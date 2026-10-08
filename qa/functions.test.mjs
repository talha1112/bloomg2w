// Runtime tests for the Cloud Functions: the COMPILED handlers in
// functions/lib are invoked in-process (callable `.run()` / onRequest
// handler) against the Firestore EMULATOR under project demo-bloomg2w.
// Real handler code, real Firestore transactions, real Stripe signature
// verification — no production project, no real Stripe/Zoom credentials.
// (The Functions emulator's discovery step hangs on this machine; auth
// token rejection is separately verified against the deployed functions.)
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { before, describe, test } from "node:test";

process.env.GCLOUD_PROJECT = "demo-bloomg2w";
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: "demo-bloomg2w" });
process.env.ZOOM_ACCOUNT_ID = "qa-dummy";
process.env.ZOOM_CLIENT_ID = "qa-dummy";
process.env.ZOOM_CLIENT_SECRET = "qa-dummy";
process.env.STRIPE_SECRET_KEY = "sk_test_qa_dummy_emulator_only_not_a_real_key";
process.env.STRIPE_WEBHOOK_SECRET = "whsec_qa_local_emulator_only";
assert.ok(process.env.FIRESTORE_EMULATOR_HOST, "must run under the Firestore emulator");

const fnRequire = createRequire(new URL("../functions/package.json", import.meta.url));
const fns = fnRequire("./lib/index.js");
const { getFirestore, Timestamp } = fnRequire("firebase-admin/firestore");
const { getAuth } = fnRequire("firebase-admin/auth");
const Stripe = fnRequire("stripe");

const db = getFirestore("bloomg2w-db");
const auth = getAuth();
const stripe = new Stripe("sk_test_qa_dummy_emulator_only_not_a_real_key");
const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;

let n = 0;
async function user(role) {
  const uid = `qa_${role}_${Date.now()}_${n++}`;
  await db.collection("users").doc(uid).set({ firstName: "QA", lastName: role, email: `${uid}@example.com`, role, memberType: "woman", createdAt: Timestamp.now() });
  return uid;
}

// Like user(), but also creates a real (Auth-emulator) account at that uid —
// needed only for deleteOwnAccount tests, which call getAuth().deleteUser()
// as their final step. Every other test in this file never touches Auth,
// so the plain user() helper above is left untouched for them.
async function authUser(role, overrides = {}) {
  const uid = `qa_${role}_${Date.now()}_${n++}`;
  await auth.createUser({ uid, email: `${uid}@example.com` });
  await db.collection("users").doc(uid).set({ firstName: "QA", lastName: role, email: `${uid}@example.com`, role, memberType: "woman", createdAt: Timestamp.now(), guardianUids: [], linkedChildUids: [], ...overrides });
  return uid;
}

async function call(name, uid, data) {
  try {
    const result = await fns[name].run({ data, auth: uid ? { uid, token: { uid } } : undefined, rawRequest: { headers: {} } });
    return { result };
  } catch (e) {
    return { error: e.code, message: e.message };
  }
}

// Like call(), but also sets auth.token.email — needed for
// completeMinorSignup, which cross-checks the submitted email against the
// authenticated token's email (the same way Firestore rules' isValidNewMemberDoc
// does for d.email == request.auth.token.email on a normal client write).
async function callAsEmail(name, uid, email, data) {
  try {
    const result = await fns[name].run({ data, auth: uid ? { uid, token: { uid, email } } : undefined, rawRequest: { headers: {} } });
    return { result };
  } catch (e) {
    return { error: e.code, message: e.message };
  }
}

async function webhook(payloadObj, { secret = WEBHOOK_SECRET, timestamp, header } = {}) {
  const payload = JSON.stringify(payloadObj);
  const sig = header !== undefined ? header : stripe.webhooks.generateTestHeaderString({ payload, secret, ...(timestamp ? { timestamp } : {}) });
  const headers = sig === null ? {} : { "stripe-signature": sig };
  const res = { statusCode: 200, body: "" };
  res.status = (c) => { res.statusCode = c; return res; };
  res.send = (b) => { res.body = String(b); return res; };
  await fns.stripeWebhook({ method: "POST", headers, rawBody: Buffer.from(payload), body: payloadObj }, res);
  return { status: res.statusCode, body: res.body };
}

const evt = (id, type, obj) => ({ id, object: "event", type, data: { object: obj } });

async function badges(uid, count, prefix = "s") {
  for (let i = 0; i < count; i++) {
    await db.collection("session_badges").doc(`${prefix}${i}_${uid}`).set({ sessionId: `${prefix}${i}`, participantUid: uid, sessionTitle: "T", program: "P", awardedAt: Timestamp.now(), celebrationSeen: true, redemptionId: null });
  }
}

async function reward(overrides = {}) {
  const ref = db.collection("rewards").doc();
  await ref.set({ partnerUid: "p", partnerName: "Biz", name: "Gift Card", value: 25, quantityAvailable: 5, remainingQuantity: 5, badgeCost: 2, description: "", expirationDate: null, restrictions: null, active: true, status: "approved", reviewNotes: "", createdAt: Timestamp.now(), ...overrides });
  return ref;
}

const unspent = async (uid) => (await db.collection("session_badges").where("participantUid", "==", uid).where("redemptionId", "==", null).get()).size;

