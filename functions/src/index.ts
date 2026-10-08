import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

import { createMeetingForUser, fetchPastMeeting, fetchPastMeetingParticipants, zoomAccountId, zoomClientId, zoomClientSecret } from "./zoomClient";
import { matchAttendance, RegisteredParticipant } from "./attendanceCalculator";

initializeApp();
const db = getFirestore("bloomg2w-db");

export { redeemReward, markRedemptionUsed } from "./rewards";
export { createDonationCheckout, stripeWebhook } from "./stripe";
export { completeMinorSignup, redeemInviteCode } from "./guardianLinking";
export { deleteOwnAccount } from "./accountDeletion";

interface SyncRequest {
  sessionId: string;
}

type SessionNotificationKind = "sessionUpdated" | "sessionCancelled" | "sessionReminder" | "sessionStarting";

const SESSION_NOTIFICATION_COPY: Record<SessionNotificationKind, (sessionTitle: string, extra?: string) => { title: string; body: string }> = {
  sessionUpdated: (sessionTitle) => ({
    title: "🌸 Bloom Session Updated",
    body: `The ${sessionTitle} has been rescheduled. Please check the updated session details.`,
  }),
  sessionCancelled: (sessionTitle) => ({
    title: "🌸 Bloom Session Cancelled",
    body: `The ${sessionTitle} session has been cancelled. You will be notified when a new session is scheduled.`,
  }),
  sessionReminder: (sessionTitle) => ({
    title: "🌸 Bloom Session Reminder",
    body: `${sessionTitle} is coming up soon — don't forget to join!`,
  }),
  sessionStarting: (sessionTitle) => ({
    title: "🌸 Your Bloom Session Is Starting",
    body: `${sessionTitle} is starting now — tap to join.`,
  }),
};

interface NotifyRegistrantsRequest {
  sessionId: string;
  kind: SessionNotificationKind;
}

/**
 * Admin-triggered fan-out of a session notice to every active registrant.
 * This is the ONLY server-side path that may create a notification for a
 * uid other than the caller's own — Firestore rules restrict client
 * `app_notifications` creates to `d.uid == request.auth.uid` (see M-6),
 * so updateSession/cancelSession/"Send Reminder Now"/"Notify: Starting"
 * all route through this function instead of writing to other users'
 * inboxes directly from the client.
 */
export const notifySessionRegistrants = onCall({ region: "us-central1" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }

  const adminDoc = await db.collection("users").doc(uid).get();
  if (adminDoc.data()?.role !== "admin") {
    throw new HttpsError("permission-denied", "Only an admin may notify session registrants.");
  }

  const { sessionId, kind } = request.data as NotifyRegistrantsRequest;
  if (!sessionId || typeof sessionId !== "string") {
    throw new HttpsError("invalid-argument", "sessionId is required.");
  }
  if (!kind || !(kind in SESSION_NOTIFICATION_COPY)) {
    throw new HttpsError("invalid-argument", `kind must be one of: ${Object.keys(SESSION_NOTIFICATION_COPY).join(", ")}`);
  }

  const sessionDoc = await db.collection("bloom_sessions").doc(sessionId).get();
  if (!sessionDoc.exists) {
    throw new HttpsError("not-found", "Session not found.");
  }
  const sessionTitle: string = sessionDoc.data()?.title ?? "your Bloom session";

  const registrationsSnap = await db.collection("session_registrations").where("sessionId", "==", sessionId).get();
  const activeUids = registrationsSnap.docs
    .map((d) => d.data() as any)
    .filter((r) => r.status !== "cancelled")
    .map((r) => r.participantUid as string);

  // If a registrant is a minor, her linked guardian(s) also receive this
  // notification — looked up per-registrant since Firestore has no
  // efficient "IN" query here that scales past 30 ids, and this path
  // already runs admin-side with no per-request latency budget to protect.
  const recipientUids = new Set<string>(activeUids);
  for (const registrantUid of activeUids) {
    const registrantDoc = await db.collection("users").doc(registrantUid).get();
    const registrant = registrantDoc.data();
    if (registrant?.role === "minor") {
      const guardianUids: string[] = registrant.guardianUids ?? [];
      for (const guardianUid of guardianUids) {
        recipientUids.add(guardianUid);
      }
    }
  }

  const { title, body } = SESSION_NOTIFICATION_COPY[kind](sessionTitle);

  const recipients = [...recipientUids];
  const BATCH_LIMIT = 500;
  for (let i = 0; i < recipients.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const recipientUid of recipients.slice(i, i + BATCH_LIMIT)) {
      const ref = db.collection("app_notifications").doc();
      batch.set(ref, {
        uid: recipientUid,
        type: kind,
        title,
        body,
        read: false,
        sessionId,
        createdAt: Timestamp.now(),
      });
    }
    await batch.commit();
  }

  logger.info("notifySessionRegistrants sent", { sessionId, kind, registrantCount: activeUids.length, notifiedCount: recipients.length, triggeredByUid: uid });

  return { success: true, notifiedCount: recipients.length };
});

