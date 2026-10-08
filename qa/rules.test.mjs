// Runtime Firestore security-rules tests against the local emulator.
// Project id is demo-bloomg2w, so nothing here can ever reach production.
import { readFileSync } from "node:fs";
import { after, before, beforeEach, describe, test } from "node:test";
import { assertFails, assertSucceeds, initializeTestEnvironment } from "@firebase/rules-unit-testing";
import { collection, deleteDoc, doc, getDoc, getDocs, onSnapshot, query, serverTimestamp, setDoc, Timestamp, updateDoc, where } from "firebase/firestore";

let env;
const P1 = "participant1";
const P2 = "participant2";
const PARTNER_A = "partnerA";
const PARTNER_B = "partnerB";
const ADMIN = "admin1";
const SPEAKER = "speaker1";
const SPEAKER_2 = "speaker2";
const SESSION = "sess1";
const REG_P1 = `${SESSION}_${P1}`;
const REG_P2 = `${SESSION}_${P2}`;
const MINOR = "minor1";
const MINOR_UNLINKED = "minorUnlinked";
const GUARDIAN = "guardian1";
const GUARDIAN_UNLINKED = "guardianUnlinked";
const REG_MINOR = `${SESSION}_${MINOR}`;

const db = (uid) => env.authenticatedContext(uid, { email: `${uid}@example.com` }).firestore();
const anon = () => env.unauthenticatedContext().firestore();

function sessionDoc(overrides = {}) {
  return {
    title: "Leadership Lab", topic: "Voice", description: "desc", date: Timestamp.fromDate(new Date("2026-10-05T00:00:00Z")),
    startTime: "6:00 PM", endTime: "7:00 PM", zoomMeetingLink: "https://zoom.us/j/1", zoomMeetingId: "1", zoomPasscode: "p",
    minAttendancePercent: 75, program: "Leadership Lab", ageGroup: "Girls", status: "published",
    registrationDeadline: null, guestSpeakerUid: SPEAKER, guestSpeakerNameSnapshot: "Speaker", cancellationReason: null,
    createdAt: Timestamp.now(), ...overrides,
  };
}

function registration(uid, overrides = {}) {
  return {
    sessionId: SESSION, participantUid: uid, participantName: uid, registeredAt: Timestamp.now(), status: "registered",
    notified: false, checkedIn: false, attended: false, surveyCompleted: false, completionMet: false, ...overrides,
  };
}

function partnerDoc(overrides = {}) {
  return {
    businessName: "Biz", contactPerson: "Owner", email: "biz@example.com", phone: "555", website: "https://biz.example",
    description: "d", supportTypes: ["Sponsor participant rewards"], contributionDetails: "c", logoUrl: null,
    status: "pending", statusUpdatedAt: null, statusUpdatedBy: null, createdAt: Timestamp.now(), ...overrides,
  };
}

function rewardDoc(overrides = {}) {
  return {
    partnerUid: PARTNER_A, partnerName: "Biz", name: "Gift Card", value: 25, quantityAvailable: 5, remainingQuantity: 5,
    badgeCost: 2, description: "d", expirationDate: null, restrictions: null, active: true, status: "approved",
    reviewNotes: "", createdAt: Timestamp.now(), ...overrides,
  };
}

function badge(uid, overrides = {}) {
  return { sessionId: SESSION, participantUid: uid, sessionTitle: "Leadership Lab", program: "Leadership Lab", awardedAt: Timestamp.now(), celebrationSeen: false, redemptionId: null, ...overrides };
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-bloomg2w",
    firestore: { rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8") },
  });
});

