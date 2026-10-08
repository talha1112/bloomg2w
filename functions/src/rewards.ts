import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as crypto from "crypto";

function generateRedemptionCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  const bytes = crypto.randomBytes(8);
  for (let i = 0; i < 8; i++) {
    code += chars[bytes[i] % chars.length];
  }
  return code;
}

interface RedeemRequest {
  rewardId: string;
}

/**
 * Atomically redeems one unit of a BloomReward offer for the calling
 * participant: verifies they hold enough UNSPENT session badges, marks
 * exactly [badgeCost] of them spent (tagged with this redemption, never
 * deleted — badge history and celebration state survive), decrements the
 * reward's remainingQuantity, and creates a RewardRedemption doc with a
 * fresh unique code. Everything happens inside one Firestore transaction,
 * so a participant can never double-spend badges or claim more units than
 * are actually available, even under concurrent requests.
 */
export const redeemReward = onCall({ region: "us-central1" }, async (request) => {
  const db = getFirestore("bloomg2w-db");
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }

  const { rewardId } = request.data as RedeemRequest;
  if (!rewardId || typeof rewardId !== "string") {
    throw new HttpsError("invalid-argument", "rewardId is required.");
  }

  const rewardRef = db.collection("rewards").doc(rewardId);
  const redemptionRef = db.collection("reward_redemptions").doc();

  try {
    const result = await db.runTransaction(async (tx) => {
      const rewardDoc = await tx.get(rewardRef);
      if (!rewardDoc.exists) {
        throw new HttpsError("not-found", "Reward not found.");
      }
      const reward = rewardDoc.data()!;

      // Both the admin-approval lifecycle (status) and the partner's own
      // pause toggle (active) must hold — a reward pending/rejected
      // review can never be redeemed even if a stale client cached it
      // before this check was added, since this validation happens
      // server-side inside the transaction, not merely in the Flutter
      // marketplace query.
      if (reward.status !== "approved") {
        throw new HttpsError("failed-precondition", "This reward is not currently approved for redemption.");
      }
      if (reward.active !== true) {
        throw new HttpsError("failed-precondition", "This reward is no longer available.");
      }
      if (reward.expirationDate && reward.expirationDate.toDate() < new Date()) {
        throw new HttpsError("failed-precondition", "This reward has expired.");
      }

      const remainingQuantity: number = reward.remainingQuantity ?? 0;
      if (remainingQuantity < 1) {
        throw new HttpsError("failed-precondition", "This reward is out of stock.");
      }

      const badgeCost: number = reward.badgeCost ?? 1;

      // Find the participant's unspent badges (a badge already tagged
      // with a redemptionId has been spent and cannot be reused).
      const badgesSnap = await tx.get(
        db.collection("session_badges").where("participantUid", "==", uid).where("redemptionId", "==", null)
      );
      if (badgesSnap.size < badgeCost) {
        throw new HttpsError(
          "failed-precondition",
          `You need ${badgeCost} badge(s) to redeem this reward — you have ${badgesSnap.size} unspent.`
        );
      }

      const code = generateRedemptionCode();
      const badgesToSpend = badgesSnap.docs.slice(0, badgeCost);

      // All writes happen only after every read/validation above has
      // succeeded, per Firestore transaction rules (reads before writes).
      for (const badgeDoc of badgesToSpend) {
        tx.update(badgeDoc.ref, { redemptionId: redemptionRef.id, spentAt: Timestamp.now() });
      }
      tx.update(rewardRef, { remainingQuantity: remainingQuantity - 1 });
      tx.set(redemptionRef, {
        rewardId,
        rewardName: reward.name ?? "",
        partnerUid: reward.partnerUid ?? "",
        partnerName: reward.partnerName ?? "",
        participantUid: uid,
        badgeCost,
        code,
        status: "pending",
        createdAt: Timestamp.now(),
        usedAt: null,
        usedByPartnerUid: null,
      });

      return { code };
    });

    logger.info("redeemReward succeeded", { uid, rewardId, redemptionId: redemptionRef.id });
    return { success: true, redemptionId: redemptionRef.id, code: result.code };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    logger.error("redeemReward failed", { uid, rewardId, error: error?.message });
    throw new HttpsError("internal", `Redemption failed: ${error?.message ?? error}`);
  }
});

interface VerifyRequest {
  code: string;
}

/**
 * Partner-triggered: looks up a redemption code scoped to the CALLING
 * partner's own uid (so one partner can never probe another partner's
 * codes) and marks it used — atomically, so a code can only ever be
 * marked used once even under a double-tap or concurrent verification
 * attempt.
 */
export const markRedemptionUsed = onCall({ region: "us-central1" }, async (request) => {
  const db = getFirestore("bloomg2w-db");
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }

  const { code } = request.data as VerifyRequest;
  if (!code || typeof code !== "string") {
    throw new HttpsError("invalid-argument", "code is required.");
  }

  const normalizedCode = code.trim().toUpperCase();
  const matchSnap = await db
    .collection("reward_redemptions")
    .where("partnerUid", "==", uid)
    .where("code", "==", normalizedCode)
    .limit(1)
    .get();

  if (matchSnap.empty) {
    throw new HttpsError("not-found", "No reward found for that code.");
  }
  const redemptionRef = matchSnap.docs[0].ref;

  try {
    await db.runTransaction(async (tx) => {
      const doc = await tx.get(redemptionRef);
      if (!doc.exists) {
        // Could happen if the redemption was deleted between the lookup
        // query above and this transaction — treat it the same as "not
        // found" rather than crashing on an undefined data() access.
        throw new HttpsError("not-found", "This redemption no longer exists.");
      }
      const data = doc.data()!;
      if (data.status === "used") {
        throw new HttpsError("failed-precondition", "This code has already been redeemed.");
      }
      tx.update(redemptionRef, { status: "used", usedAt: Timestamp.now(), usedByPartnerUid: uid });
    });

    // Thank-you notification to the partner, reusing the existing
    // app_notifications infrastructure (AppNotificationType.general) —
    // best-effort: a notification failure must never undo an already-
    // committed redemption, so it's outside the transaction and its own
    // errors are only logged, never surfaced to the caller.
    try {
      await db.collection("app_notifications").doc().set({
        uid,
        type: "general",
        title: "Thank You, Community Partner! 🌸",
        body:
          "Thank you for being a Project Bloom Girls 2 Women Community Partner! Your generosity helps us encourage girls and women to participate, learn, achieve goals, build confidence, and continue blooming. Together, we are Building a Nation of Bloomers — One Girl and One Woman at a Time. Bloom. Believe. Become.",
        read: false,
        sessionId: null,
        createdAt: Timestamp.now(),
      });
    } catch (notifyError: any) {
      logger.error("markRedemptionUsed: thank-you notification failed", { uid, notifyError: notifyError?.message });
    }

    return { success: true };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    logger.error("markRedemptionUsed failed", { uid, code: normalizedCode, error: error?.message });
    throw new HttpsError("internal", `Could not mark redeemed: ${error?.message ?? error}`);
  }
});