/**
 * Admin-triggered pull sync of a session's authoritative Zoom attendance
 * report. Callable only by an authenticated admin (checked against their
 * own users/{uid} doc — never trusts client-claimed role).
 *
 * Idempotent: re-running for the same session overwrites each
 * registrant's attendance fields with the latest Zoom data rather than
 * stacking duplicate imports, and every run appends one entry to
 * attendance_sync_log for audit history instead of silently overwriting
 * the previous run's record.
 */
export const syncSessionAttendance = onCall(
  { secrets: [zoomAccountId, zoomClientId, zoomClientSecret], region: "us-central1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const adminDoc = await db.collection("users").doc(uid).get();
    if (adminDoc.data()?.role !== "admin") {
      throw new HttpsError("permission-denied", "Only an admin may sync attendance.");
    }

    const { sessionId } = request.data as SyncRequest;
    if (!sessionId || typeof sessionId !== "string") {
      throw new HttpsError("invalid-argument", "sessionId is required.");
    }

    const sessionDoc = await db.collection("bloom_sessions").doc(sessionId).get();
    if (!sessionDoc.exists) {
      throw new HttpsError("not-found", "Session not found.");
    }
    const session = sessionDoc.data()!;
    const zoomMeetingId: string = session.zoomMeetingId ?? "";
    const minAttendancePercent: number = session.minAttendancePercent ?? 0;

    if (!zoomMeetingId) {
      throw new HttpsError("failed-precondition", "This session has no Zoom Meeting ID configured.");
    }

    const syncLogRef = db.collection("attendance_sync_log").doc();
    const startedAt = Timestamp.now();

    try {
      const [pastMeeting, zoomParticipants] = await Promise.all([
        fetchPastMeeting(zoomMeetingId),
        fetchPastMeetingParticipants(zoomMeetingId),
      ]);

      if (!pastMeeting.duration || pastMeeting.duration <= 0) {
        throw new HttpsError(
          "failed-precondition",
          "Zoom reported an invalid meeting duration for this session — cannot calculate attendance percentages. Verify the meeting has actually ended and try again."
        );
      }

      const registrationsSnap = await db.collection("session_registrations").where("sessionId", "==", sessionId).get();
      // Keep each registration's real DocumentReference (its actual doc
      // ID, from the query result) rather than reconstructing
      // "{sessionId}_{uid}" — a registration created by any path other
      // than the normal client flow (e.g. a future admin/import tool)
      // could have a different doc ID with the same fields, and
      // batch.update() on a guessed, non-existent ref fails the entire
      // batch.
      const refByUid = new Map<string, FirebaseFirestore.DocumentReference>();
      const registrations = registrationsSnap.docs
        .map((d) => {
          refByUid.set((d.data() as any).participantUid, d.ref);
          return { id: d.id, ...d.data() };
        })
        .filter((r: any) => r.status !== "cancelled");

      // Batched via getAll() (chunked defensively) rather than one
      // Promise.all() of individual get() calls per registrant — avoids
      // an unbounded fan-out of concurrent gRPC reads for a
      // large-enrollment session.
      const uidToEmail = new Map<string, string>();
      const userRefs = registrations.map((r: any) => db.collection("users").doc(r.participantUid));
      const GET_ALL_CHUNK = 300;
      for (let i = 0; i < userRefs.length; i += GET_ALL_CHUNK) {
        const chunk = userRefs.slice(i, i + GET_ALL_CHUNK);
        if (chunk.length === 0) continue;
        const userDocs = await db.getAll(...chunk);
        userDocs.forEach((u) => {
          if (u.exists) uidToEmail.set(u.id, (u.data()?.email ?? "").toLowerCase());
        });
      }

      const registered: RegisteredParticipant[] = registrations
        .map((r: any) => ({ uid: r.participantUid, email: uidToEmail.get(r.participantUid) ?? "" }))
        .filter((r) => r.email.length > 0);

      const { matches, unmatched } = matchAttendance(zoomParticipants, registered, pastMeeting.duration, minAttendancePercent);

      let qualifiedCount = 0;
      let unmatchedRegistrantCount = 0;
      const pendingWrites: Array<{ ref: FirebaseFirestore.DocumentReference; data: FirebaseFirestore.UpdateData<any> }> = [];

      for (const match of matches) {
        const regRef = refByUid.get(match.uid);

        if (match.matchMethod === "unmatched" || !regRef) {
          unmatchedRegistrantCount++;
          // Leave attendance untouched — an admin must resolve this via
          // manual correction. We never guess.
          continue;
        }

        if (match.qualified) qualifiedCount++;

        pendingWrites.push({
          ref: regRef,
          data: {
            attended: match.qualified,
            status: match.qualified ? "attended" : "missed",
            attendanceSource: "zoom_import",
            attendedMinutes: match.attendedMinutes,
            attendancePercent: match.attendancePercent,
            attendanceMatchMethod: match.matchMethod,
            attendanceSyncedAt: Timestamp.now(),
          },
        });
      }

      // Firestore batches cap at 500 writes — chunk defensively even
      // though most sessions won't approach that size.
      const BATCH_LIMIT = 500;
      for (let i = 0; i < pendingWrites.length; i += BATCH_LIMIT) {
        const batch = db.batch();
        for (const { ref, data } of pendingWrites.slice(i, i + BATCH_LIMIT)) {
          batch.update(ref, data);
        }
        await batch.commit();
      }

      await syncLogRef.set({
        sessionId,
        zoomMeetingId,
        triggeredByUid: uid,
        startedAt,
        completedAt: Timestamp.now(),
        status: "success",
        sessionDurationMinutes: pastMeeting.duration,
        registeredCount: registered.length,
        matchedCount: matches.filter((m) => m.matchMethod !== "unmatched").length,
        qualifiedCount,
        unmatchedRegistrantCount,
        unmatchedZoomParticipants: unmatched,
        errorMessage: null,
      });

      return {
        success: true,
        registeredCount: registered.length,
        matchedCount: matches.filter((m) => m.matchMethod !== "unmatched").length,
        qualifiedCount,
        unmatchedRegistrantCount,
        unmatchedZoomParticipants: unmatched,
      };
    } catch (error: any) {
      logger.error("syncSessionAttendance failed", { sessionId, error: error?.message });
      // Best-effort audit write: if Firestore itself is the reason this
      // sync failed, don't let a second failure here replace the
      // original, more useful error message.
      try {
        await syncLogRef.set({
          sessionId,
          zoomMeetingId,
          triggeredByUid: uid,
          startedAt,
          completedAt: Timestamp.now(),
          status: "failed",
          sessionDurationMinutes: null,
          registeredCount: null,
          matchedCount: null,
          qualifiedCount: null,
          unmatchedRegistrantCount: null,
          unmatchedZoomParticipants: [],
          errorMessage: String(error?.message ?? error),
        });
      } catch (logError: any) {
        logger.error("syncSessionAttendance: failed to write failure audit log", { sessionId, logError: logError?.message });
      }
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", `Zoom attendance sync failed: ${error?.message ?? error}`);
    }
  }
);