after(async () => env?.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    const user = (uid, role) => setDoc(doc(f, "users", uid), { firstName: uid, lastName: "T", email: `${uid}@example.com`, role, memberType: "woman", createdAt: Timestamp.now() });
    await user(P1, "member");
    await user(P2, "member");
    await user(PARTNER_A, "partner");
    await user(PARTNER_B, "partner");
    await user(ADMIN, "admin");
    await user(SPEAKER, "guestSpeaker");
    await user(SPEAKER_2, "guestSpeaker");
    await setDoc(doc(f, "users", MINOR), {
      firstName: MINOR, lastName: "T", email: `${MINOR}@example.com`, role: "minor", memberType: "girl",
      createdAt: Timestamp.now(), dateOfBirth: Timestamp.fromDate(new Date("2015-01-01")),
      guardianUids: [GUARDIAN], linkedChildUids: [], inviteCode: "ABC123",
    });
    await setDoc(doc(f, "users", MINOR_UNLINKED), {
      firstName: MINOR_UNLINKED, lastName: "T", email: `${MINOR_UNLINKED}@example.com`, role: "minor", memberType: "girl",
      createdAt: Timestamp.now(), dateOfBirth: Timestamp.fromDate(new Date("2015-01-01")),
      guardianUids: [], linkedChildUids: [], inviteCode: "XYZ999",
    });
    await setDoc(doc(f, "users", GUARDIAN), {
      firstName: GUARDIAN, lastName: "T", email: `${GUARDIAN}@example.com`, role: "guardian", memberType: "parent",
      createdAt: Timestamp.now(), dateOfBirth: Timestamp.fromDate(new Date("1985-01-01")),
      guardianUids: [], linkedChildUids: [MINOR],
    });
    await user(GUARDIAN_UNLINKED, "guardian");
    await setDoc(doc(f, "session_registrations", REG_MINOR), registration(MINOR));
    await setDoc(doc(f, "bloom_sessions", SESSION), sessionDoc());
    await setDoc(doc(f, "bloom_sessions", "draftSess"), sessionDoc({ status: "draft" }));
    await setDoc(doc(f, "bloom_sessions", "sessOpen"), sessionDoc());
    await setDoc(doc(f, "bloom_sessions", "sessCancelled"), sessionDoc({ status: "cancelled" }));
    const utcMidnight = (daysFromToday) => { const d = new Date(); return Timestamp.fromDate(new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + daysFromToday))); };
    await setDoc(doc(f, "bloom_sessions", "sessPastDeadline"), sessionDoc({ registrationDeadline: utcMidnight(-3) }));
    await setDoc(doc(f, "bloom_sessions", "sessFutureDeadline"), sessionDoc({ registrationDeadline: utcMidnight(5) }));
    await setDoc(doc(f, "bloom_sessions", SESSION, "private", "zoomHost"), { startUrl: "https://zoom.us/s/secret", hostEmail: "s@example.com", speakerUid: SPEAKER, updatedAt: Timestamp.now() });
    await setDoc(doc(f, "session_registrations", REG_P1), registration(P1));
    await setDoc(doc(f, "session_registrations", REG_P2), registration(P2, { attended: true, status: "attended" }));
    await setDoc(doc(f, "partners", PARTNER_A), partnerDoc({ status: "approved" }));
    await setDoc(doc(f, "partners", PARTNER_B), partnerDoc({ businessName: "Other Biz" }));
    await setDoc(doc(f, "rewards", "rewardA"), rewardDoc());
    await setDoc(doc(f, "rewards", "rewardPending"), rewardDoc({ status: "pending" }));
    await setDoc(doc(f, "reward_redemptions", "redA"), { rewardId: "rewardA", rewardName: "Gift Card", partnerUid: PARTNER_A, partnerName: "Biz", participantUid: P1, badgeCost: 2, code: "ABCD2345", status: "pending", createdAt: Timestamp.now(), usedAt: null, usedByPartnerUid: null });
    await setDoc(doc(f, "donations", "donA"), { partnerId: PARTNER_A, partnerName: "Biz", email: "biz@example.com", amount: 2500, currency: "usd", purpose: "Workshop", status: "pending", stripeCheckoutSessionId: "cs_test_x", stripePaymentIntentId: null, createdAt: Timestamp.now(), paidAt: null });
    await setDoc(doc(f, "donations", "donB"), { partnerId: PARTNER_B, partnerName: "Other", email: "o@example.com", amount: 5000, currency: "usd", purpose: "Other", status: "paid", stripeCheckoutSessionId: "cs_test_y", stripePaymentIntentId: "pi_y", createdAt: Timestamp.now(), paidAt: Timestamp.now() });
    await setDoc(doc(f, "session_surveys", REG_P2), { sessionId: SESSION, participantUid: P2, learningRating: 5, confidenceAfter: 4, applicationLikelihood: "yes", mostValuableLearning: "private reflection", futureSupportInterest: "yes", submittedAt: Timestamp.now() });
    await setDoc(doc(f, "session_checkins", REG_P2), { sessionId: SESSION, participantUid: P2, knowledgeBefore: 2, confidenceBefore: 2, learningGoal: "private goal", submittedAt: Timestamp.now() });
    await setDoc(doc(f, "app_notifications", "n1"), { uid: P1, type: "general", title: "t", body: "b", read: false, sessionId: null, createdAt: Timestamp.now() });
    await setDoc(doc(f, "stripe_webhook_events", "evt_1"), { type: "checkout.session.completed", processedAt: Timestamp.now(), donationId: "donA" });
    await setDoc(doc(f, "attendance_sync_log", "log1"), { sessionId: SESSION, status: "success" });
  });
});

describe("Users & roles", () => {
  test("participant cannot escalate own role to admin", async () => {
    await assertFails(updateDoc(doc(db(P1), "users", P1), { role: "admin" }));
  });
  test("participant cannot read another user's profile", async () => {
    await assertFails(getDoc(doc(db(P1), "users", P2)));
  });
  test("participant can read own profile", async () => {
    await assertSucceeds(getDoc(doc(db(P1), "users", P1)));
  });
  test("unauthenticated user cannot read any profile", async () => {
    await assertFails(getDoc(doc(anon(), "users", P1)));
  });
  test("admin can read any profile", async () => {
    await assertSucceeds(getDoc(doc(db(ADMIN), "users", P1)));
  });
});

