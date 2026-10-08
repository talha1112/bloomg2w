import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { getAuth } from "firebase-admin/auth";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

const BATCH_LIMIT = 500;

/**
 * Deletes every doc in [query] in batches of [BATCH_LIMIT] — the same
 * chunking idiom already used for fan-out writes in index.ts's
 * notifySessionRegistrants. Returns the total number of docs deleted.
 */
async function deleteAllMatching(db: FirebaseFirestore.Firestore, query: FirebaseFirestore.Query): Promise<number> {
  const snap = await query.get();
  let deleted = 0;
  for (let i = 0; i < snap.docs.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const doc of snap.docs.slice(i, i + BATCH_LIMIT)) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deleted += Math.min(BATCH_LIMIT, snap.docs.length - i);
  }
  return deleted;
}

/**
 * Deletes every session_registrations/session_badges/session_surveys/
 * session_checkins doc whose composite id ends "_{uid}" — these collections
 * are keyed "{sessionId}_{participantUid}" (see firestore.rules's
 * canReadOwnParticipantDoc), so there's no indexed "participantUid" query
 * needed; the doc id itself identifies ownership. Still, each collection
 * ALSO carries a participantUid field, so we query on that field (which is
 * indexed by default for equality) rather than scanning every doc by id.
 */
async function deleteParticipantDocs(db: FirebaseFirestore.Firestore, uid: string): Promise<void> {
  const collections = ["session_registrations", "session_badges", "session_surveys", "session_checkins"];
  for (const name of collections) {
    await deleteAllMatching(db, db.collection(name).where("participantUid", "==", uid));
  }
}

/**
 * Best-effort delete of a possible Storage photo at [path] — "not found" is
 * expected (a user has at most one of the three possible photo kinds) and
 * is swallowed; any other error is logged but does not fail the overall
 * deletion, since a stray orphaned photo is a much smaller problem than
 * leaving the user's account and data half-deleted.
 */
async function tryDeleteStorageFile(bucket: ReturnType<ReturnType<typeof getStorage>["bucket"]>, path: string): Promise<void> {
  try {
    await bucket.file(path).delete();
  } catch (error: any) {
    if (error?.code !== 404) {
      logger.error("deleteOwnAccount: storage delete failed (non-fatal)", { path, error: error?.message });
    }
  }
}

/**
 * Lets a signed-in user permanently delete their OWN account: their
 * Firestore profile and every doc they own across the app, their Storage
 * photo (whichever of the three namespaces applies), their Firebase Auth
 * account, and — where they're a linked minor or guardian — unwinds that
 * link on the other party's doc so nobody is left pointing at a uid that no
 * longer exists.
 *
 * Financial/accounting records (donations, reward_redemptions) are
 * ANONYMIZED rather than deleted — the underlying transaction/fulfillment
 * history still needs to exist for the Community Partner's own records and
 * for basic accounting integrity, but personally-identifying fields are
 * blanked. stripe_webhook_events and attendance_sync_log are operational
 * audit logs, not "this user's data" in the privacy sense, and are left
 * untouched entirely.
 *
 * There is no "delete someone else's account" path — only self-deletion,
 * gated by the caller already holding a valid ID token for that uid. This
 * is deliberate: it means no client-side Firebase Auth re-authentication
 * flow is needed (admin.auth().deleteUser() is a privileged server-side
 * call with no recent-sign-in requirement, unlike the client SDK's
 * user.delete()).
 */
