import { getFirestore, Timestamp, FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as crypto from "crypto";

const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 6;
const MAX_GUARDIANS_PER_MINOR = 4;
const MAX_CODE_GENERATION_ATTEMPTS = 10;

function generateCandidateCode(): string {
  let code = "";
  const bytes = crypto.randomBytes(CODE_LENGTH);
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_CHARS[bytes[i] % CODE_CHARS.length];
  }
  return code;
}

/**
 * Generates a unique, reusable (non-expiring) invite code for a newly
 * self-registering minor, and attaches it to her user doc — all inside the
 * SAME transaction as the user doc's own creation, so the two can never
 * diverge (a minor doc is never created without a code, and a code never
 * exists without a corresponding minor doc). Called from inside
 * `completeMinorSignup`'s transaction (see below), not directly callable.
 *
 * Collisions are vanishingly unlikely at this alphabet/length
 * (33^6 ≈ 1.29 billion combinations) but are still checked and retried —
 * a transaction can only read docs it hasn't yet written, so each retry
 * re-reads a fresh candidate's invite_codes/{code} doc.
 */
async function pickUniqueInviteCode(
  tx: FirebaseFirestore.Transaction,
  db: FirebaseFirestore.Firestore
): Promise<string> {
  for (let attempt = 0; attempt < MAX_CODE_GENERATION_ATTEMPTS; attempt++) {
    const candidate = generateCandidateCode();
    const existing = await tx.get(db.collection("invite_codes").doc(candidate));
    if (!existing.exists) {
      return candidate;
    }
  }
  throw new HttpsError("internal", "Could not generate a unique invite code — please try again.");
}

interface CompleteMinorSignupRequest {
  firstName: string;
  lastName: string;
  email: string;
  memberType: string;
  dateOfBirth: number; // epoch millis
}

/**
 * Called once, right after a Girl finishes the "Profile Information" step
 * of the signup wizard (the first point her date of birth is known).
 * Creates her Firestore user doc (role 'minor') AND generates+attaches her
 * guardian invite code atomically in one transaction — the Firestore
 * SECURITY RULES still independently enforce the 8-17 age requirement on
 * this write (see isValidNewMemberDoc/isValidAgeForRole in firestore.rules),
 * so this function's own age check below is a defense-in-depth belt, not
 * the sole guard: even if this function were somehow bypassed, the rules
 * would still reject an out-of-range write.
 *
 * Firebase Auth account creation happens client-side via the normal
 * signUp() flow BEFORE this is called — this function only ever writes the
 * Firestore profile doc for the already-authenticated caller's own uid,
 * never anyone else's.
 */
export const completeMinorSignup = onCall({ region: "us-central1" }, async (request) => {
  const db = getFirestore("bloomg2w-db");
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }

  const { firstName, lastName, email, memberType, dateOfBirth } = request.data as CompleteMinorSignupRequest;
  if (!firstName || typeof firstName !== "string") {
    throw new HttpsError("invalid-argument", "firstName is required.");
  }
  if (!lastName || typeof lastName !== "string") {
    throw new HttpsError("invalid-argument", "lastName is required.");
  }
  if (!email || typeof email !== "string" || email !== request.auth?.token.email) {
    throw new HttpsError("invalid-argument", "email must match the authenticated account.");
  }
  if (typeof dateOfBirth !== "number") {
    throw new HttpsError("invalid-argument", "dateOfBirth is required.");
  }

  const dob = new Date(dateOfBirth);
  const ageYears = (Date.now() - dob.getTime()) / (1000 * 60 * 60 * 24 * 365.25);
  if (ageYears < 8 || ageYears >= 18) {
    throw new HttpsError("failed-precondition", "A Girl account requires a date of birth between 8 and 17 years old.");
  }

  const userRef = db.collection("users").doc(uid);

  try {
    const result = await db.runTransaction(async (tx) => {
      const existing = await tx.get(userRef);
      if (existing.exists) {
        // Idempotency: if this was already called once (e.g. a retried
        // request after a dropped connection), don't create a second
        // invite code or overwrite her doc — just return her existing one.
        const data = existing.data()!;
        return { inviteCode: data.inviteCode as string };
      }

      const inviteCode = await pickUniqueInviteCode(tx, db);

      tx.set(userRef, {
        firstName,
        lastName,
        email,
        role: "minor",
        memberType,
        photoUrl: null,
        createdAt: Timestamp.now(),
        dateOfBirth: Timestamp.fromDate(dob),
        guardianUids: [],
        linkedChildUids: [],
        inviteCode,
      });
      tx.set(db.collection("invite_codes").doc(inviteCode), {
        minorUid: uid,
        createdAt: Timestamp.now(),
      });

      return { inviteCode };
    });

    logger.info("completeMinorSignup succeeded", { uid });
    return { success: true, inviteCode: result.inviteCode };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    logger.error("completeMinorSignup failed", { uid, error: error?.message });
    throw new HttpsError("internal", `Could not complete signup: ${error?.message ?? error}`);
  }
});

interface RedeemInviteCodeRequest {
  code: string;
}

/**
 * Guardian-triggered: redeems a minor's invite code, linking the calling
 * guardian to her. Reusable and non-expiring by design (supports multiple
 * guardians per girl — both parents, a parent + grandparent, etc.) —
 * redeeming the same code twice by the same guardian is a no-op
 * (arrayUnion), not an error, so there's no harm in a guardian re-entering
 * a code they already used.
 *
 * Only a caller whose OWN role is already 'guardian' may call this — a
 * Woman or another Girl cannot link themselves to a minor this way.
 */
export const redeemInviteCode = onCall({ region: "us-central1" }, async (request) => {
  const db = getFirestore("bloomg2w-db");
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }

  const { code } = request.data as RedeemInviteCodeRequest;
  if (!code || typeof code !== "string") {
    throw new HttpsError("invalid-argument", "code is required.");
  }
  const normalizedCode = code.trim().toUpperCase();

  const callerDoc = await db.collection("users").doc(uid).get();
  if (callerDoc.data()?.role !== "guardian") {
    throw new HttpsError("permission-denied", "Only a Parent/Guardian account may link to a child using an invite code.");
  }

  const codeDoc = await db.collection("invite_codes").doc(normalizedCode).get();
  if (!codeDoc.exists) {
    throw new HttpsError("not-found", "Invalid invite code.");
  }
  const minorUid: string = codeDoc.data()!.minorUid;
  const minorRef = db.collection("users").doc(minorUid);
  const guardianRef = db.collection("users").doc(uid);

  try {
    await db.runTransaction(async (tx) => {
      const minorDoc = await tx.get(minorRef);
      if (!minorDoc.exists) {
        throw new HttpsError("not-found", "The linked account no longer exists.");
      }
      const guardianUids: string[] = minorDoc.data()?.guardianUids ?? [];
      if (!guardianUids.includes(uid) && guardianUids.length >= MAX_GUARDIANS_PER_MINOR) {
        throw new HttpsError("failed-precondition", `This account already has the maximum of ${MAX_GUARDIANS_PER_MINOR} linked guardians.`);
      }

      tx.update(minorRef, { guardianUids: FieldValue.arrayUnion(uid) });
      tx.update(guardianRef, { linkedChildUids: FieldValue.arrayUnion(minorUid) });
    });

    logger.info("redeemInviteCode succeeded", { guardianUid: uid, minorUid });
    return { success: true, linkedChildUid: minorUid };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    logger.error("redeemInviteCode failed", { guardianUid: uid, error: error?.message });
    throw new HttpsError("internal", `Could not link account: ${error?.message ?? error}`);
  }
});