describe("Guardian linking (Girl/Woman/Parent role split)", () => {
  test("a linked guardian can read her minor's profile", async () => {
    await assertSucceeds(getDoc(doc(db(GUARDIAN), "users", MINOR)));
  });
  test("an UNLINKED guardian cannot read a minor's profile just by having the guardian role", async () => {
    await assertFails(getDoc(doc(db(GUARDIAN_UNLINKED), "users", MINOR)));
  });
  test("a plain member (Woman) cannot read a minor's profile", async () => {
    await assertFails(getDoc(doc(db(P1), "users", MINOR)));
  });
  test("a minor cannot read another minor's profile", async () => {
    await assertFails(getDoc(doc(db(MINOR), "users", MINOR_UNLINKED)));
  });
  test("a linked guardian can read her minor's registrations/badges", async () => {
    await assertSucceeds(getDoc(doc(db(GUARDIAN), "session_registrations", REG_MINOR)));
  });
  test("an unlinked guardian cannot read a minor's registrations", async () => {
    await assertFails(getDoc(doc(db(GUARDIAN_UNLINKED), "session_registrations", REG_MINOR)));
  });
  test("a linked guardian can probe her OWN minor's not-yet-existing badge (existence check)", async () => {
    await assertSucceeds(getDoc(doc(db(GUARDIAN), "session_badges", REG_MINOR)));
  });
  test("an unlinked guardian cannot probe a minor's not-yet-existing badge", async () => {
    await assertFails(getDoc(doc(db(GUARDIAN_UNLINKED), "session_badges", REG_MINOR)));
  });

  test("a minor cannot self-write guardianUids", async () => {
    await assertFails(updateDoc(doc(db(MINOR), "users", MINOR), { guardianUids: [MINOR] }));
  });
  test("a minor cannot self-write linkedChildUids", async () => {
    await assertFails(updateDoc(doc(db(MINOR), "users", MINOR), { linkedChildUids: ["someone"] }));
  });
  test("a guardian cannot self-write linkedChildUids", async () => {
    await assertFails(updateDoc(doc(db(GUARDIAN), "users", GUARDIAN), { linkedChildUids: [MINOR, "extraKid"] }));
  });
  test("a minor cannot self-write her own inviteCode", async () => {
    await assertFails(updateDoc(doc(db(MINOR), "users", MINOR), { inviteCode: "HACKED" }));
  });
  test("a minor CAN self-update unrelated fields (e.g. photoUrl) without touching guardian-link fields", async () => {
    await assertSucceeds(updateDoc(doc(db(MINOR), "users", MINOR), { photoUrl: "https://example.com/p.jpg" }));
  });
  test("a minor cannot self-escalate role away from minor", async () => {
    await assertFails(updateDoc(doc(db(MINOR), "users", MINOR), { role: "member" }));
  });

  test("self-create as a minor requires an age-appropriate (8-17) dateOfBirth", async () => {
    const tooOld = Timestamp.fromDate(new Date("1990-01-01"));
    await assertFails(setDoc(doc(db("newMinor"), "users", "newMinor"), {
      firstName: "New", lastName: "Girl", email: "newMinor@example.com", role: "minor", memberType: "girl",
      createdAt: serverTimestamp(), dateOfBirth: tooOld, guardianUids: [], linkedChildUids: [],
    }));
  });
  test("self-create as a minor with an age-appropriate dateOfBirth succeeds", async () => {
    const age12 = Timestamp.fromDate(new Date(new Date().getFullYear() - 12, 0, 1));
    await assertSucceeds(setDoc(doc(db("newMinor2"), "users", "newMinor2"), {
      firstName: "New", lastName: "Girl", email: "newMinor2@example.com", role: "minor", memberType: "girl",
      createdAt: serverTimestamp(), dateOfBirth: age12, guardianUids: [], linkedChildUids: [],
    }));
  });
  test("self-create as member (Woman) under 18 is rejected", async () => {
    const age15 = Timestamp.fromDate(new Date(new Date().getFullYear() - 15, 0, 1));
    await assertFails(setDoc(doc(db("tooYoungWoman"), "users", "tooYoungWoman"), {
      firstName: "Too", lastName: "Young", email: "tooYoungWoman@example.com", role: "member", memberType: "woman",
      createdAt: serverTimestamp(), dateOfBirth: age15,
    }));
  });
  test("self-create as guardian under 18 is rejected", async () => {
    const age15 = Timestamp.fromDate(new Date(new Date().getFullYear() - 15, 0, 1));
    await assertFails(setDoc(doc(db("tooYoungGuardian"), "users", "tooYoungGuardian"), {
      firstName: "Too", lastName: "Young", email: "tooYoungGuardian@example.com", role: "guardian", memberType: "parent",
      createdAt: serverTimestamp(), dateOfBirth: age15,
    }));
  });
  test("self-create as a minor cannot pre-seed guardianUids (must start empty)", async () => {
    const age12 = Timestamp.fromDate(new Date(new Date().getFullYear() - 12, 0, 1));
    await assertFails(setDoc(doc(db("sneakyMinor"), "users", "sneakyMinor"), {
      firstName: "Sneaky", lastName: "Girl", email: "sneakyMinor@example.com", role: "minor", memberType: "girl",
      createdAt: serverTimestamp(), dateOfBirth: age12, guardianUids: [ADMIN], linkedChildUids: [],
    }));
  });
  test("self-create cannot set inviteCode directly (must be absent)", async () => {
    const age12 = Timestamp.fromDate(new Date(new Date().getFullYear() - 12, 0, 1));
    await assertFails(setDoc(doc(db("sneakyMinor2"), "users", "sneakyMinor2"), {
      firstName: "Sneaky", lastName: "Girl", email: "sneakyMinor2@example.com", role: "minor", memberType: "girl",
      createdAt: serverTimestamp(), dateOfBirth: age12, guardianUids: [], linkedChildUids: [], inviteCode: "FAKE01",
    }));
  });

  test("the invite_codes collection is never client-readable or writable, even by the minor it belongs to", async () => {
    await assertFails(getDoc(doc(db(MINOR), "invite_codes", "ABC123")));
    await assertFails(setDoc(doc(db(MINOR), "invite_codes", "ABC123"), { minorUid: MINOR, createdAt: Timestamp.now() }));
    await assertFails(getDoc(doc(db(ADMIN), "invite_codes", "ABC123")));
  });
});

