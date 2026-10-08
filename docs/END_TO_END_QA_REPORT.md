# Bloom G2W — End-to-End QA Report

## Executive Summary

| | |
|---|---|
| **Overall status** | **READY WITH KNOWN ISSUES.** The registration-blocking bug (C-1) and every High severity finding are fixed, tested, and **deployed to production**. All fixes in this round passed a full rebuild, a clean single-run 155/155 emulator test suite, and were deployed: Firestore rules, Storage rules, all 7 Cloud Functions (including a new one), and Hosting. Several Medium/Low items remain open by design decision or environment limitation — see Remaining Issues. |
| **Date tested** | 2026-09-28 → 2026-09-29 (fix round completed 2026-09-29) |
| **Tested by** | Claude (automated QA + fix session) |
| **Firebase project** | `bloomg2w`, Firestore database `bloomg2w-db` — production **data** was only read, never mutated; production **configuration** (rules, functions, hosting) was deployed as described below |
| **Test environment** | Firestore emulator (firebase-tools 13, project id `demo-bloomg2w`, fully offline, run under the JDK 17 runtime bundled with Android Studio since no standalone JDK is installed on this machine), Flutter 3.44.1 stable, Node 24 (dev machine) / Node 22 (deployed Functions runtime), Windows 10 |
| **Stripe** | Sandbox (test mode) only throughout. No live keys used, printed, or committed. |
| **Build tested** | Working tree as of 2026-09-29 (the project is not a git repository, so there is no commit hash) |

### Fix round (2026-09-29): what changed since the initial audit

The initial audit (below, largely preserved for history) found the app **NOT READY** and left every fix undeployed. This second pass fixed the remaining open findings, re-verified everything with real test runs, and **deployed all changes to the live `bloomg2w` project**. Summary:

| Severity | Findings | Status after this round |
|---|---|---|
| Critical | C-1 | Fixed and **deployed** |
| High | H-1, H-2, H-3, H-4 | Fixed and **deployed** |
| Medium | M-1, M-2, M-3, M-4, M-5, M-6, M-7, M-8, M-9, M-11 | Fixed and **deployed** |
| Medium | M-10 | Fixed and **deployed** (storage rules) |
| Low | L-1, L-2, L-4, L-6, L-7, L-8 | Fixed and **deployed** |
| Low | L-3, L-5 | Reviewed; deliberately left as documented, low-risk known limitations (see below) |

### How to read this report

Every result is labelled with how it was verified:

- **[RUNTIME-EMU]** Executed against the Firestore emulator. Security rules were enforced by the real rules engine, and Cloud Functions handlers were run from the compiled `functions/lib` code in-process.
- **[RUNTIME-PROD]** Observed on the live `bloomg2w` project, either through non-mutating HTTP probes of deployed functions or read-only inspection of Firestore data and Cloud Logging.
- **[UNIT]** Pure-logic unit tests (`flutter test` or Node).
- **[CODE]** Code inspection only. **Not executed.**
- **[NOT TESTED]** Could not be tested. The reason is given each time.

**Limitation:** no Android device or emulator was connected, and no browser-automation tool was available. **No UI screen was clicked through by the QA process.** Every UI finding comes from code inspection. The only real-browser evidence is the Stripe sandbox payment the product owner completed on 2026-09-20, whose resulting data and logs were verified in this QA.

---

## Test Coverage

| Module | Coverage |
|---|---|
| Firestore security rules (all collections) | [RUNTIME-EMU]: ~90 tests, including a full participant-journey replay and the M-6 notification-injection fix |
| Cloud Functions: `redeemReward`, `markRedemptionUsed`, `createDonationCheckout`, `stripeWebhook`, `createZoomMeetingForSession`, `syncSessionAttendance`, `notifySessionRegistrants` | [RUNTIME-EMU]: 51 tests, including concurrency and the new notification fan-out function |
| Attendance calculation (Zoom report → % → qualified) | [UNIT]: 14 tests |
| Deployed functions (auth enforcement, webhook signature enforcement) | [RUNTIME-PROD]: 8 non-mutating probes |
| Production data integrity and Stripe payment trail | [RUNTIME-PROD]: read-only |
| Flutter model logic (dates, marketplace visibility, status defaults) | [UNIT]: 11 tests |
| Builds (analyze, test, web, APK) | Executed |
| UI screens, navigation, loading/empty/error states, layouts | [CODE] only |
| Real Zoom API (meeting creation, attendance import) | [NOT TESTED]: see Known Limitations |

Re-run all automated tests. JDK 17+ is needed; no standalone JDK is installed on this machine, so the JBR bundled with Android Studio (`C:\Program Files\Android\Android Studio\jbr`) was put on `PATH` for the emulator:

```bash
cd functions && npm run build && cd ..
export PATH="/c/Program Files/Android/Android Studio/jbr/bin:$PATH"
npx firebase-tools@13 emulators:exec --only firestore --project demo-bloomg2w "cd qa && npm test"
flutter test
```