interface CreateMeetingRequest {
  sessionId: string;
}

// Project Bloom G2W's sessions are authored and displayed in this fixed
// timezone (bloom_session.startTime/endTime carry no timezone info of
// their own — they're plain "6:00 PM" strings). Zoom is told this IANA
// zone explicitly alongside the wall-clock time, so it schedules the
// meeting at the correct real-world instant regardless of Zoom's or the
// server's own default timezone. Update this single constant if Project
// Bloom's operating timezone is ever not US Eastern.
const SESSION_TIMEZONE = "America/New_York";

function parseClockTime(label: string): { hour: number; minute: number } | null {
  const match = /^(\d{1,2}):(\d{2})\s*(AM|PM)?$/i.exec(label.trim());
  if (!match) return null;
  let hour = parseInt(match[1], 10);
  const minute = parseInt(match[2], 10);
  const meridiem = match[3]?.toUpperCase();
  if (meridiem === "PM" && hour !== 12) hour += 12;
  if (meridiem === "AM" && hour === 12) hour = 0;
  return { hour, minute };
}

/**
 * Admin-triggered: creates a real Zoom meeting under the assigned guest
 * speaker's own licensed Zoom user account (Server-to-Server OAuth acting
 * on behalf of a same-org user — see createMeetingForUser), then saves the
 * resulting join link/ID/passcode onto the session for participants and
 * the host-only start link for the speaker's dashboard.
 *
 * The speaker's email is resolved from speaker_applications/{uid} — a
 * PII-holding collection only this trusted backend and admins can read —
 * never taken from client input, so a caller cannot point the meeting at
 * an arbitrary Zoom user.
 */