describe("Sessions", () => {
  test("participant can read a published session", async () => {
    await assertSucceeds(getDoc(doc(db(P1), "bloom_sessions", SESSION)));
  });
  test("participant cannot read a draft session", async () => {
    await assertFails(getDoc(doc(db(P1), "bloom_sessions", "draftSess")));
  });
  test("participant cannot create or edit a session", async () => {
    await assertFails(setDoc(doc(db(P1), "bloom_sessions", "x"), sessionDoc()));
    await assertFails(updateDoc(doc(db(P1), "bloom_sessions", SESSION), { title: "hacked" }));
  });
  test("admin can create a session", async () => {
    await assertSucceeds(setDoc(doc(db(ADMIN), "bloom_sessions", "adminNew"), sessionDoc()));
  });
  test("participant cannot read the host-only Zoom start link", async () => {
    await assertFails(getDoc(doc(db(P1), "bloom_sessions", SESSION, "private", "zoomHost")));
  });
  test("a different speaker cannot read another speaker's start link", async () => {
    await assertFails(getDoc(doc(db(SPEAKER_2), "bloom_sessions", SESSION, "private", "zoomHost")));
  });
  test("the assigned speaker can read their start link", async () => {
    await assertSucceeds(getDoc(doc(db(SPEAKER), "bloom_sessions", SESSION, "private", "zoomHost")));
  });
  test("nobody (not even admin) can write the start link from a client", async () => {
    await assertFails(setDoc(doc(db(ADMIN), "bloom_sessions", SESSION, "private", "zoomHost"), { startUrl: "x", speakerUid: ADMIN }));
  });
});