let admin, member, partnerApproved, partnerPending;
before(async () => {
  admin = await user("admin");
  member = await user("member");
  partnerApproved = await user("partner");
  partnerPending = await user("partner");
  await db.collection("partners").doc(partnerApproved).set({ businessName: "Approved Biz", email: "a@example.com", status: "approved" });
  await db.collection("partners").doc(partnerPending).set({ businessName: "Pending Biz", email: "p@example.com", status: "pending" });
});

describe("redeemReward", () => {
  test("rejects unauthenticated caller", async () => {
    assert.equal((await call("redeemReward", null, { rewardId: "x" })).error, "unauthenticated");
  });

  test("rejects a reward still pending admin approval (no badges spent)", async () => {
    const p = await user("member"); await badges(p, 5);
    const ref = await reward({ status: "pending" });
    assert.equal((await call("redeemReward", p, { rewardId: ref.id })).error, "failed-precondition");
    assert.equal(await unspent(p), 5);
  });

  test("rejects a paused, expired, or out-of-stock reward", async () => {
    const p = await user("member"); await badges(p, 5);
    for (const overrides of [{ active: false }, { expirationDate: Timestamp.fromDate(new Date(Date.now() - 864e5)) }, { remainingQuantity: 0 }]) {
      const ref = await reward(overrides);
      assert.equal((await call("redeemReward", p, { rewardId: ref.id })).error, "failed-precondition", JSON.stringify(Object.keys(overrides)));
    }
    assert.equal(await unspent(p), 5);
  });

  test("rejects a nonexistent reward", async () => {
    const p = await user("member"); await badges(p, 5);
    assert.equal((await call("redeemReward", p, { rewardId: "doesNotExist" })).error, "not-found");
  });

  test("rejects when participant lacks enough unspent badges", async () => {
    const p = await user("member"); await badges(p, 1);
    const ref = await reward({ badgeCost: 2 });
    assert.equal((await call("redeemReward", p, { rewardId: ref.id })).error, "failed-precondition");
    assert.equal((await ref.get()).data().remainingQuantity, 5);
  });

  test("happy path: spends exactly badgeCost badges, decrements stock, issues an 8-char code", async () => {
    const p = await user("member"); await badges(p, 3);
    const ref = await reward({ badgeCost: 2, partnerUid: partnerApproved });
    const r = await call("redeemReward", p, { rewardId: ref.id });
    assert.ok(r.result?.success, JSON.stringify(r));
    assert.match(r.result.code, /^[A-HJ-NP-Z2-9]{8}$/);
    assert.equal(await unspent(p), 1);
    assert.equal((await ref.get()).data().remainingQuantity, 4);
    const red = (await db.collection("reward_redemptions").doc(r.result.redemptionId).get()).data();
    assert.equal(red.participantUid, p);
    assert.equal(red.partnerUid, partnerApproved);
    assert.equal(red.rewardId, ref.id);
    assert.equal(red.status, "pending");
    assert.equal(red.code, r.result.code);
    const spent = (await db.collection("session_badges").where("redemptionId", "==", r.result.redemptionId).get()).size;
    assert.equal(spent, 2, "the spent badges are tagged with this exact redemption");
  });

  test("already-spent badges cannot be spent again", async () => {
    const p = await user("member"); await badges(p, 2);
    const ref = await reward({ badgeCost: 2 });
    assert.ok((await call("redeemReward", p, { rewardId: ref.id })).result?.success);
    assert.equal((await call("redeemReward", p, { rewardId: ref.id })).error, "failed-precondition");
    assert.equal((await ref.get()).data().remainingQuantity, 4);
  });

  test("CONCURRENCY: same participant, badges for only one redemption -> exactly one succeeds", async () => {
    const p = await user("member"); await badges(p, 2);
    const ref = await reward({ badgeCost: 2, quantityAvailable: 10, remainingQuantity: 10 });
    const results = await Promise.all(Array.from({ length: 4 }, () => call("redeemReward", p, { rewardId: ref.id })));
    assert.equal(results.filter((r) => r.result?.success).length, 1, JSON.stringify(results));
    assert.equal(await unspent(p), 0);
    assert.equal((await ref.get()).data().remainingQuantity, 9);
    assert.equal((await db.collection("reward_redemptions").where("participantUid", "==", p).get()).size, 1);
  });

  test("CONCURRENCY: last unit of inventory, 5 eligible participants -> exactly one wins, stock never negative", async () => {
    const ref = await reward({ badgeCost: 1, quantityAvailable: 1, remainingQuantity: 1 });
    const people = [];
    for (let i = 0; i < 5; i++) { const p = await user("member"); await badges(p, 1, `inv${i}_`); people.push(p); }
    const results = await Promise.all(people.map((p) => call("redeemReward", p, { rewardId: ref.id })));
    assert.equal(results.filter((r) => r.result?.success).length, 1, JSON.stringify(results));
    assert.equal((await ref.get()).data().remainingQuantity, 0);
    assert.equal((await db.collection("reward_redemptions").where("rewardId", "==", ref.id).get()).size, 1);
    let unspentTotal = 0; for (const p of people) unspentTotal += await unspent(p);
    assert.equal(unspentTotal, 4, "losers keep their badges");
  });

  test("codes are unique across many redemptions", async () => {
    const p = await user("member"); await badges(p, 12);
    const ref = await reward({ badgeCost: 1, quantityAvailable: 12, remainingQuantity: 12 });
    const codes = [];
    for (let i = 0; i < 12; i++) codes.push((await call("redeemReward", p, { rewardId: ref.id })).result.code);
    assert.equal(new Set(codes).size, 12);
  });
});