export const createZoomMeetingForSession = onCall(
  { secrets: [zoomAccountId, zoomClientId, zoomClientSecret], region: "us-central1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const adminDoc = await db.collection("users").doc(uid).get();
    if (adminDoc.data()?.role !== "admin") {
      throw new HttpsError("permission-denied", "Only an admin may create a Zoom meeting.");
    }

    const { sessionId } = request.data as CreateMeetingRequest;
    if (!sessionId || typeof sessionId !== "string") {
      throw new HttpsError("invalid-argument", "sessionId is required.");
    }

    const sessionRef = db.collection("bloom_sessions").doc(sessionId);
    const sessionDoc = await sessionRef.get();
    if (!sessionDoc.exists) {
      throw new HttpsError("not-found", "Session not found.");
    }
    const session = sessionDoc.data()!;
    const speakerUid: string | undefined = session.guestSpeakerUid;
    if (!speakerUid) {
      throw new HttpsError("failed-precondition", "Assign a guest speaker to this session before creating a Zoom meeting.");
    }

    const speakerAppDoc = await db.collection("speaker_applications").doc(speakerUid).get();
    const speakerEmail: string | undefined = speakerAppDoc.data()?.email;
    if (!speakerEmail) {
      throw new HttpsError("failed-precondition", "The assigned speaker has no email on file.");
    }

    const sessionDate: Date = session.date?.toDate?.() ?? new Date();
    const startClock = parseClockTime(session.startTime ?? "");
    const endClock = parseClockTime(session.endTime ?? "");

    if (!startClock) {
      throw new HttpsError("failed-precondition", `This session's start time ("${session.startTime}") isn't in a recognizable format (e.g. "6:00 PM").`);
    }

    // The stored date's calendar day (read via UTC getters, since the
    // admin's date picker stores midnight UTC for the chosen day) combined
    // with the wall-clock start time, as a LOCAL time string (no "Z") that
    // Zoom interprets using the explicit `timezone` field below — never
    // silently reinterpreted as UTC.
    const y = sessionDate.getUTCFullYear();
    const m = String(sessionDate.getUTCMonth() + 1).padStart(2, "0");
    const day = String(sessionDate.getUTCDate()).padStart(2, "0");
    const hh = String(startClock.hour).padStart(2, "0");
    const mm = String(startClock.minute).padStart(2, "0");
    const startTimeLocal = `${y}-${m}-${day}T${hh}:${mm}:00`;

    let durationMinutes = 60;
    if (endClock) {
      let diff = endClock.hour * 60 + endClock.minute - (startClock.hour * 60 + startClock.minute);
      // A session listed as e.g. 11:00 PM - 12:30 AM crosses midnight —
      // without this, the negative diff silently fell back to the
      // generic 60-minute default instead of the correct ~90 minutes.
      if (diff <= 0) diff += 24 * 60;
      durationMinutes = diff;
    }

    try {
      const meeting = await createMeetingForUser({
        hostEmail: speakerEmail,
        topic: session.title || "Bloom G2W Session",
        startTimeLocal,
        timezone: SESSION_TIMEZONE,
        durationMinutes,
      });

      await sessionRef.update({
        zoomMeetingLink: meeting.join_url,
        zoomMeetingId: String(meeting.id),
        zoomPasscode: meeting.password,
      });

      // Host-only start link lives in a private subcollection — Firestore
      // rules can grant the assigned speaker + admin read access to this
      // doc specifically, without exposing it to every member who can read
      // the (broadly readable) published session document.
      await sessionRef.collection("private").doc("zoomHost").set({
        startUrl: meeting.start_url,
        hostEmail: meeting.host_email,
        speakerUid,
        updatedAt: Timestamp.now(),
      });

      logger.info("createZoomMeetingForSession succeeded", { sessionId, speakerUid, meetingId: meeting.id });

      return {
        success: true,
        zoomMeetingId: String(meeting.id),
        zoomMeetingLink: meeting.join_url,
      };
    } catch (error: any) {
      logger.error("createZoomMeetingForSession failed", { sessionId, speakerUid, error: error?.message });
      throw new HttpsError("internal", `Could not create Zoom meeting: ${error?.message ?? error}`);
    }
  }
);