describe("Registrations & attendance", () => {
  const reg = (sessionId, uid, { fields = {} } = {}) => setDoc(doc(db(uid), "session_registrations", `${sessionId}_${uid}`), { ...registration(uid), sessionId, ...fields });

  test("participant can register for an open published session", async () => {
    await assertSucceeds(reg("sessOpen", P1));
  });
  test("participant can register before a future deadline", async () => {
    await assertSucceeds(reg("sessFutureDeadline", P1));
  });
  test("registration after the deadline is rejected server-side", async () => {
    await assertFails(reg("sessPastDeadline", P1));
  });
  test("cannot register for a draft, cancelled, or nonexistent session", async () => {
    await assertFails(reg("draftSess", P1));
    await assertFails(reg("sessCancelled", P1));
    await assertFails(reg("noSuchSession", P1));
  });
  test("duplicate registration (overwriting an existing one) is rejected", async () => {
    await assertFails(setDoc(doc(db(P1), "session_registrations", REG_P1), registration(P1)));
  });
  test("participant cannot register someone else", async () => {
    await assertFails(setDoc(doc(db(P1), "session_registrations", "sessOpen_" + P2), { ...registration(P2), sessionId: "sessOpen" }));
  });
  test("participant cannot create a registration pre-marked attended", async () => {
    await assertFails(reg("sessOpen", P1, { fields: { attended: true } }));
  });
  test("participant cannot self-mark attended", async () => {
    await assertFails(updateDoc(doc(db(P1), "session_registrations", REG_P1), { attended: true, status: "attended" }));
  });
  test("participant cannot set attendance percent / source", async () => {
    await assertFails(updateDoc(doc(db(P1), "session_registrations", REG_P1), { attendancePercent: 100, attendanceSource: "zoom_import" }));
  });
  test("participant can check themself in", async () => {
    await assertSucceeds(updateDoc(doc(db(P1), "session_registrations", REG_P1), { checkedIn: true, status: "checkInAvailable" }));
  });
  test("participant cannot read another participant's registration", async () => {
    await assertFails(getDoc(doc(db(P1), "session_registrations", REG_P2)));
  });
  test("participant cannot complete survey when not attended", async () => {
    await assertFails(updateDoc(doc(db(P1), "session_registrations", REG_P1), { surveyCompleted: true, completionMet: true, status: "completed" }));
  });
  test("participant CAN complete survey once admin recorded attended", async () => {
    await assertSucceeds(updateDoc(doc(db(P2), "session_registrations", REG_P2), { surveyCompleted: true, completionMet: true, status: "completed" }));
  });
  test("admin can record attendance with audit stamp", async () => {
    await assertSucceeds(updateDoc(doc(db(ADMIN), "session_registrations", REG_P1), { attended: true, status: "attended", attendanceSource: "manual", attendanceCorrectedBy: ADMIN, attendanceCorrectedAt: serverTimestamp() }));
  });
  test("admin cannot forge the audit stamp as another admin", async () => {
    await assertFails(updateDoc(doc(db(ADMIN), "session_registrations", REG_P1), { attended: true, status: "attended", attendanceSource: "manual", attendanceCorrectedBy: "someoneElse" }));
  });
  test("partner cannot read participant registrations", async () => {
    await assertFails(getDoc(doc(db(PARTNER_A), "session_registrations", REG_P1)));
  });
});

describe("Reads of not-yet-existing participant docs (app existence checks)", () => {
  for (const coll of ["session_registrations", "session_checkins", "session_surveys", "session_badges"]) {
    test(`participant can get() their OWN not-yet-existing ${coll} doc`, async () => {
      const snap = await assertSucceeds(getDoc(doc(db(P1), coll, `sessOpen_${P1}`)));
      if (snap.exists()) throw new Error("expected non-existent doc");
    });
    test(`participant cannot probe ANOTHER user's not-yet-existing ${coll} doc`, async () => {
      await assertFails(getDoc(doc(db(P1), coll, `sessOpen_${P2}`)));
    });
  }
  test("participant can listen to their own not-yet-existing registration", async () => {
    await assertSucceeds(new Promise((resolve, reject) => {
      const unsub = onSnapshot(doc(db(P1), "session_registrations", `sessOpen_${P1}`), () => { unsub(); resolve(); }, reject);
    }));
  });
  test("list queries stay scoped to the caller", async () => {
    for (const coll of ["session_registrations", "session_badges", "session_surveys", "session_checkins"]) {
      await assertSucceeds(getDocs(query(collection(db(P1), coll), where("participantUid", "==", P1))));
      await assertFails(getDocs(query(collection(db(P1), coll), where("participantUid", "==", P2))));
      await assertFails(getDocs(collection(db(P1), coll)));
    }
  });
});