describe("markRedemptionUsed (partner verification, one-time)", () => {
  async function issued(partnerUid) {
    const p = await user("member"); await badges(p, 1);
    const ref = await reward({ badgeCost: 1, partnerUid });
    const r = await call("redeemReward", p, { rewardId: ref.id });
    return { participant: p, code: r.result.code, redemptionId: r.result.redemptionId };
  }

  test("another partner cannot verify this partner's code", async () => {
    const { code, redemptionId } = await issued(partnerApproved);
    assert.equal((await call("markRedemptionUsed", partnerPending, { code })).error, "not-found");
    assert.equal((await db.collection("reward_redemptions").doc(redemptionId).get()).data().status, "pending");
  });

  test("participant cannot mark their own code used", async () => {
    const { participant, code, redemptionId } = await issued(partnerApproved);
    assert.equal((await call("markRedemptionUsed", participant, { code })).error, "not-found");
    assert.equal((await db.collection("reward_redemptions").doc(redemptionId).get()).data().status, "pending");
  });

  test("owning partner verifies once (code normalized); second attempt rejected; one thank-you notification", async () => {
    const { code, redemptionId } = await issued(partnerApproved);
    const before = (await db.collection("app_notifications").where("uid", "==", partnerApproved).get()).size;
    const first = await call("markRedemptionUsed", partnerApproved, { code: `  ${code.toLowerCase()} ` });
    assert.ok(first.result?.success, JSON.stringify(first));
    const doc = (await db.collection("reward_redemptions").doc(redemptionId).get()).data();
    assert.equal(doc.status, "used");
    assert.equal(doc.usedByPartnerUid, partnerApproved);
    assert.ok(doc.usedAt);
    const second = await call("markRedemptionUsed", partnerApproved, { code });
    assert.equal(second.error, "failed-precondition");
    assert.match(second.message, /already been redeemed/i);
    const notes = (await db.collection("app_notifications").where("uid", "==", partnerApproved).get()).docs.map((d) => d.data());
    assert.equal(notes.length, before + 1, "exactly one thank-you notification");
    assert.match(notes.map((x) => x.body).join(" "), /Building a Nation of Bloomers/);
  });

  test("CONCURRENCY: simultaneous verifications of one code -> exactly one succeeds", async () => {
    const { code } = await issued(partnerApproved);
    const results = await Promise.all(Array.from({ length: 5 }, () => call("markRedemptionUsed", partnerApproved, { code })));
    assert.equal(results.filter((r) => r.result?.success).length, 1, JSON.stringify(results));
  });

  test("invalid code is rejected", async () => {
    assert.equal((await call("markRedemptionUsed", partnerApproved, { code: "NOPE0000" })).error, "not-found");
  });
});

describe("createDonationCheckout", () => {
  const valid = { amountCents: 2500, currency: "usd", purpose: "Workshop" };

  test("unauthenticated caller rejected", async () => {
    assert.equal((await call("createDonationCheckout", null, valid)).error, "unauthenticated");
  });

  test("regular participant cannot create a donation", async () => {
    assert.equal((await call("createDonationCheckout", member, valid)).error, "permission-denied");
  });

  test("pending (unapproved) partner cannot create a donation", async () => {
    assert.equal((await call("createDonationCheckout", partnerPending, valid)).error, "permission-denied");
  });

  test("server-side amount/currency/purpose validation", async () => {
    for (const bad of [{ amountCents: 0 }, { amountCents: -500 }, { amountCents: 99 }, { amountCents: 2500.5 }, { amountCents: 10_000_001 }, { amountCents: "2500" }, { currency: "eur" }, { purpose: "Anything" }]) {
      assert.equal((await call("createDonationCheckout", partnerApproved, { ...valid, ...bad })).error, "invalid-argument", JSON.stringify(bad));
    }
  });

  test("invalid input never creates a donation record", async () => {
    const count = async () => (await db.collection("donations").where("partnerId", "==", partnerApproved).get()).size;
    const before = await count();
    await call("createDonationCheckout", partnerApproved, { ...valid, amountCents: -1 });
    await call("createDonationCheckout", partnerApproved, { ...valid, purpose: "x" });
    assert.equal(await count(), before);
  });

  test("Stripe API failure marks the donation failed (never stuck pending, never paid)", async () => {
    // Dummy Stripe key -> Stripe rejects session creation.
    const r = await call("createDonationCheckout", partnerApproved, valid);
    assert.equal(r.error, "internal");
    const docs = (await db.collection("donations").where("partnerId", "==", partnerApproved).get()).docs.map((d) => d.data());
    assert.ok(docs.length >= 1);
    assert.ok(docs.every((d) => d.status === "failed"), JSON.stringify(docs.map((d) => d.status)));
    assert.ok(docs.every((d) => d.amount === 2500 && d.currency === "usd" && d.purpose === "Workshop" && d.partnerName === "Approved Biz"));
  });
});