export const deleteOwnAccount = onCall({ region: "us-central1" }, async (request) => {
  const db = getFirestore("bloomg2w-db");
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }

  const userRef = db.collection("users").doc(uid);

  try {
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
      // Nothing to clean up in Firestore, but still remove the orphaned
      // Auth account so the user isn't stuck unable to sign in or re-register
      // with the same email.
      await getAuth().deleteUser(uid).catch(() => undefined);
      logger.info("deleteOwnAccount: no profile doc found, Auth account removed", { uid });
      return { success: true };
    }
    const user = userDoc.data()!;
    const role: string = user.role ?? "";

    // 1. Unwind guardian <-> minor links (mirrors redeemInviteCode's
    // atomic both-sides-update pattern in guardianLinking.ts).
    if (role === "minor") {
      const guardianUids: string[] = user.guardianUids ?? [];
      for (let i = 0; i < guardianUids.length; i += BATCH_LIMIT) {
        const batch = db.batch();
        for (const guardianUid of guardianUids.slice(i, i + BATCH_LIMIT)) {
          batch.update(db.collection("users").doc(guardianUid), { linkedChildUids: FieldValue.arrayRemove(uid) });
        }
        await batch.commit();
      }
      // Invite codes pointing at this minor are no longer redeemable.
      await deleteAllMatching(db, db.collection("invite_codes").where("minorUid", "==", uid));
    } else if (role === "guardian") {
      const linkedChildUids: string[] = user.linkedChildUids ?? [];
      for (let i = 0; i < linkedChildUids.length; i += BATCH_LIMIT) {
        const batch = db.batch();
        for (const childUid of linkedChildUids.slice(i, i + BATCH_LIMIT)) {
          batch.update(db.collection("users").doc(childUid), { guardianUids: FieldValue.arrayRemove(uid) });
        }
        await batch.commit();
      }
    }

    // 2. Delete the user's own participant-scoped records.
    await deleteParticipantDocs(db, uid);

    // 3. Delete app_notifications addressed to this user.
    await deleteAllMatching(db, db.collection("app_notifications").where("uid", "==", uid));

    // 4. Role-specific owned docs.
    if (role === "partner") {
      await db.collection("partners").doc(uid).delete().catch(() => undefined);
      await db.collection("partner_profiles").doc(uid).delete().catch(() => undefined);
      await deleteAllMatching(db, db.collection("rewards").where("partnerUid", "==", uid));
    }
    if (role === "guestSpeaker") {
      await db.collection("speaker_applications").doc(uid).delete().catch(() => undefined);
      await db.collection("speaker_profiles").doc(uid).delete().catch(() => undefined);
    }
    await deleteAllMatching(db, db.collection("speaker_interests").where("memberUid", "==", uid));
    await deleteAllMatching(db, db.collection("speaker_interests").where("speakerUid", "==", uid));
    await deleteAllMatching(db, db.collection("support_messages").where("uid", "==", uid));
    await deleteAllMatching(db, db.collection("membership_applications").where("uid", "==", uid));

    // 5. Anonymize (never delete) financial/accounting-adjacent records.
    const donationsSnap = await db.collection("donations").where("partnerId", "==", uid).get();
    for (let i = 0; i < donationsSnap.docs.length; i += BATCH_LIMIT) {
      const batch = db.batch();
      for (const doc of donationsSnap.docs.slice(i, i + BATCH_LIMIT)) {
        batch.update(doc.ref, { email: "[deleted account]", partnerName: "[deleted account]" });
      }
      await batch.commit();
    }
    const redemptionsSnap = await db.collection("reward_redemptions").where("participantUid", "==", uid).get();
    for (let i = 0; i < redemptionsSnap.docs.length; i += BATCH_LIMIT) {
      const batch = db.batch();
      for (const doc of redemptionsSnap.docs.slice(i, i + BATCH_LIMIT)) {
        batch.update(doc.ref, { participantUid: null });
      }
      await batch.commit();
    }

    // 6. Best-effort Storage cleanup — a user has at most one of these.
    // The bucket name is passed explicitly rather than relying on
    // getStorage().bucket()'s default-app inference, which depends on the
    // FIREBASE_CONFIG env var carrying a storageBucket field — true for a
    // deployed function, but not guaranteed in every local/test harness.
    const bucket = getStorage().bucket("bloomg2w.firebasestorage.app");
    await tryDeleteStorageFile(bucket, `profile_photos/${uid}.jpg`);
    await tryDeleteStorageFile(bucket, `speaker_photos/${uid}.jpg`);
    await tryDeleteStorageFile(bucket, `partner_logos/${uid}.jpg`);

    // 7. The profile doc itself.
    await userRef.delete();

    // 8. Firebase Auth account — last, so a failure earlier in this
    // function never leaves someone locked out of an account that still
    // has orphaned data; they can sign in and retry.
    await getAuth().deleteUser(uid);

    logger.info("deleteOwnAccount succeeded", { uid, role });
    return { success: true };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    logger.error("deleteOwnAccount failed", { uid, error: error?.message });
    throw new HttpsError("internal", `Could not delete account: ${error?.message ?? error}`);
  }
});