describe("Participant journey — the app's exact client call sequence", () => {
  test("register -> check-in -> (admin attendance) -> exit survey -> badge -> celebration", async () => {
    const me = db(P1);
    const regId = `sessOpen_${P1}`;
    // SessionService.registerForSession
    await assertSucceeds(getDoc(doc(me, "session_registrations", regId)));
    await assertSucceeds(setDoc(doc(me, "session_registrations", regId), { ...registration(P1), sessionId: "sessOpen", registeredAt: serverTimestamp() }));
    await assertSucceeds(setDoc(doc(me, "app_notifications", "reg_" + P1), { uid: P1, type: "registrationConfirmed", title: "Registered", body: "b", read: false, sessionId: "sessOpen", createdAt: serverTimestamp() }));
    // SessionService.submitCheckin (check-in doc + registration flip)
    await assertSucceeds(setDoc(doc(me, "session_checkins", regId), { sessionId: "sessOpen", participantUid: P1, knowledgeBefore: 2, confidenceBefore: 3, learningGoal: "g", submittedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(me, "session_registrations", regId), { checkedIn: true, status: "checkInAvailable" }));
    // Participant must not be able to jump ahead
    await assertFails(updateDoc(doc(me, "session_registrations", regId), { attended: true, status: "attended" }));
    // Admin records attendance (manual override path)
    await assertSucceeds(updateDoc(doc(db(ADMIN), "session_registrations", regId), { attended: true, status: "attended", attendanceSource: "manual", attendanceCorrectedBy: ADMIN, attendanceCorrectedAt: serverTimestamp() }));
    // SessionService.submitExitSurvey
    await assertSucceeds(getDoc(doc(me, "session_registrations", regId)));
    await assertSucceeds(getDoc(doc(me, "session_surveys", regId)));
    await assertSucceeds(setDoc(doc(me, "session_surveys", regId), { sessionId: "sessOpen", participantUid: P1, learningRating: 5, confidenceAfter: 4, applicationLikelihood: "yes", mostValuableLearning: "x", futureSupportInterest: "maybe", submittedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(me, "session_registrations", regId), { surveyCompleted: true, completionMet: true, status: "completed" }));
    await assertSucceeds(getDoc(doc(me, "session_badges", regId)));
    await assertSucceeds(setDoc(doc(me, "session_badges", regId), { sessionId: "sessOpen", participantUid: P1, sessionTitle: "Leadership Lab", program: "Leadership Lab", awardedAt: serverTimestamp(), celebrationSeen: false, redemptionId: null }));
    // Badge list the Rewards screen / My Bloom Journey read
    await assertSucceeds(getDocs(query(collection(me, "session_badges"), where("participantUid", "==", P1))));
    await assertSucceeds(getDocs(query(collection(me, "session_badges"), where("participantUid", "==", P1), where("celebrationSeen", "==", false))));
    // BadgeCelebrationListener marks it seen
    await assertSucceeds(updateDoc(doc(me, "session_badges", regId), { celebrationSeen: true }));
    // A retried survey submission cannot rewrite the survey or re-complete
    await assertFails(setDoc(doc(me, "session_surveys", regId), { sessionId: "sessOpen", participantUid: P1, learningRating: 1, confidenceAfter: 1, applicationLikelihood: "notYet", mostValuableLearning: "", futureSupportInterest: "no", submittedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(me, "session_registrations", regId), { surveyCompleted: true, completionMet: true, status: "completed" }));
  });
});

describe("Surveys & check-ins (private participant data)", () => {
  test("partner cannot read participant survey responses", async () => {
    await assertFails(getDoc(doc(db(PARTNER_A), "session_surveys", REG_P2)));
  });
  test("partner cannot read participant check-ins", async () => {
    await assertFails(getDoc(doc(db(PARTNER_A), "session_checkins", REG_P2)));
  });
  test("another participant cannot read someone's survey", async () => {
    await assertFails(getDoc(doc(db(P1), "session_surveys", REG_P2)));
  });
  test("participant can read own survey", async () => {
    await assertSucceeds(getDoc(doc(db(P2), "session_surveys", REG_P2)));
  });
  test("admin can read surveys (impact metrics)", async () => {
    await assertSucceeds(getDoc(doc(db(ADMIN), "session_surveys", REG_P2)));
  });
  test("surveys are immutable once submitted", async () => {
    await assertFails(updateDoc(doc(db(P2), "session_surveys", REG_P2), { learningRating: 1 }));
  });
  test("participant cannot submit a survey for someone else", async () => {
    await assertFails(setDoc(doc(db(P1), "session_surveys", "sessX_" + P2), { sessionId: "sessX", participantUid: P2, learningRating: 5, confidenceAfter: 5, applicationLikelihood: "yes", mostValuableLearning: "", futureSupportInterest: "yes", submittedAt: serverTimestamp() }));
  });
  test("out-of-range survey rating is rejected", async () => {
    await assertFails(setDoc(doc(db(P1), "session_surveys", "sessX_" + P1), { sessionId: "sessX", participantUid: P1, learningRating: 9, confidenceAfter: 5, applicationLikelihood: "yes", mostValuableLearning: "", futureSupportInterest: "yes", submittedAt: serverTimestamp() }));
  });
});

describe("Badges", () => {
  test("participant cannot mint a badge for a session they did not attend", async () => {
    await assertFails(setDoc(doc(db(P1), "session_badges", REG_P1), badge(P1)));
  });
  test("attended participant can create their badge at the composite id", async () => {
    await assertSucceeds(setDoc(doc(db(P2), "session_badges", REG_P2), badge(P2)));
  });
  test("attended participant cannot mint extra badges at arbitrary ids", async () => {
    await assertFails(setDoc(doc(db(P2), "session_badges", "randomId123"), badge(P2)));
  });
  test("participant cannot create a pre-spent badge", async () => {
    await assertFails(setDoc(doc(db(P2), "session_badges", REG_P2), badge(P2, { redemptionId: "x" })));
  });
  test("participant cannot mint a badge for another participant", async () => {
    await assertFails(setDoc(doc(db(P1), "session_badges", REG_P2), badge(P2)));
  });
  test("participant can only flip celebrationSeen false->true, nothing else", async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), "session_badges", REG_P2), badge(P2)));
    await assertFails(updateDoc(doc(db(P2), "session_badges", REG_P2), { redemptionId: null, sessionTitle: "changed" }));
    await assertFails(updateDoc(doc(db(P2), "session_badges", REG_P2), { redemptionId: "fakeSpend" }));
    await assertSucceeds(updateDoc(doc(db(P2), "session_badges", REG_P2), { celebrationSeen: true }));
  });
  test("participant cannot delete a badge", async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), "session_badges", REG_P2), badge(P2)));
    await assertFails(deleteDoc(doc(db(P2), "session_badges", REG_P2)));
  });
});