describe("stripeWebhook", () => {
  async function pendingDonation() {
    const ref = db.collection("donations").doc();
    await ref.set({ partnerId: partnerApproved, partnerName: "Approved Biz", email: "x@example.com", amount: 2500, currency: "usd", purpose: "Workshop", status: "pending", stripeCheckoutSessionId: "cs_test_qa", stripePaymentIntentId: null, createdAt: Timestamp.now(), paidAt: null });
    return ref;
  }
  const completed = (id, donationId, type = "checkout.session.completed") => evt(id, type, { id: "cs_test_qa", object: "checkout.session", payment_intent: "pi_qa_123", metadata: donationId ? { donationId, partnerId: partnerApproved, purpose: "Workshop" } : {} });
  const status = async (ref) => (await ref.get()).data().status;

  test("missing signature header -> 400, no state change", async () => {
    const d = await pendingDonation();
    assert.equal((await webhook(completed("evt_nosig", d.id), { header: null })).status, 400);
    assert.equal(await status(d), "pending");
  });

  test("forged signature -> 400, no state change", async () => {
    const d = await pendingDonation();
    assert.equal((await webhook(completed("evt_forged", d.id), { header: "t=1700000000,v1=deadbeef" })).status, 400);
    assert.equal(await status(d), "pending");
  });

  test("signed with the wrong secret -> 400", async () => {
    const d = await pendingDonation();
    assert.equal((await webhook(completed("evt_wrongsecret", d.id), { secret: "whsec_attacker" })).status, 400);
    assert.equal(await status(d), "pending");
  });

  test("tampered payload (valid signature for a different body) -> 400", async () => {
    const d = await pendingDonation();
    const genuine = JSON.stringify(completed("evt_tamper", "someOtherDonation"));
    const sig = stripe.webhooks.generateTestHeaderString({ payload: genuine, secret: WEBHOOK_SECRET });
    assert.equal((await webhook(completed("evt_tamper", d.id), { header: sig })).status, 400);
    assert.equal(await status(d), "pending");
  });

  test("stale timestamp (replayed >5 min later) -> 400", async () => {
    const d = await pendingDonation();
    assert.equal((await webhook(completed("evt_stale", d.id), { timestamp: Math.floor(Date.now() / 1000) - 600 })).status, 400);
    assert.equal(await status(d), "pending");
  });

  test("valid checkout.session.completed marks donation paid with Stripe ids", async () => {
    const d = await pendingDonation();
    assert.equal((await webhook(completed("evt_ok_1", d.id))).status, 200);
    const data = (await d.get()).data();
    assert.equal(data.status, "paid");
    assert.ok(data.paidAt);
    assert.equal(data.stripePaymentIntentId, "pi_qa_123");
    assert.ok((await db.collection("stripe_webhook_events").doc("evt_ok_1").get()).exists);
  });

  test("DUPLICATE delivery of the same event (sequential + concurrent) is idempotent", async () => {
    const d = await pendingDonation();
    assert.equal((await webhook(completed("evt_dup", d.id))).status, 200);
    const paidAt1 = (await d.get()).data().paidAt.toMillis();
    await new Promise((r) => setTimeout(r, 1100));
    const results = await Promise.all([webhook(completed("evt_dup", d.id)), webhook(completed("evt_dup", d.id)), webhook(completed("evt_dup", d.id))]);
    assert.ok(results.every((x) => x.status === 200), JSON.stringify(results));
    const data = (await d.get()).data();
    assert.equal(data.status, "paid");
    assert.equal(data.paidAt.toMillis(), paidAt1, "paidAt must not be rewritten by a replay");
  });

  test("two concurrent FIRST deliveries of one event -> processed exactly once", async () => {
    const d = await pendingDonation();
    const results = await Promise.all([webhook(completed("evt_race", d.id)), webhook(completed("evt_race", d.id))]);
    assert.ok(results.every((x) => x.status === 200), JSON.stringify(results));
    assert.equal(await status(d), "paid");
  });

  test("a different success event for an already-paid donation does not re-process it", async () => {
    const d = await pendingDonation();
    await webhook(completed("evt_first", d.id));
    const paidAt1 = (await d.get()).data().paidAt.toMillis();
    await new Promise((r) => setTimeout(r, 1100));
    assert.equal((await webhook(completed("evt_second", d.id, "checkout.session.async_payment_succeeded"))).status, 200);
    assert.equal((await d.get()).data().paidAt.toMillis(), paidAt1);
    assert.equal((await db.collection("stripe_webhook_events").doc("evt_second").get()).data().note, "already paid");
  });

  test("missing donationId metadata is acknowledged and ignored", async () => {
    const r = await webhook(completed("evt_nometa", null));
    assert.equal(r.status, 200);
    assert.match(r.body, /no donationId/i);
  });

  test("unknown donationId does not create a donation", async () => {
    assert.equal((await webhook(completed("evt_ghost", "doesNotExist123"))).status, 200);
    assert.equal((await db.collection("donations").doc("doesNotExist123").get()).exists, false);
    assert.equal((await db.collection("stripe_webhook_events").doc("evt_ghost").get()).data().note, "donation not found");
  });

  test("cancelled/expired checkout marks a pending donation failed, never paid", async () => {
    const d = await pendingDonation();
    assert.equal((await webhook(evt("evt_expired", "checkout.session.expired", { id: "cs_test_qa", object: "checkout.session", metadata: { donationId: d.id } }))).status, 200);
    assert.equal(await status(d), "failed");
  });

  test("payment_intent.payment_failed marks a pending donation failed", async () => {
    const d = await pendingDonation();
    await webhook(evt("evt_pi_failed", "payment_intent.payment_failed", { id: "pi_x", object: "payment_intent", metadata: { donationId: d.id } }));
    assert.equal(await status(d), "failed");
  });

  test("a late 'expired' event cannot downgrade an already-paid donation", async () => {
    const d = await pendingDonation();
    await webhook(completed("evt_paid_then_exp", d.id));
    await webhook(evt("evt_exp_late", "checkout.session.expired", { id: "cs_test_qa", object: "checkout.session", metadata: { donationId: d.id } }));
    assert.equal(await status(d), "paid");
  });

  test("unhandled event types are acknowledged without side effects", async () => {
    const d = await pendingDonation();
    assert.equal((await webhook(evt("evt_other", "customer.created", { id: "cus_1", object: "customer", metadata: { donationId: d.id } }))).status, 200);
    assert.equal(await status(d), "pending");
  });
});