**2026-09-29 fix-round re-run:** the full `qa/` suite was run exactly once against a freshly cleared emulator: **155/155 pass, 0 fail** (19 suites: rules, functions, attendance). An earlier same-day run of `functions.test.mjs` alone, on a still-warm emulator left over from a prior run, showed 7 apparent Stripe-webhook failures — these were re-investigated and confirmed to be a test-isolation artifact (hardcoded event IDs like `evt_ok_1` colliding with the previous run's already-recorded idempotency-ledger entries, i.e. the idempotency logic correctly refusing to reprocess), not a product defect. The clean, single, fresh-emulator run is the one this report's numbers are based on.

---

## Passed

### Authentication & roles
- [RUNTIME-PROD] All 5 callable functions reject unauthenticated calls with HTTP 401 `UNAUTHENTICATED`.
- [RUNTIME-EMU] A participant cannot escalate their own role to admin, cannot read another user's profile, and unauthenticated users can read no profiles. Admins can read profiles.
- [RUNTIME-EMU] Admin-only functions (`createZoomMeetingForSession`, `syncSessionAttendance`) return `permission-denied` for participants and partners. The admin check reads the trusted `users/{uid}.role` field.

### Sessions & registration
- [RUNTIME-EMU] Participants can read published sessions but not drafts. Only admins can create or edit sessions. The exact payload the app's `BloomSession.toMap()` writes is accepted.
- [RUNTIME-EMU] A participant can register themself for an open published session. They cannot register someone else, create a pre-attended registration, or overwrite an existing registration (duplicate prevention).
- [RUNTIME-EMU] *(after fix M-1)* Registration is rejected for draft, cancelled, and nonexistent sessions, and after the registration deadline.
- [RUNTIME-EMU] The host-only Zoom start link (`bloom_sessions/{id}/private/zoomHost`) is readable only by the assigned speaker and admins. No client can write it.

### Attendance
- [RUNTIME-EMU] Participants cannot mark themselves attended or set `attendancePercent` or `attendanceSource`. Participants can check themselves in.
- [RUNTIME-EMU] Admins can record attendance. The audit stamp (`attendanceCorrectedBy`) must equal the acting admin, so one admin cannot forge another's.
- [UNIT] Attendance math:
  - Full attendance, and the spec's example (50 of 60 min = 83.3% → qualified at 75%)
  - Late join, early leave, multiple join/leave intervals
  - Case-insensitive email matching
  - Unregistered Zoom attendees reported as unmatched
  - No automatic name matching for email-less guests
  - Zero-duration meetings qualify nobody
  - Rounding consistency, and a 100% cap
- [RUNTIME-EMU] If the Zoom call fails, `syncSessionAttendance` writes a `failed` audit entry and leaves registrations untouched.

### Exit survey & badges
- [RUNTIME-EMU] Survey completion is only allowed after an admin has recorded attendance. Surveys are immutable, a participant cannot submit a survey for someone else, and out-of-range ratings are rejected.
- [RUNTIME-EMU] Badges:
  - Can be created only by the attending participant, only at the `{sessionId}_{uid}` id, and never pre-spent.
  - Cannot be minted for non-attended sessions, created at arbitrary ids, or created for others.
  - Only `celebrationSeen` (false → true) can change. Badges cannot be deleted.
- [RUNTIME-EMU] Full participant journey, replaying the app's exact client call sequence: register → check-in → admin attendance → survey → badge → badge queries → celebration flip. A retried survey cannot rewrite the survey or re-complete.

### Private data isolation
- [RUNTIME-EMU] Partners cannot read participant registrations, surveys, or check-ins. Participants cannot read each other's surveys or check-ins. Admins can.
- [RUNTIME-EMU] *(after fix C-1)* A participant cannot probe whether another user has a registration, check-in, survey, or badge. List queries are scoped to the caller.

### Community partners
- [RUNTIME-EMU] Self-registration must start as `pending`. A partner cannot self-approve, self-publish to the directory, or read another partner's private doc. A partner can edit their own business info.
- [RUNTIME-EMU] Admin approval must be stamped with the acting admin and cannot rewrite partner-authored content.
- [RUNTIME-PROD] The one production partner is `approved` and published. No directory entries exist for unapproved partners.

### Rewards & redemption
- [RUNTIME-EMU] Rules:
  - Rewards created by partners must start `pending`, and a partner cannot self-approve.
  - Nobody except the server transaction can change `remainingQuantity`. Admin review cannot change inventory or badge cost.
  - A partner can pause their own reward but cannot edit other partners' rewards. Participants cannot create rewards.
- [RUNTIME-EMU] `redeemReward`:
  - Rejects pending, paused, expired, out-of-stock, and nonexistent rewards, and callers with too few unspent badges. No badges are spent on a rejected attempt.
  - On success, spends exactly `badgeCost` badges, tags them with the redemption id, decrements stock by 1, and issues an 8-character code.
  - Already-spent badges cannot be reused. Codes were unique across 12 redemptions.
  - **Concurrency (same participant):** 4 simultaneous redemptions with badges for only 1 → exactly 1 succeeds.
  - **Concurrency (inventory):** 5 eligible participants racing for the last unit → exactly 1 wins, stock ends at 0 (never negative), and the others keep their badges.
- [RUNTIME-EMU] `markRedemptionUsed`:
  - Another partner cannot verify a code (`not-found`), and a participant cannot mark their own code used.
  - The owning partner verifies once, and codes are normalized (case and whitespace). A second attempt returns "already been redeemed".
  - Exactly one thank-you notification is created.
  - **5 simultaneous verifications → exactly 1 succeeds.**
- [RUNTIME-EMU] Clients cannot create redemptions or codes, and cannot mark them used directly. Only the participant and the owning partner can read a redemption.

### Stripe / donations
- [RUNTIME-PROD] The webhook rejects a missing signature (400) and a forged signature (400), both before touching Firestore.
- [RUNTIME-PROD] Real sandbox payment trail (the product owner's test on 2026-09-20): one donation went `pending → paid`, with Checkout Session id, PaymentIntent id, and `paidAt` stored. Exactly one `checkout.session.completed` event was processed. The webhook logged 1 × 200 and no errors.
- [RUNTIME-EMU] Webhook:
  - Rejected with 400 and no state change: wrong secret, tampered body, and a stale timestamp (replay > 5 min).
  - A valid event marks the donation `paid` with Stripe ids.
  - **Duplicate delivery (sequential, and 3 concurrent)** → processed once, and `paidAt` is not rewritten.
  - **Two concurrent first deliveries** → processed once.
  - A second success event is not re-processed.
  - Missing metadata is acknowledged. An unknown donation id creates nothing.
  - `checkout.session.expired` → `failed`. A late `expired` cannot downgrade a `paid` donation. Unhandled event types have no side effects.
- [RUNTIME-EMU] `createDonationCheckout`:
  - Rejects unauthenticated callers, participants, and pending partners.
  - Server-side validation rejects 0, negative, <$1, fractional, >$100k, and string amounts, non-USD currencies, and unknown purposes. Invalid input creates no record.
  - A Stripe API failure marks the donation `failed`, not stuck `pending` and never `paid`.
- [RUNTIME-EMU] No client, including an admin, can create a donation, mark one paid, or fabricate a PaymentIntent id. A partner can read only their own donations, both by document and by list query. Participants cannot read donations. The webhook idempotency ledger is admin-read-only.

### Notifications
- [RUNTIME-EMU] Users can read only their own notifications and can only flip `read`.
- [RUNTIME-EMU] The partner thank-you notification contains the required copy.

---

## Failed

Findings are ordered by severity. **Status** reflects the state as of the 2026-09-29 fix round: FIXED (DEPLOYED), FIXED (reviewed, deliberately not restructured), or NOT IMPLEMENTED (by design/scope decision).

### C-1 · CRITICAL · No participant can register for a session · FIXED (DEPLOYED)
- **Reproduce:** Sign in as a participant, open any published session, and tap **Register for Session**.
- **Expected:** A registration is created and the panel switches to "Registered".
- **Actual:** `registerForSession` first reads the participant's own not-yet-existing `session_registrations/{sessionId}_{uid}` doc. The read rule `resource.data.participantUid == request.auth.uid` is evaluated with `resource == null`, which **denies** the read, so the call throws `permission-denied`. The session screen's live listener on that doc is also denied, so it would never show "Registered" either. The exit-survey flow's badge-existence and survey-existence checks hit the same denial, so **no badge could ever be awarded**.
- **Evidence:**
  - [RUNTIME-EMU] `qa/debug_existence_reads.mjs` before the fix: `DENY get()` on registrations, check-ins, surveys, and badges, and `DENY listen` on registrations.
  - [RUNTIME-PROD] Production has **0 registrations, 0 badges, and 0 redemptions ever**.
- **Files:** `firestore.rules` (read rules for `session_registrations`, `session_checkins`, `session_surveys`, `session_badges`); `lib/services/session_service.dart` (`registerForSession`, `submitExitSurvey`).
- **Fix:** New `canReadOwnParticipantDoc(docId)` rule. If the doc exists, ownership comes from `participantUid`. If it does not exist yet, the read is allowed only when the doc id ends with the caller's own uid, so nobody can probe another user's registrations.
- **Verified:** After the fix, the diagnostic returns `ALLOW` for all reads, 10 new rules tests pass (including anti-probing), and the full journey test passes.

### H-1 · HIGH · Today's session disappears from Events & Zoom on the day it happens · FIXED (DEPLOYED)
- **Reproduce:** Publish a session for today, then open Events & Zoom after 3:00 AM local time.
- **Expected:** Today's session is listed, because this is when participants need to check in and join.
- **Actual:** The filter `s.date.isAfter(now - 3h)` treats `date` as an instant, but `date` is the calendar day at midnight (the time of day lives in the separate `startTime` string). The session is hidden for the rest of its day. The Events screen is the **only** route to the Check-In and Join buttons.
- **File:** `lib/screens/events_zoom_screen.dart`. The admin dashboard's "X upcoming" counter had the same off-by-one-day logic (fixed as L-1).
- **Fix:** Compare whole calendar days, so a session stays listed through its entire date.

### H-2 · HIGH · Session dates shift by a day across timezones; Zoom meetings booked on the wrong day · FIXED (DEPLOYED)
- **Reproduce (A):** An admin in UTC+5 (Pakistan) creates a session for Oct 5. The date is stored as Oct 4 19:00 UTC, so `createZoomMeetingForSession` (which reads UTC components) books the Zoom meeting for **Oct 4**, and US participants see **Oct 4**.
- **Reproduce (B):** An admin in US Eastern creates Oct 5. The date is stored as Oct 5 04:00 UTC, so participants in Central, Mountain, and Pacific time see **Oct 4**.
- **Expected:** Every viewer, and Zoom, sees Oct 5.
- **Files:** `lib/models/bloom_session.dart`, `lib/services/session_service.dart` (update path).
- **Fix:** Session `date` and `registrationDeadline` are now stored as midnight **UTC** of the chosen calendar day and read back by UTC components. This is consistent with what the Zoom function already assumed. **No data migration was needed**: production has 0 sessions.
- **Verified:** [UNIT] round-trip and time-of-day independence tests, run on a UTC+5 machine.

### H-3 · HIGH · Overlapping Zoom connections double-count attendance (unearned badges) · FIXED (DEPLOYED)
- **Reproduce:** A participant joins from a phone and a laptop for the first 30 minutes of a 60-minute session, then leaves.
- **Expected:** 30 minutes = 50% attendance, not qualified at 75%.
- **Actual:** The two join records were summed to 60 minutes = 100%, so the participant qualified and earned a badge they did not earn. A partially overlapping reconnect was over-counted in the same way.
- **File:** `functions/src/attendanceCalculator.ts`.
- **Fix:** Merge each person's join/leave intervals before summing, so only unique minutes count.
- **Verified:** [UNIT] 14/14, including 2 overlap tests that failed before the fix.
- **Deploy:** `syncSessionAttendance`.

### H-4 · HIGH · Home screen and Member Dashboard show fabricated data to real users · FIXED (DEPLOYED)
- **Reproduce:** Sign in as any participant and look at the Home screen "Upcoming Events" card; then open Drawer → Member Dashboard.
- **Was:**
  - `widgets/upcoming_event_card.dart` was **entirely hard-coded**: "Women Blooming Club", MAY 25 SAT, 10:00–11:30 AM. This event did not exist, and "View All" did nothing.
  - `screens/member_dashboard_screen.dart` was **entirely fabricated**: "Welcome back, Amara", 340 Reward Points, 3 Badges, 12 Volunteer Hrs, a fake workshop with a dead **Register** button (`onPressed: () {}`), fake course progress, fake badges, and a fake reminder.
- **Fix:**
  - `upcoming_event_card.dart` is now a `StreamBuilder` on `SessionService.instance.watchUpcomingPublishedSessions()`, filtered to whole calendar days not before today (same pattern as the H-1 fix) and sorted by date. It shows the real next session's title/date/time, links to it, and shows an honest empty state ("No upcoming sessions scheduled yet — check back soon!") when there is none. "View All" now navigates to Events & Zoom.
  - `member_dashboard_screen.dart` was rewritten to read `UserService.instance.watchUserProfile` (real name, member type, photo), `SessionService.instance.watchRegistrationsForUser`/`watchBadgesForUser` (real Badges Earned / Sessions Attended / Completed counts), the same real upcoming-session stream, and a real "My Badges" list, each with an honest empty state. Fabricated metrics with no real backing feature (reward points, volunteer hours, course progress) were **removed, not replaced with different fake values**.
- **Files:** `lib/widgets/upcoming_event_card.dart`, `lib/screens/member_dashboard_screen.dart`.
- **Verified:** [CODE] — reviewed against the real `SessionService`/`UserService` stream APIs already used and tested elsewhere in the app (e.g. Events & Zoom, admin dashboard); `flutter analyze` and `flutter test` pass. No emulator UI test was possible (no device/browser automation available), so the actual rendered screen was not clicked through.

### M-1 · MEDIUM · Registration deadline never enforced · FIXED (DEPLOYED)
- **Actual:** The deadline was stored and shown to admins only. Participants could register at any time, and the rules also allowed registration for draft, cancelled, and nonexistent sessions.
- **Fix:**
  - **UI:** The session detail screen shows "Registration closes <date>" and replaces the Register button after the end of the deadline day in the participant's own timezone.
  - **Server:** The registration create rule now requires the session to exist and be `published`, and requires `request.time < deadline + 36h`. The 36-hour allowance covers the end of the deadline day in every US timezone. It is a tamper-proof backstop; the app enforces the exact local cut-off.
- **Verified:** [RUNTIME-EMU] 5 tests.

### M-2 · MEDIUM · Admin "Total Contributions" counts failed donations · FIXED (DEPLOYED)
- **Evidence:** [RUNTIME-PROD] Production has 1 paid ($25) and 2 failed ($25 each). The dashboard showed **$75 total when $25 was actually received**. This figure feeds grant and board reporting.
- **File:** `lib/screens/admin/donations/admin_donations_screen.dart`.
- **Fix:** "Total" = paid + pending. Failed, cancelled, and refunded donations are excluded.

### M-3 · MEDIUM · Cancelled Stripe checkout shows an endless "Confirming your payment…" spinner · FIXED (DEPLOYED)
- **Reproduce:** Start a contribution, then click back or cancel on Stripe's page.
- **Actual:** The cancel URL opened the same confirmation screen as success. The donation legitimately stays `pending` until Stripe expires the session (hours later), so the screen spun indefinitely.
- **Fix:**
  - `/donation-cancelled` now shows "Checkout Cancelled — no charge was made". A payment that actually completes still shows as paid.
  - The pending state explains that closing the Stripe page means no charge was made.
  - The deep link now captures the navigator before the role router replaces the stack, instead of relying on the old widget still being mounted.
- **Files:** `lib/screens/partner/donation_confirmation_screen.dart`, `lib/main.dart`.

### M-4 · MEDIUM · Register, check-in, and exit-survey submissions failed silently · FIXED (DEPLOYED)
- **Actual:** These used `try/finally` with no `catch`, so any error (network, rules) gave the participant no feedback.
- **Fix:** Added a user-facing error SnackBar to each.
- **Files:** `session_detail_screen.dart`, `checkin_screen.dart`, `exit_survey_screen.dart`.

### M-5 · MEDIUM · Exit survey could get permanently stuck after a mid-flow failure · FIXED (DEPLOYED)
- **Actual:** The survey doc, which is immutable, was written first, followed by the registration update and then the badge. If the connection dropped after the first step, every retry failed at that first step, so the participant could never complete or earn the badge.
- **Fix:** Each step is skipped if it is already done, so a retry resumes instead of failing.
- **File:** `lib/services/session_service.dart`.
- **Residual (LOW):** If the registration update succeeds but badge creation then fails, the survey button is hidden (`surveyCompleted == true`), so the UI offers no retry for the badge. This requires a failure at exactly that step.

### M-6 · MEDIUM · Security · Any signed-in user can inject notifications into any other user's inbox · FIXED (DEPLOYED)
- **Evidence (before):** [RUNTIME-EMU] The test "KNOWN GAP" succeeded in writing "Your account is suspended, click here" into another user's inbox.
- **Cause:** `app_notifications` allowed create for any uid, by design, because client code fanned notifications out to other users directly from Flutter.
- **Risk:** Phishing and harassment vector. The read rule always protected confidentiality; this was a write-side injection risk only.
- **Fix:**
  - `firestore.rules`: `isValidNewNotification()` now requires `d.uid == request.auth.uid` — a client may only ever create a notification addressed to itself.
  - New admin-only callable `notifySessionRegistrants` (`functions/src/index.ts`) performs all cross-user fan-out (session updated/cancelled/reminder/starting) server-side via the Admin SDK, which bypasses client rules entirely. It looks up active (non-cancelled) registrants for the session itself — the caller cannot supply a recipient list — and batches writes.
  - `lib/services/session_service.dart`: `updateSession`, `cancelSession`, `sendReminderNow`, and `sendSessionStartingNow` were changed to call the new callable instead of writing `app_notifications` directly. `updateSession` now only notifies when the date, time, or Zoom link actually changed (this also fixes M-8 — see below), not on every save.
- **Verified:** [RUNTIME-EMU] The former "KNOWN GAP" test now asserts `assertFails` (fix confirmed at the rules layer); a new test confirms a user can still notify themself; a new test confirms even an admin cannot write `app_notifications` for another uid directly (must use the callable). 6 new `notifySessionRegistrants` tests cover unauthenticated/non-admin rejection, invalid `kind`, missing session, correct fan-out to active (not cancelled) registrants only, and distinct copy per notification kind. All pass against a fresh emulator.
- **Deployed:** `firestore.rules`; new function `notifySessionRegistrants`.

### M-7 · MEDIUM · Profile & Settings screen is mostly placeholder · FIXED (DEPLOYED)
- **What worked already:** Name, email, and photo upload were real.
- **Was:**
  - "Membership Information" was hard-coded for **every** user ("Girls Membership (8–17)", "Member Since March 2024", "Active"). Wrong for adult members, partners, and admins.
  - Interests and "Certificates & Badges" were hard-coded, not the user's real badges.
  - **Edit Profile** was a dead button.
  - The notification and privacy switches could not be toggled (`onChanged: (_) {}`).
- **Fix:**
  - Membership Type and Member Since now read the real `UserProfile.memberType` and `UserProfile.createdAt` via `UserService.instance.watchUserProfile`, with the same girl/woman/parent label mapping used on the Member Dashboard. "Status: Active" was kept as a static label — there is no suspension/deactivation feature anywhere in the app, so any account that can reach this screen is, by definition, active; this is not fabricated data the way the old fields were.
  - The fake Interests section and fake "Certificates & Badges" chips were removed. A "My Badges" section now streams the user's real `SessionBadge` records via `SessionService.instance.watchBadgesForUser`, with an honest empty state.
  - The dead **Edit Profile** button and the two non-functional switches were removed outright rather than left as dead UI, since no edit-profile or notification-preferences feature exists to back them.
- **File:** `lib/screens/profile_settings_screen.dart`.
- **Verified:** [CODE] + `flutter analyze` clean, `flutter test` passes. Not clicked through (no device/browser automation available).

### M-8 · MEDIUM · Any edit to a published session sends a "rescheduled" notice · FIXED (DEPLOYED)
- **Was:** `updateSession(..., notifyRegistrants: status == published)` notified every registrant with "…has been rescheduled…" on *any* save of a published session, including a description typo fix.
- **Fix:** `updateSession` now takes the `previous` session and only calls `notifySessionRegistrants` (see M-6) when the calendar date, start/end time, or Zoom link/id/passcode actually differ from before. A fresh session's first save (`previous == null`) never notifies, since nobody could be registered yet.
- **File:** `lib/services/session_service.dart`, `lib/screens/admin/sessions/admin_session_form_screen.dart`.
- **Verified:** [CODE]. The underlying notification path itself is covered by the M-6 emulator tests; the "only notify on an actual schedule change" condition is a pure Dart boolean and was reviewed but not separately unit-tested (would require a widget-level test harness not present in this project).

### M-9 · MEDIUM · UI · "Gold" call-to-action buttons render white-on-off-white app-wide · FIXED (DEPLOYED)
- **Cause:** `AppColors.gold` was redefined to white (per an earlier design direction). Buttons that use it on light pages were borderless white-on-off-white. On the sign-up wizard's **Continue** button (`WizardPrimaryButton`), the disabled state (35% white) was nearly indistinguishable from enabled.
- **Fixed this round:** the remaining flows beyond what the initial audit covered: `wizard_scaffold.dart`'s `WizardPrimaryButton` (used by every step of every sign-up wizard) now uses `AppColors.royal`/white text instead of gold/royalDeep, with a visibly distinct disabled state. The same gold-on-light swap was applied to the "Learn More"/"Join the Bloom Movement" buttons on `about_screen.dart`, `founder_president_screen.dart`, `what_guides_us_screen.dart`, and `membership_registration_screen.dart`.
- **Deliberately left alone:** `congratulations_screen.dart`, `speaker_application_submitted_screen.dart`, `welcome_screen.dart`, and `partner_registration_complete.dart` — these all sit on the dark navy (`AppColors.royalDeep`) background, where gold-on-dark already has correct contrast.
- **Files:** `lib/widgets/common/wizard_scaffold.dart`, `lib/screens/about_screen.dart`, `lib/screens/founder_president_screen.dart`, `lib/screens/what_guides_us_screen.dart`, `lib/screens/membership_registration_screen.dart`.
- **Verified:** [CODE] contrast review (royal-blue background/white text vs. the previous white-on-off-white). Not visually screenshotted (no browser automation available).

### M-10 · MEDIUM · Privacy · Profile photos, including those of minors, are publicly readable · FIXED (DEPLOYED)
- **Cause:** `storage.rules` had `profile_photos/{file}: allow read: if true`. The program includes girls aged 8–17.
- **Fix:** All three photo namespaces (`profile_photos/`, `speaker_photos/`, `partner_logos/` — see L-6) now require `request.auth != null` to read. Write rules (owner-only by uid-matched filename, 5MB limit, image content-type check) were unchanged.
- **File:** `storage.rules`.
- **Verified:** [CODE] — the rules file was reviewed and deployed; Storage rules are not covered by the `qa/` emulator suite (which targets Firestore only), so this was not independently re-tested against the Storage emulator. Deployed and live (`firebase deploy --only storage` succeeded against project `bloomg2w`).

### M-11 · MEDIUM · Operational · Cloud Functions runtime Node.js 20 is decommissioned on 2026-10-30 · FIXED (DEPLOYED)
- **Evidence:** Every deploy previously warned: "Runtime Node.js 20 was deprecated on 2026-04-30 and will be decommissioned on 2026-10-30, after which you will not be able to deploy without upgrading."
- **Fix:** `functions/package.json` `engines.node` changed from `"20"` to `"22"`. Verified first that the existing `firebase-functions@^6.0.1` and `firebase-admin@^12.6.0` dependencies have no upper Node-version bound that would conflict, so no dependency major-version upgrade was needed — kept to the minimal change.
- **Verified:** `npm install` and `npm run build` succeed; all 7 functions redeployed as "Node.js 22 (2nd Gen)" per the `firebase deploy --only functions` output.

### L-1 · LOW · Admin "X upcoming" count excluded today's sessions · FIXED (DEPLOYED)
Same calendar-day comparison fix as H-1. File: `admin_dashboard_screen.dart`.

### L-2 · LOW · Speaker "Start Meeting" silently did nothing before a meeting existed · FIXED (DEPLOYED)
- **Actual:** The read of the not-yet-existing `private/zoomHost` doc is denied, and with no `catch`, the intended "no meeting yet" message never appeared.
- **Fix:** A `catch` that shows the message.
- **File:** `speaker_dashboard_screen.dart`.

### L-3 · LOW · Published sessions expose the Zoom join link and passcode to every signed-in user · REVIEWED, NOT RESTRUCTURED (documented known limitation)
- **Cause:** The rules allow reading an entire published session doc, including by partners and non-registrants.
- **Risk:** Zoom-bombing. Meetings created by the app have the waiting room enabled, which mitigates this.
- **Why not restructured this round:** moving join details to a registrant-only subcollection is a real data-model change touching session discovery, the Events & Zoom listing, and the Join button across every screen that reads a `BloomSession`. Attempting it alongside this round's other fixes risked destabilizing the already-fixed H-1/H-2/C-1 session flows. A detailed comment explaining the limitation and the mitigation was added directly to `firestore.rules` at the `bloom_sessions` read rule so the tradeoff is visible to the next engineer who touches this code, rather than leaving it as silent tribal knowledge.
- **File:** `firestore.rules` (comment only — behavior unchanged).
- **Recommendation (still open):** move the join link/passcode/ID to a registrant-readable subcollection in a dedicated, isolated change.

### L-4 · LOW · The `payment_intent.payment_failed` webhook branch can never match · FIXED (DEPLOYED)
- **Cause:** Checkout Session metadata was not copied to the PaymentIntent Stripe creates for the actual charge, so the event carried no `donationId` and was ignored.
- **Impact:** Harmless either way — abandoned checkouts already become `failed` via `checkout.session.expired`, and a declined card can be retried on the same Checkout page. Fixed anyway since it was a small, low-risk, clearly-scoped change.
- **Fix:** `createDonationCheckout` now also sets `payment_intent_data.metadata` (donationId, partnerId, purpose) on the Checkout Session, so the resulting PaymentIntent carries the same metadata and the webhook's `payment_intent.payment_failed` branch can now actually match and mark the donation `failed`.
- **File:** `functions/src/stripe.ts`.
- **Verified:** [RUNTIME-EMU] existing `payment_intent.payment_failed` webhook test still passes against the updated code path (this metadata addition doesn't change the emulator test's synthetic event shape, but the production code now populates the field a real Stripe-generated PaymentIntent would carry).
- **Deployed:** `createDonationCheckout`, `stripeWebhook`.

### L-5 · LOW · App Check is not enforced on callable functions · REVIEWED, NOT FIXED (by design — requires client-side work outside this pass's scope)
- **Evidence:** [RUNTIME-PROD] Logs show `"app":"MISSING"`.
- **Why not fixed:** No `firebase_app_check` client package exists in `pubspec.yaml`. Turning on server-side App Check enforcement without first adding and wiring the client SDK (and configuring a provider — reCAPTCHA/Play Integrity/DeviceCheck — in the Firebase Console, which cannot be verified from this environment) would immediately break every legitimate request. This is a real, still-open gap, not a false negative — it requires client-side integration work and a Console configuration step that this environment cannot safely complete.
- **Recommendation:** Add `firebase_app_check`, initialize it in `main.dart`, configure a provider in the Console, then enforce.

### L-6 · LOW · One image slot per user · FIXED (DEPLOYED)
- **Was:** A partner's logo, a speaker's headshot, and the user's profile photo all uploaded to `profile_photos/{uid}.jpg`, so each overwrote the others.
- **Fix:** `StorageService.uploadProfilePhoto` now takes an `ImageUploadKind` (`profilePhoto` / `speakerPhoto` / `partnerLogo`) and writes to `profile_photos/`, `speaker_photos/`, or `partner_logos/` respectively. Callers updated: `speaker_application_form_screen.dart` now passes `speakerPhoto`, `partner_profile_screen.dart` now passes `partnerLogo`. `storage.rules` was split into three matching per-purpose blocks (also carrying the M-10 auth-required read fix).
- **Files:** `lib/services/storage_service.dart`, `lib/screens/speaker/speaker_application_form_screen.dart`, `lib/screens/registration/partner/partner_profile_screen.dart`, `storage.rules`.
- **Deployed:** `storage.rules` (the client-side path change only takes effect once the rebuilt app is deployed/installed — done for web via Hosting this round).

### L-7 · LOW · Repository hygiene · FIXED (DEPLOYED — i.e. committed to the working tree; still not a git repo)
- **Was:** `.gitignore` did not ignore `node_modules/` (in `functions/` and `qa/`) or `*.local`/secret files.
- **Fix:** Added `node_modules/`, `npm-debug.log*`, `*.local`, `.env`/`.env.*`, `functions/.runtimeconfig.json`, `**/serviceAccountKey*.json`, `.firebase/`, and the various `*-debug.log` emulator log patterns.
- **File:** `.gitignore`.
- **Note:** the project is still not an initialized git repository; this only takes effect once one exists.

### L-8 · LOW · The only pre-existing Flutter test was broken · FIXED
- **Actual:** `test/widget_test.dart` pumped the full app without initialising Firebase, so it crashed and asserted nothing.
- **Fix:** Replaced with 11 real unit tests (see Build Results).

### L-9 · LOW · Build warning (future Flutter versions)
`cloud_functions` and `share_plus` apply the Kotlin Gradle Plugin. Future Flutter versions will fail to build until these plugins are updated.

---

## Blockers (preventing release)

**All previously-listed blockers are resolved as of the 2026-09-29 deployment.** C-1, H-1, H-2, H-3, H-4, and M-11 are fixed, tested, and deployed to the live `bloomg2w` project (Firestore rules, Storage rules, all 7 Cloud Functions, Hosting). What remains before an unqualified "READY" (not "READY WITH KNOWN ISSUES"):

1. **The participant journey (register → check-in → attend → survey → badge → reward) has still never run end-to-end on the deployed app with a real account in a real browser or device.** It is verified as a rules-and-function replay against the Firestore emulator (155/155 tests, clean single run) and as a live, non-mutating probe of the deployed endpoints (see Manual/Production Verification below), but no human click-through was performed in this session — no Android device or browser-automation tool is available in this environment.
2. **L-3 and L-5** remain open by deliberate scope decision (data-model restructure and client SDK integration respectively, both flagged as needing dedicated follow-up work, not blockers to today's release).

---

## Security Findings

| Area | Result |
|---|---|
| Firestore rules: privilege escalation (role, self-approval, self-attendance, badge minting, inventory, donation status, redemption status) | **Pass** [RUNTIME-EMU] |
| Firestore rules: participant self-reads of not-yet-created docs | **Fail → fixed** (C-1). The fix is scoped so it cannot be used to probe other users. |
| Data isolation: partner ↔ participant private data, partner ↔ partner | **Pass** [RUNTIME-EMU] |
| Notification integrity (cross-user injection) | **Fail → fixed** (M-6), deployed. [RUNTIME-EMU] confirms a signed-in user can no longer create a notification for another uid; fan-out is now exclusively server-side via `notifySessionRegistrants`. |
| Storage: public read of member/minor photos | **Fail → fixed** (M-10), deployed. All three photo namespaces now require `request.auth != null` to read. |
| Storage: cross-purpose image path collision | **Fail → fixed** (L-6), deployed. Profile photos, speaker photos, and partner logos now use separate storage paths. |
| Authentication on callables | **Pass** [RUNTIME-PROD] (401 without a token) and [RUNTIME-EMU] |
| Admin-role checks | **Pass**. Always read from `users/{uid}` server-side, never from client input. |
| Stripe secret key / webhook secret in source | **None found**. Scanned all source for `sk_*`, `whsec_*`, and `rk_*` patterns plus the Zoom credentials. Secrets live in Google Secret Manager and are bound to functions via `defineSecret`. |
| Stripe webhook signature verification | **Pass** [RUNTIME-PROD] (missing and forged → 400) and [RUNTIME-EMU] (wrong secret, tampered body, stale replay → 400) |
| Clients marking donations paid or fabricating payment ids | **Pass**: impossible [RUNTIME-EMU] |
| App Check on callable functions | **Gap, still open** (L-5) — requires client SDK integration and Console provider setup outside this pass's safe scope. |
| Credentials exposed in chat history | The Zoom Client Secret was rotated (owner confirmed). **The Stripe test secret key pasted into chat on 2026-09-21 should be rolled** in the Stripe Dashboard if that has not already been done. No secret values were printed or committed during this fix round; all Stripe/Zoom secrets remain in Google Secret Manager, bound via `defineSecret`, and Stripe stayed in test/sandbox mode throughout. |
| Security requirements checklist (this round) | Re-confirmed below. |

**Security requirements checklist (per this round's explicit scope):**

| Requirement | Status |
|---|---|
| Users cannot access another user's private data | **Pass** [RUNTIME-EMU] — pre-existing, re-verified |
| Participants cannot mark themselves attended | **Pass** [RUNTIME-EMU] — pre-existing, re-verified |
| Participants cannot create badges or alter badge balances | **Pass** [RUNTIME-EMU] — pre-existing, re-verified |
| Participants cannot mark rewards redeemed or alter donation status | **Pass** [RUNTIME-EMU] — pre-existing, re-verified |
| Users cannot inject notifications into another user's inbox | **Pass, newly fixed** (M-6) [RUNTIME-EMU], deployed |
| Partners cannot access participant private survey data or another partner's data | **Pass** [RUNTIME-EMU] — pre-existing, re-verified |
| Stripe webhook signature verified | **Pass** [RUNTIME-PROD] + [RUNTIME-EMU] — pre-existing, re-verified |
| Stripe/Zoom secrets server-side only | **Pass** — Secret Manager + `defineSecret`; scanned source for `sk_*`/`whsec_*`/`rk_*`; none found |
| Storage files appropriately protected | **Pass, newly fixed** (M-10) — read now requires auth; deployed |
| Admin checks enforced server-side | **Pass** — always reads `users/{uid}.role`, never trusts client input |
| Callable functions validate auth/authorization | **Pass** — including the new `notifySessionRegistrants` (admin-only, [RUNTIME-EMU] verified) |

---

## Stripe Test Results

| Check | Result | Evidence |
|---|---|---|
| Checkout Session creation | **Pass** | [RUNTIME-PROD] 1 success on 2026-09-20 23:48 UTC. Two earlier 500 errors (Managed Payments: `payment_method_types`, then product tax code) were fixed that day. Validation and failure paths: [RUNTIME-EMU]. |
| Test payment | **Pass** | [RUNTIME-PROD] Completed by the product owner in the sandbox. A new checkout was **not** run during this QA, because that needs a human in the browser. |
| Webhook delivery | **Pass** | [RUNTIME-PROD] `stripeWebhook` logged 1 × 200 for the real event and 0 errors. |
| Firestore status update | **Pass** | [RUNTIME-PROD] `pending → paid`, with `paidAt`, the Checkout Session id, and the PaymentIntent id stored. |
| Admin donation record | **Data pass; UI not visually verified** | The record exists with the correct amount ($25.00 USD), purpose, and partner. The totals bug was found and fixed (M-2). |
| Duplicate webhook | **Pass** | [RUNTIME-EMU] sequential, concurrent, and concurrent-first deliveries are all idempotent. Stripe did not retry in production, so this was not observable there. |
| Cancellation | **Pass (data); UX fixed** | [RUNTIME-EMU] `expired → failed`; a paid donation is never downgraded. A real cancel click on Stripe's page was not exercised. |
| Live mode | Not used | Sandbox only, as required. |

---

## Rewards Test Results

| Check | Result |
|---|---|
| Eligibility (badge count, approval, active, expiry, stock) | **Pass** [RUNTIME-EMU] + [UNIT] |
| Redemption creates a record and spends exactly the badge cost | **Pass** [RUNTIME-EMU] |
| Unique code, 8 characters, unambiguous alphabet | **Pass**: 12/12 unique [RUNTIME-EMU] |
| QR | QR is **displayed** to participants (it encodes the code). There is **no partner-side QR scanning**; partners type the code. [CODE] |
| Inventory never negative (5-way race for the last unit) | **Pass** [RUNTIME-EMU] |
| Duplicate redemption (4-way race by the same participant) | **Pass** [RUNTIME-EMU] |
| One-time verification (sequential and 5-way concurrent) | **Pass** [RUNTIME-EMU] |
| Cross-partner verification blocked | **Pass** [RUNTIME-EMU] |
| Production state | 2 approved rewards (quantity 1 each, costing 5 and 1 badges) and 0 redemptions as of the initial audit. Not re-checked after this round's deploy (no destructive or mutating production action was taken, so this figure should be unchanged). |

---

## Build Results (2026-09-29 fix round)

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` | **11/11 pass** |
| `flutter build apk --debug` | **Pass**: `build/app/outputs/flutter-apk/app-debug.apk` |
| `flutter build web --release` | **Pass**: `build/web` (this is the exact tree deployed to Hosting). Same pre-existing, unrelated WebAssembly-incompatibility warning in the transitive `image` package as before — does not affect the standard JS build actually shipped. |
| `functions`: `npm run build` (tsc) | Pass, clean compile against Node types for the new `engines.node: "22"` |
| `qa`: `npm test` (Firestore emulator, single run, freshly cleared state) | **155/155 pass**, 0 fail — 19 suites across `rules.test.mjs`, `functions.test.mjs`, `attendance.test.mjs` |
| `firestore.rules` deploy compile | Pass — `firebase deploy --only firestore:rules` compiled and released without error |
| `storage.rules` deploy compile | Pass — `firebase deploy --only storage` compiled and released without error |

**Test-harness notes:**
- No standalone JDK is installed on this machine; the Firestore emulator was run using the JDK 17 runtime bundled with Android Studio (`C:\Program Files\Android\Android Studio\jbr`), added to `PATH` for that process only.
- The Functions emulator still hangs at function discovery on this machine, so — as before — the compiled handlers (`functions/lib/index.js`, including the new `notifySessionRegistrants`) were run in-process against the Firestore emulator instead of the Functions emulator.
- An earlier, same-day re-run of `functions.test.mjs` alone against a not-yet-cleared emulator showed 7 apparent Stripe-webhook failures. Root-caused to hardcoded event IDs in the test file colliding with idempotency-ledger entries left over from the prior run — i.e. the idempotency protection working as designed, not a defect. The 155/155 number above is from a single clean run and is the one this report relies on.

---

## Known Limitations

These are **not bugs**. They are features that are not implemented, or not implemented automatically.

- **Zoom attendance is admin-triggered, not automatic.** `syncSessionAttendance` pulls the report when an admin taps *Sync Attendance*. There is no webhook or scheduled import. **It has never been run against a real Zoom meeting**, because production has 0 sessions. Manual attendance entry remains available.
- **Zoom meeting creation has never been run against the real Zoom API.** It needs the `meeting:write:meeting:admin` scope on the Zoom app and speakers who are licensed users on the Bloom Zoom account. Only the precondition paths were tested [RUNTIME-EMU].
- **Session reminders are manual.** "Send Reminder Now" and "Notify: Starting" buttons exist, but there is no scheduler.
- **Notifications not implemented:**
  - Exit-survey prompt
  - Badge earned (an in-app celebration dialog exists, but no notification)
  - Participant reward-redemption confirmation
  - Donation receipt
  - Tapping a notification only marks it read; it does not navigate anywhere.
- **Participants cannot cancel their own registration.**
- **Check-in and Join are not time-gated.** Participants can check in and see the join link days early.
- **The participant session screen does not show** the end time, program, or audience.
- **Rewards:** there is no `requiredBadgeIds` (count-based eligibility only), no partner-side QR scanning, no partner profile-edit screen, and a partner's edits would not propagate to the public directory mirror (only admins write it).
- **Stripe refunds:** there is no `charge.refunded` handler, so the `refunded` status is never set automatically.
- **Placeholder screens still remaining:** Parent Portal and Learning Center. (Member Dashboard was fixed this round — see H-4. Profile & Settings was fixed this round — see M-7.)
- **L-3 (Zoom link exposure to all signed-in users)** and **L-5 (App Check not enforced)** remain open, reviewed and documented, not fixed this round — see their entries above for why.
- **Not tested at all:** real-device and web UI interaction, network failure and slow network, small-screen overflow, keyboard behaviour, the sign-up/login/password-reset UI, and Storage rules against the Storage emulator specifically (Storage rules were reviewed and deployed but not exercised against a running emulator, since the `qa/` harness targets Firestore only). Each of these needs a device or browser-automation setup, which was not available in this environment.

---

## Release Recommendation

### READY WITH KNOWN ISSUES

All Critical and High severity findings, and every Medium severity finding except none, are fixed and **deployed to production** as of 2026-09-29. What keeps this from an unqualified "READY":

1. **No human click-through of the deployed app has been performed.** Every fix is verified by code inspection, `flutter analyze`/`flutter test`, a clean 155/155 single-run Firestore-emulator test suite covering rules and Cloud Functions (including the new `notifySessionRegistrants`), and live non-mutating HTTP probes of the deployed Hosting site and `stripeWebhook` endpoint. No Android device or browser-automation tool was available in this environment, so no one has actually tapped "Register for Session" against the live, newly-deployed rules.
2. **L-3** (Zoom join link visible to all signed-in users) and **L-5** (App Check not enforced) remain open by deliberate, documented decision — both need dedicated follow-up work (a session data-model change, and client SDK integration + Console configuration, respectively) rather than being safely foldable into this fix round.
3. Several **Known Limitations** (manual Zoom sync, no registration cancellation, Parent Portal/Learning Center still placeholders, etc.) are unimplemented features, not defects, and can ship as documented gaps.

**Recommended before the next release:** a manual smoke test on the live site (https://bloomg2w.web.app) or a real device — register → check in → admin marks attended → exit survey → badge celebration → redeem a reward → partner verifies the code — the first time this exact sequence will have been exercised by a human against the deployed, fixed rules.

### Deployment actually performed this round

All of the following were run against the **live `bloomg2w` project** on 2026-09-29 and each reported success:

```bash
# 1. Firestore security rules — C-1, M-1, M-6
npx firebase-tools@latest deploy --only firestore:rules --project bloomg2w

# 2. Storage rules — M-10, L-6
npx firebase-tools@latest deploy --only storage --project bloomg2w

# 3. All Cloud Functions — H-3 (attendance), M-6 (new notifySessionRegistrants),
#    L-4 (Stripe metadata), M-11 (Node 22 runtime) — redeployed all 7 functions
#    since the runtime bump touches every function's deploy target
cd functions && npm run build && cd ..
npx firebase-tools@latest deploy --only functions --project bloomg2w

# 4. Web app — H-1, H-2, H-4, M-1..M-5, M-7, M-9, L-1, L-2
flutter build web --release
npx firebase-tools@latest deploy --only hosting --project bloomg2w
```

Live confirmation after deploy: `https://bloomg2w.web.app` returns HTTP 200; the deployed `stripeWebhook` Cloud Run URL returns HTTP 400 for a request with no Stripe signature header (correct — signature verification is enforced, and this was confirmed without sending any real or fabricated Stripe event).

**Mobile:** `flutter build apk --debug` succeeded (`build/app/outputs/flutter-apk/app-debug.apk`) with the same Dart-layer fixes. This debug build was not distributed to a device — no Android device or emulator was available to install it on. A release build and store/distribution upload were out of scope for this pass.

### Files changed during the 2026-09-29 fix round

| File | Change |
|---|---|
| `firestore.rules` | Notification create rule now requires `d.uid == request.auth.uid` (M-6); documented L-3 limitation in a comment |
| `functions/src/index.ts` | New admin-only callable `notifySessionRegistrants` (M-6) |
| `functions/src/stripe.ts` | `payment_intent_data.metadata` on Checkout Session creation (L-4) |
| `functions/package.json` | `engines.node` 20 → 22 (M-11) |
| `lib/services/session_service.dart` | `updateSession`/`cancelSession`/`sendReminderNow`/`sendSessionStartingNow` now call `notifySessionRegistrants`; only notify on an actual schedule change (M-6, M-8) |
| `lib/screens/admin/sessions/admin_session_form_screen.dart` | Pass `previous` session to `updateSession` (M-8) |
| `lib/screens/admin/sessions/admin_session_detail_screen.dart` | Error feedback on reminder/starting-now actions |
| `lib/widgets/upcoming_event_card.dart` | Rewritten to show real upcoming session data (H-4) |
| `lib/screens/member_dashboard_screen.dart` | Rewritten to show real profile/badge/session data, fabricated metrics removed (H-4) |
| `lib/screens/profile_settings_screen.dart` | Real membership type/date, real badges, dead controls removed (M-7) |
| `lib/services/storage_service.dart` | `ImageUploadKind` — per-purpose upload paths (L-6) |
| `lib/screens/speaker/speaker_application_form_screen.dart` | Uses `ImageUploadKind.speakerPhoto` (L-6) |
| `lib/screens/registration/partner/partner_profile_screen.dart` | Uses `ImageUploadKind.partnerLogo` (L-6) |
| `storage.rules` | Split into 3 per-purpose namespaces, auth-required read (M-10, L-6) |
| `lib/widgets/common/wizard_scaffold.dart` | `WizardPrimaryButton` royal/white instead of gold/royalDeep (M-9) |
| `lib/screens/about_screen.dart`, `founder_president_screen.dart`, `what_guides_us_screen.dart`, `membership_registration_screen.dart` | Same gold-contrast fix (M-9) |
| `.gitignore` | Added `node_modules/`, secret file patterns, emulator logs (L-7) |
| `qa/rules.test.mjs` | Notification-injection test flipped from documenting the gap to asserting the M-6 fix; 2 new tests |
| `qa/functions.test.mjs` | New `notifySessionRegistrants` test suite (6 tests) |
| `docs/END_TO_END_QA_REPORT.md` | This update |

No production **data** was modified at any point. Stripe stayed in sandbox/test mode throughout; no live keys were used, printed, or committed. Production **configuration** (Firestore rules, Storage rules, Cloud Functions, Hosting) was deployed as described above, with each deploy's success confirmed from its own CLI output plus a live, non-mutating HTTP check afterward.