describe("Community Partners", () => {
  test("new partner self-registration must start pending", async () => {
    await assertSucceeds(setDoc(doc(db(P1), "partners", P1), partnerDoc()));
    await assertFails(setDoc(doc(db(P2), "partners", P2), partnerDoc({ status: "approved" })));
  });
  test("partner cannot read another partner's private doc", async () => {
    await assertFails(getDoc(doc(db(PARTNER_A), "partners", PARTNER_B)));
  });
  test("pending partner cannot self-approve", async () => {
    await assertFails(updateDoc(doc(db(PARTNER_B), "partners", PARTNER_B), { status: "approved" }));
  });
  test("partner can edit own business info", async () => {
    await assertSucceeds(updateDoc(doc(db(PARTNER_B), "partners", PARTNER_B), { description: "updated" }));
  });
  test("partner cannot self-publish to the public directory", async () => {
    await assertFails(setDoc(doc(db(PARTNER_B), "partner_profiles", PARTNER_B), { businessName: "Other Biz", description: "d", supportTypes: [], logoUrl: null, createdAt: Timestamp.now() }));
  });
  test("admin can approve a partner (stamping themself)", async () => {
    await assertSucceeds(updateDoc(doc(db(ADMIN), "partners", PARTNER_B), { status: "approved", statusUpdatedAt: serverTimestamp(), statusUpdatedBy: ADMIN }));
  });
  test("admin approval cannot rewrite partner-authored content", async () => {
    await assertFails(updateDoc(doc(db(ADMIN), "partners", PARTNER_B), { status: "approved", statusUpdatedBy: ADMIN, businessName: "Rewritten" }));
  });
  test("admin can publish the public directory entry", async () => {
    await assertSucceeds(setDoc(doc(db(ADMIN), "partner_profiles", PARTNER_B), { businessName: "Other Biz", description: "d", supportTypes: [], logoUrl: null, createdAt: Timestamp.now() }));
  });
});

describe("Rewards", () => {
  test("partner-created reward must start pending", async () => {
    await assertSucceeds(setDoc(doc(db(PARTNER_A), "rewards", "newR"), rewardDoc({ status: "pending", createdAt: serverTimestamp() })));
    await assertFails(setDoc(doc(db(PARTNER_A), "rewards", "newR2"), rewardDoc({ status: "approved", createdAt: serverTimestamp() })));
  });
  test("participant cannot create a reward", async () => {
    await assertFails(setDoc(doc(db(P1), "rewards", "hack"), rewardDoc({ partnerUid: P1, status: "pending", createdAt: serverTimestamp() })));
  });
  test("partner cannot self-approve own reward", async () => {
    await assertFails(updateDoc(doc(db(PARTNER_A), "rewards", "rewardPending"), { status: "approved" }));
  });
  test("partner cannot change remainingQuantity", async () => {
    await assertFails(updateDoc(doc(db(PARTNER_A), "rewards", "rewardA"), { remainingQuantity: 999 }));
  });
  test("participant cannot change remainingQuantity", async () => {
    await assertFails(updateDoc(doc(db(P1), "rewards", "rewardA"), { remainingQuantity: 999 }));
  });
  test("partner can pause own reward", async () => {
    await assertSucceeds(updateDoc(doc(db(PARTNER_A), "rewards", "rewardA"), { active: false }));
  });
  test("another partner cannot edit someone else's reward", async () => {
    await assertFails(updateDoc(doc(db(PARTNER_B), "rewards", "rewardA"), { active: false }));
  });
  test("admin can approve a reward", async () => {
    await assertSucceeds(updateDoc(doc(db(ADMIN), "rewards", "rewardPending"), { status: "approved", reviewNotes: "" }));
  });
  test("admin review cannot alter inventory or badge cost", async () => {
    await assertFails(updateDoc(doc(db(ADMIN), "rewards", "rewardPending"), { status: "approved", remainingQuantity: 0 }));
    await assertFails(updateDoc(doc(db(ADMIN), "rewards", "rewardPending"), { status: "approved", badgeCost: 1 }));
  });
});