describe("notifySessionRegistrants (M-6 fix: only this server-side path may fan out notifications)", () => {
  async function sessionWithRegistrants(activeUids, cancelledUids = []) {
    const ref = db.collection("bloom_sessions").doc();
    await ref.set({ title: "Confidence Workshop", date: Timestamp.fromDate(new Date("2026-10-05T00:00:00Z")), startTime: "6:00 PM", endTime: "7:00 PM", status: "published" });
    for (const uid of activeUids) {
      await db.collection("session_registrations").doc(`${ref.id}_${uid}`).set({ sessionId: ref.id, participantUid: uid, participantName: uid, status: "registered", attended: false });
    }
    for (const uid of cancelledUids) {
      await db.collection("session_registrations").doc(`${ref.id}_${uid}`).set({ sessionId: ref.id, participantUid: uid, participantName: uid, status: "cancelled", attended: false });
    }
    return ref;
  }
  const notificationsFor = async (uid, sessionId) => (await db.collection("app_notifications").where("uid", "==", uid).where("sessionId", "==", sessionId).get()).docs.map((d) => d.data());

  test("unauthenticated caller rejected", async () => {
    const s = await sessionWithRegistrants([member]);
    assert.equal((await call("notifySessionRegistrants", null, { sessionId: s.id, kind: "sessionUpdated" })).error, "unauthenticated");
  });

  test("non-admin caller rejected", async () => {
    const s = await sessionWithRegistrants([member]);
    assert.equal((await call("notifySessionRegistrants", member, { sessionId: s.id, kind: "sessionUpdated" })).error, "permission-denied");
    assert.equal((await call("notifySessionRegistrants", partnerApproved, { sessionId: s.id, kind: "sessionUpdated" })).error, "permission-denied");
  });

  test("invalid kind rejected", async () => {
    const s = await sessionWithRegistrants([member]);
    assert.equal((await call("notifySessionRegistrants", admin, { sessionId: s.id, kind: "somethingElse" })).error, "invalid-argument");
  });

  test("missing session rejected", async () => {
    assert.equal((await call("notifySessionRegistrants", admin, { sessionId: "nope", kind: "sessionUpdated" })).error, "not-found");
  });

  test("notifies only active registrants, not cancelled ones, with the right copy per kind", async () => {
    const p1 = await user("member"), p2 = await user("member"), cancelled = await user("member");
    const s = await sessionWithRegistrants([p1, p2], [cancelled]);
    const r = await call("notifySessionRegistrants", admin, { sessionId: s.id, kind: "sessionCancelled" });
    assert.equal(r.result?.notifiedCount, 2, JSON.stringify(r));
    for (const uid of [p1, p2]) {
      const notes = await notificationsFor(uid, s.id);
      assert.equal(notes.length, 1);
      assert.equal(notes[0].type, "sessionCancelled");
      assert.match(notes[0].body, /Confidence Workshop/);
      assert.equal(notes[0].read, false);
    }
    assert.equal((await notificationsFor(cancelled, s.id)).length, 0, "cancelled registrant must not be notified");
  });

  test("each notification kind produces distinct copy", async () => {
    const p = await user("member");
    const s = await sessionWithRegistrants([p]);
    for (const kind of ["sessionUpdated", "sessionReminder", "sessionStarting"]) {
      await call("notifySessionRegistrants", admin, { sessionId: s.id, kind });
    }
    const notes = await notificationsFor(p, s.id);
    assert.equal(notes.length, 3);
    assert.deepEqual(new Set(notes.map((n) => n.type)), new Set(["sessionUpdated", "sessionReminder", "sessionStarting"]));
  });
});

describe("Zoom functions (preconditions; real Zoom API unreachable with dummy creds)", () => {
  async function session(overrides = {}) {
    const ref = db.collection("bloom_sessions").doc();
    await ref.set({ title: "QA", date: Timestamp.fromDate(new Date("2026-10-05T00:00:00Z")), startTime: "6:00 PM", endTime: "7:00 PM", zoomMeetingId: "", zoomMeetingLink: "", zoomPasscode: "", minAttendancePercent: 75, status: "draft", guestSpeakerUid: null, ...overrides });
    return ref;
  }

  test("createZoomMeetingForSession: unauthenticated / non-admin denied", async () => {
    const s = await session();
    assert.equal((await call("createZoomMeetingForSession", null, { sessionId: s.id })).error, "unauthenticated");
    assert.equal((await call("createZoomMeetingForSession", member, { sessionId: s.id })).error, "permission-denied");
    assert.equal((await call("createZoomMeetingForSession", partnerApproved, { sessionId: s.id })).error, "permission-denied");
  });

  test("createZoomMeetingForSession: session with no speaker rejected", async () => {
    const s = await session();
    const r = await call("createZoomMeetingForSession", admin, { sessionId: s.id });
    assert.equal(r.error, "failed-precondition");
    assert.match(r.message, /guest speaker/i);
  });

  test("createZoomMeetingForSession: speaker with no email on file rejected", async () => {
    const s = await session({ guestSpeakerUid: "speakerNoApp" });
    const r = await call("createZoomMeetingForSession", admin, { sessionId: s.id });
    assert.equal(r.error, "failed-precondition");
    assert.match(r.message, /email/i);
  });

  test("createZoomMeetingForSession: unparseable start time rejected before calling Zoom", async () => {
    await db.collection("speaker_applications").doc("speakerQA").set({ email: "speaker@example.com" });
    const s = await session({ guestSpeakerUid: "speakerQA", startTime: "6pm" });
    const r = await call("createZoomMeetingForSession", admin, { sessionId: s.id });
    assert.equal(r.error, "failed-precondition");
    assert.match(r.message, /start time/i);
  });

  test("createZoomMeetingForSession: missing session -> not found", async () => {
    assert.equal((await call("createZoomMeetingForSession", admin, { sessionId: "nope" })).error, "not-found");
  });

  test("createZoomMeetingForSession: valid input reaches Zoom; auth failure surfaced, session untouched", async () => {
    await db.collection("speaker_applications").doc("speakerQA").set({ email: "speaker@example.com" });
    const s = await session({ guestSpeakerUid: "speakerQA" });
    const r = await call("createZoomMeetingForSession", admin, { sessionId: s.id });
    assert.equal(r.error, "internal");
    assert.match(r.message, /Zoom/i);
    assert.equal((await s.get()).data().zoomMeetingLink, "");
    assert.equal((await s.collection("private").doc("zoomHost").get()).exists, false);
  });

  test("syncSessionAttendance: unauthenticated / non-admin denied", async () => {
    const s = await session({ zoomMeetingId: "123" });
    assert.equal((await call("syncSessionAttendance", null, { sessionId: s.id })).error, "unauthenticated");
    assert.equal((await call("syncSessionAttendance", member, { sessionId: s.id })).error, "permission-denied");
  });

  test("syncSessionAttendance: session without a Zoom meeting id rejected", async () => {
    const s = await session();
    assert.equal((await call("syncSessionAttendance", admin, { sessionId: s.id })).error, "failed-precondition");
  });

  test("syncSessionAttendance: Zoom failure writes a 'failed' audit entry, registrations untouched", async () => {
    const s = await session({ zoomMeetingId: "123" });
    const regRef = db.collection("session_registrations").doc(`${s.id}_${member}`);
    await regRef.set({ sessionId: s.id, participantUid: member, participantName: "M", status: "registered", attended: false });
    assert.equal((await call("syncSessionAttendance", admin, { sessionId: s.id })).error, "internal");
    const logs = (await db.collection("attendance_sync_log").where("sessionId", "==", s.id).get()).docs.map((d) => d.data());
    assert.equal(logs.length, 1);
    assert.equal(logs[0].status, "failed");
    assert.equal(logs[0].triggeredByUid, admin);
    assert.equal((await regRef.get()).data().attended, false);
  });
});