describe("Reward redemptions", () => {
  test("participant cannot create a redemption/code directly", async () => {
    await assertFails(setDoc(doc(db(P1), "reward_redemptions", "fake"), { rewardId: "rewardA", partnerUid: PARTNER_A, participantUid: P1, code: "FAKECODE", status: "pending" }));
  });
  test("participant cannot mark own redemption used", async () => {
    await assertFails(updateDoc(doc(db(P1), "reward_redemptions", "redA"), { status: "used" }));
  });
  test("partner cannot mark a redemption used directly (must use Cloud Function)", async () => {
    await assertFails(updateDoc(doc(db(PARTNER_A), "reward_redemptions", "redA"), { status: "used" }));
  });
  test("participant can read own redemption; owning partner can too", async () => {
    await assertSucceeds(getDoc(doc(db(P1), "reward_redemptions", "redA")));
    await assertSucceeds(getDoc(doc(db(PARTNER_A), "reward_redemptions", "redA")));
  });
  test("other participant and other partner cannot read it", async () => {
    await assertFails(getDoc(doc(db(P2), "reward_redemptions", "redA")));
    await assertFails(getDoc(doc(db(PARTNER_B), "reward_redemptions", "redA")));
  });
});

describe("Donations & Stripe ledger", () => {
  test("no client (even admin) can create a donation", async () => {
    await assertFails(setDoc(doc(db(PARTNER_A), "donations", "fake"), { partnerId: PARTNER_A, amount: 100, status: "paid" }));
    await assertFails(setDoc(doc(db(ADMIN), "donations", "fake2"), { partnerId: ADMIN, amount: 100, status: "paid" }));
  });
  test("partner cannot mark own donation paid or fabricate a payment id", async () => {
    await assertFails(updateDoc(doc(db(PARTNER_A), "donations", "donA"), { status: "paid" }));
    await assertFails(updateDoc(doc(db(PARTNER_A), "donations", "donA"), { stripePaymentIntentId: "pi_fabricated" }));
  });
  test("partner can read own donation, not another partner's", async () => {
    await assertSucceeds(getDoc(doc(db(PARTNER_A), "donations", "donA")));
    await assertFails(getDoc(doc(db(PARTNER_A), "donations", "donB")));
  });
  test("participant cannot read donations", async () => {
    await assertFails(getDoc(doc(db(P1), "donations", "donA")));
  });
  test("partner query for all donations is rejected (list isolation)", async () => {
    await assertFails(getDocs(collection(db(PARTNER_A), "donations")));
    await assertSucceeds(getDocs(query(collection(db(PARTNER_A), "donations"), where("partnerId", "==", PARTNER_A))));
  });
  test("admin can read all donations", async () => {
    await assertSucceeds(getDocs(collection(db(ADMIN), "donations")));
  });
  test("webhook idempotency ledger is not client-writable or partner-readable", async () => {
    await assertFails(setDoc(doc(db(ADMIN), "stripe_webhook_events", "evt_x"), { type: "x" }));
    await assertFails(getDoc(doc(db(PARTNER_A), "stripe_webhook_events", "evt_1")));
    await assertSucceeds(getDoc(doc(db(ADMIN), "stripe_webhook_events", "evt_1")));
  });
  test("attendance sync audit log is not client-writable", async () => {
    await assertFails(setDoc(doc(db(ADMIN), "attendance_sync_log", "fake"), { status: "success" }));
    await assertFails(getDoc(doc(db(P1), "attendance_sync_log", "log1")));
  });
});

describe("Notifications", () => {
  test("user can read own notification, not others'", async () => {
    await assertSucceeds(getDoc(doc(db(P1), "app_notifications", "n1")));
    await assertFails(getDoc(doc(db(P2), "app_notifications", "n1")));
  });
  test("user can only mark read, not rewrite content", async () => {
    await assertSucceeds(updateDoc(doc(db(P1), "app_notifications", "n1"), { read: true }));
    await assertFails(updateDoc(doc(db(P1), "app_notifications", "n1"), { title: "changed" }));
  });
  test("FIXED (M-6): a signed-in user can no longer inject a notification into another user's inbox", async () => {
    // Previously any signed-in user could create a notification for any
    // uid (see git history / QA report finding M-6) — a phishing and
    // harassment vector. Fan-out to other users now happens exclusively
    // server-side via the notifySessionRegistrants Cloud Function (Admin
    // SDK, bypasses these rules entirely), so a client can only ever
    // create a notification addressed to itself.
    await assertFails(setDoc(doc(db(P2), "app_notifications", "spoof"), { uid: P1, type: "general", title: "Your account is suspended", body: "click here", read: false, sessionId: null, createdAt: serverTimestamp() }));
  });
  test("a user can still create a notification addressed to themself", async () => {
    await assertSucceeds(setDoc(doc(db(P2), "app_notifications", "selfNotify"), { uid: P2, type: "registrationConfirmed", title: "Registered", body: "b", read: false, sessionId: "sessOpen", createdAt: serverTimestamp() }));
  });
  test("admin cannot create a notification for another user directly (must use the Cloud Function)", async () => {
    await assertFails(setDoc(doc(db(ADMIN), "app_notifications", "adminSpoof"), { uid: P1, type: "sessionUpdated", title: "t", body: "b", read: false, sessionId: null, createdAt: serverTimestamp() }));
  });
});