describe("completeMinorSignup + redeemInviteCode (Girl/Woman/Parent role split)", () => {
  const rawUid = (label) => `qa_${label}_${Date.now()}_${n++}`;
  const age12Dob = () => new Date(new Date().getFullYear() - 12, 0, 1).getTime();
  const age30Dob = () => new Date(new Date().getFullYear() - 30, 0, 1).getTime();

  test("completeMinorSignup: unauthenticated caller rejected", async () => {
    const r = await callAsEmail("completeMinorSignup", null, null, { firstName: "A", lastName: "B", email: "x@example.com", memberType: "girl", dateOfBirth: age12Dob() });
    assert.equal(r.error, "unauthenticated");
  });

  test("completeMinorSignup: email must match the authenticated token's email", async () => {
    const uid = rawUid("minor");
    const r = await callAsEmail("completeMinorSignup", uid, `${uid}@example.com`, {
      firstName: "A", lastName: "B", email: "someone-else@example.com", memberType: "girl", dateOfBirth: age12Dob(),
    });
    assert.equal(r.error, "invalid-argument");
  });

  test("completeMinorSignup: rejects an out-of-range date of birth (too old)", async () => {
    const uid = rawUid("minor");
    const r = await callAsEmail("completeMinorSignup", uid, `${uid}@example.com`, {
      firstName: "A", lastName: "B", email: `${uid}@example.com`, memberType: "girl", dateOfBirth: age30Dob(),
    });
    assert.equal(r.error, "failed-precondition");
  });

  test("completeMinorSignup: happy path creates a 'minor' doc with a 6-char invite code, empty guardianUids", async () => {
    const uid = rawUid("minor");
    const r = await callAsEmail("completeMinorSignup", uid, `${uid}@example.com`, {
      firstName: "Girl", lastName: "T", email: `${uid}@example.com`, memberType: "girl", dateOfBirth: age12Dob(),
    });
    assert.ok(r.result?.success, JSON.stringify(r));
    assert.match(r.result.inviteCode, /^[A-HJ-NP-Z2-9]{6}$/);

    const doc = (await db.collection("users").doc(uid).get()).data();
    assert.equal(doc.role, "minor");
    assert.deepEqual(doc.guardianUids, []);
    assert.equal(doc.inviteCode, r.result.inviteCode);

    const codeDoc = (await db.collection("invite_codes").doc(r.result.inviteCode).get()).data();
    assert.equal(codeDoc.minorUid, uid);
  });

  test("completeMinorSignup: calling twice for the same uid is idempotent (same code, no duplicate invite_codes doc)", async () => {
    const uid = rawUid("minor");
    const args = { firstName: "Girl", lastName: "T", email: `${uid}@example.com`, memberType: "girl", dateOfBirth: age12Dob() };
    const first = await callAsEmail("completeMinorSignup", uid, `${uid}@example.com`, args);
    const second = await callAsEmail("completeMinorSignup", uid, `${uid}@example.com`, args);
    assert.ok(first.result?.success && second.result?.success);
    assert.equal(first.result.inviteCode, second.result.inviteCode);
  });

  test("redeemInviteCode: unauthenticated caller rejected", async () => {
    assert.equal((await call("redeemInviteCode", null, { code: "ABCDEF" })).error, "unauthenticated");
  });

  test("redeemInviteCode: a non-guardian caller (Woman) is rejected", async () => {
    const r = await call("redeemInviteCode", member, { code: "ABCDEF" });
    assert.equal(r.error, "permission-denied");
  });

  test("redeemInviteCode: invalid/unknown code is rejected", async () => {
    const guardianUid = await user("guardian");
    const r = await call("redeemInviteCode", guardianUid, { code: "ZZZZZZ" });
    assert.equal(r.error, "not-found");
  });

  test("redeemInviteCode: happy path links guardian <-> minor both ways", async () => {
    const minorUid = rawUid("minor");
    const minorResult = await callAsEmail("completeMinorSignup", minorUid, `${minorUid}@example.com`, {
      firstName: "Girl", lastName: "T", email: `${minorUid}@example.com`, memberType: "girl", dateOfBirth: age12Dob(),
    });
    const code = minorResult.result.inviteCode;
    const guardianUid = await user("guardian");

    const r = await call("redeemInviteCode", guardianUid, { code });
    assert.ok(r.result?.success, JSON.stringify(r));
    assert.equal(r.result.linkedChildUid, minorUid);

    const minorDoc = (await db.collection("users").doc(minorUid).get()).data();
    assert.ok(minorDoc.guardianUids.includes(guardianUid));
    const guardianDoc = (await db.collection("users").doc(guardianUid).get()).data();
    assert.ok(guardianDoc.linkedChildUids.includes(minorUid));
  });

  test("redeemInviteCode: redeeming the same code twice by the same guardian is a harmless no-op, not an error", async () => {
    const minorUid = rawUid("minor");
    const minorResult = await callAsEmail("completeMinorSignup", minorUid, `${minorUid}@example.com`, {
      firstName: "Girl", lastName: "T", email: `${minorUid}@example.com`, memberType: "girl", dateOfBirth: age12Dob(),
    });
    const code = minorResult.result.inviteCode;
    const guardianUid = await user("guardian");

    await call("redeemInviteCode", guardianUid, { code });
    const second = await call("redeemInviteCode", guardianUid, { code });
    assert.ok(second.result?.success, JSON.stringify(second));

    const minorDoc = (await db.collection("users").doc(minorUid).get()).data();
    assert.equal(minorDoc.guardianUids.filter((g) => g === guardianUid).length, 1, "no duplicate entries");
  });

  test("redeemInviteCode: a 5th guardian is rejected once the cap (4) is reached", async () => {
    const minorUid = rawUid("minor");
    const minorResult = await callAsEmail("completeMinorSignup", minorUid, `${minorUid}@example.com`, {
      firstName: "Girl", lastName: "T", email: `${minorUid}@example.com`, memberType: "girl", dateOfBirth: age12Dob(),
    });
    const code = minorResult.result.inviteCode;

    for (let i = 0; i < 4; i++) {
      const guardianUid = await user("guardian");
      const r = await call("redeemInviteCode", guardianUid, { code });
      assert.ok(r.result?.success, `guardian ${i} should link successfully: ${JSON.stringify(r)}`);
    }

    const fifthGuardian = await user("guardian");
    const r = await call("redeemInviteCode", fifthGuardian, { code });
    assert.equal(r.error, "failed-precondition");

    const minorDoc = (await db.collection("users").doc(minorUid).get()).data();
    assert.equal(minorDoc.guardianUids.length, 4);
  });
});

describe("deleteOwnAccount", () => {
  test("unauthenticated caller rejected", async () => {
    assert.equal((await call("deleteOwnAccount", null, {})).error, "unauthenticated");
  });

  test("deletes the profile doc and the Auth account", async () => {
    const uid = await authUser("member");
    const r = await call("deleteOwnAccount", uid, {});
    assert.ok(r.result?.success, JSON.stringify(r));

    assert.equal((await db.collection("users").doc(uid).get()).exists, false);
    await assert.rejects(() => auth.getUser(uid), /no user record|USER_NOT_FOUND/i);
  });

  test("deletes the user's session_registrations, session_badges, session_surveys, session_checkins", async () => {
    const uid = await authUser("member");
    await db.collection("session_registrations").doc(`s1_${uid}`).set({ sessionId: "s1", participantUid: uid, status: "registered" });
    await db.collection("session_badges").doc(`s1_${uid}`).set({ sessionId: "s1", participantUid: uid, sessionTitle: "T" });
    await db.collection("session_surveys").doc(`s1_${uid}`).set({ sessionId: "s1", participantUid: uid });
    await db.collection("session_checkins").doc(`s1_${uid}`).set({ sessionId: "s1", participantUid: uid });

    await call("deleteOwnAccount", uid, {});

    assert.equal((await db.collection("session_registrations").doc(`s1_${uid}`).get()).exists, false);
    assert.equal((await db.collection("session_badges").doc(`s1_${uid}`).get()).exists, false);
    assert.equal((await db.collection("session_surveys").doc(`s1_${uid}`).get()).exists, false);
    assert.equal((await db.collection("session_checkins").doc(`s1_${uid}`).get()).exists, false);
  });

  test("deletes app_notifications addressed to the user", async () => {
    const uid = await authUser("member");
    await db.collection("app_notifications").doc().set({ uid, type: "general", title: "t", body: "b", read: false, sessionId: null, createdAt: Timestamp.now() });

    await call("deleteOwnAccount", uid, {});

    const remaining = await db.collection("app_notifications").where("uid", "==", uid).get();
    assert.equal(remaining.size, 0);
  });

  test("partner: deletes partners/partner_profiles docs and their rewards", async () => {
    const uid = await authUser("partner");
    await db.collection("partners").doc(uid).set({ businessName: "Biz", email: "x@example.com", status: "approved" });
    await db.collection("partner_profiles").doc(uid).set({ businessName: "Biz" });
    const rewardRef = db.collection("rewards").doc();
    await rewardRef.set({ partnerUid: uid, partnerName: "Biz", name: "Gift", status: "approved" });

    await call("deleteOwnAccount", uid, {});

    assert.equal((await db.collection("partners").doc(uid).get()).exists, false);
    assert.equal((await db.collection("partner_profiles").doc(uid).get()).exists, false);
    assert.equal((await rewardRef.get()).exists, false);
  });

  test("donations referencing a deleted partner are ANONYMIZED, not deleted", async () => {
    const uid = await authUser("partner");
    const donationRef = db.collection("donations").doc();
    await donationRef.set({
      partnerId: uid, partnerName: "Real Biz Name", email: "real@example.com", amount: 2500, currency: "usd",
      purpose: "Workshop", status: "paid", stripeCheckoutSessionId: "cs_1", stripePaymentIntentId: "pi_1",
      createdAt: Timestamp.now(), paidAt: Timestamp.now(),
    });

    await call("deleteOwnAccount", uid, {});

    const after = (await donationRef.get()).data();
    assert.ok(after, "donation doc must still exist");
    assert.equal(after.email, "[deleted account]");
    assert.equal(after.partnerName, "[deleted account]");
    assert.equal(after.amount, 2500);
    assert.equal(after.status, "paid");
    assert.equal(after.stripePaymentIntentId, "pi_1");
  });

  test("reward_redemptions referencing a deleted participant have participantUid nulled, record otherwise intact", async () => {
    const uid = await authUser("member");
    const redemptionRef = db.collection("reward_redemptions").doc();
    await redemptionRef.set({
      rewardId: "r1", rewardName: "Gift", partnerUid: "p1", partnerName: "Biz", participantUid: uid,
      badgeCost: 2, code: "ABCD1234", status: "used", createdAt: Timestamp.now(), usedAt: Timestamp.now(), usedByPartnerUid: "p1",
    });

    await call("deleteOwnAccount", uid, {});

    const after = (await redemptionRef.get()).data();
    assert.ok(after, "redemption doc must still exist");
    assert.equal(after.participantUid, null);
    assert.equal(after.code, "ABCD1234");
    assert.equal(after.status, "used");
  });

  test("deleting a linked minor removes her uid from her guardian's linkedChildUids", async () => {
    const guardianUid = await authUser("guardian");
    const minorUid = await authUser("minor", { guardianUids: [guardianUid] });
    await db.collection("users").doc(guardianUid).update({ linkedChildUids: [minorUid] });

    await call("deleteOwnAccount", minorUid, {});

    const guardianDoc = (await db.collection("users").doc(guardianUid).get()).data();
    assert.ok(!guardianDoc.linkedChildUids.includes(minorUid));
  });

  test("deleting a guardian removes her uid from each linked minor's guardianUids", async () => {
    const guardianUid = await authUser("guardian");
    const minorUid = await authUser("minor", { guardianUids: [guardianUid] });
    await db.collection("users").doc(guardianUid).update({ linkedChildUids: [minorUid] });

    await call("deleteOwnAccount", guardianUid, {});

    const minorDoc = (await db.collection("users").doc(minorUid).get()).data();
    assert.ok(!minorDoc.guardianUids.includes(guardianUid));
  });

  test("deleting a minor also deletes her invite_codes entry", async () => {
    const minorUid = await authUser("minor");
    await db.collection("invite_codes").doc("ZZZZZZ").set({ minorUid, createdAt: Timestamp.now() });

    await call("deleteOwnAccount", minorUid, {});

    assert.equal((await db.collection("invite_codes").doc("ZZZZZZ").get()).exists, false);
  });

  test("calling again for an already-deleted uid is a harmless no-op (idempotent)", async () => {
    const uid = await authUser("member");
    const first = await call("deleteOwnAccount", uid, {});
    assert.ok(first.result?.success, JSON.stringify(first));

    const second = await call("deleteOwnAccount", uid, {});
    assert.ok(second.result?.success, JSON.stringify(second));
  });
});
