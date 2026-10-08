# Reward Redemption — Technical Reference

## Collections involved

- `rewards/{rewardId}` — the offer template (name, badgeCost, quantity,
  status, active)
- `session_badges/{sessionId}_{uid}` — a participant's earned badges;
  `redemptionId` is `null` while unspent, set to a redemption's ID once
  spent (never deleted — badge history/celebration state survives)
- `reward_redemptions/{redemptionId}` — one doc per individual claim, with
  its own unique `code` and `status` (`pending` | `used`)

## `redeemReward` (Cloud Function, callable)

Called from `PartnerService.redeemReward(rewardId)`.

1. Requires authentication (`request.auth.uid`)
2. Inside **one Firestore transaction**:
   a. Reads the reward doc — must be `status == 'approved'`, `active ==
      true`, not expired, `remainingQuantity >= 1`
   b. Queries the caller's own `session_badges` where `redemptionId ==
      null` (unspent) — must have at least `badgeCost` of them
   c. Marks exactly `badgeCost` of those badges spent (sets `redemptionId`
      + `spentAt`)
   d. Decrements the reward's `remainingQuantity` by 1
   e. Creates the `reward_redemptions` doc with a fresh cryptographically
      random 8-character code (`crypto.randomBytes`, not `Math.random`)
3. Returns `{ redemptionId, code }` to the client

All reads happen before all writes (a Firestore transaction requirement).
If any validation fails, the whole transaction throws and nothing is
written — there is no partial state where a badge is spent but no
redemption record exists, or vice versa.

**Concurrency**: Firestore transactions use optimistic concurrency — if two
concurrent calls would touch the same badge doc or the same reward doc,
one is automatically retried against the now-current data by the Firestore
client SDK. This is what prevents double-spending, not any application-level
locking code.

## `markRedemptionUsed` (Cloud Function, callable)

Called from `PartnerService.markRedemptionUsed(code)`.

1. Requires authentication
2. Looks up `reward_redemptions` where `partnerUid == caller's own uid AND
   code == <normalized code>` — a partner can never look up (let alone
   verify) another partner's codes, because the query itself is scoped to
   their own uid
3. Inside a transaction: re-reads the redemption doc, checks `status !=
   'used'`, and if so atomically sets `status: 'used'`, `usedAt`,
   `usedByPartnerUid`
4. A second call against the same code returns
   `failed-precondition: "This code has already been redeemed."` — the
   partner-facing UI (`PartnerVerifyCodeScreen`) surfaces this clearly
5. On success, fires a best-effort thank-you notification to the partner
   (reuses `app_notifications` / `NotificationService` infrastructure) —
   a notification failure is logged but never undoes the already-committed
   redemption

## Why this can't be done safely with client-side rules alone

Firestore security rules can express "only the owner may update this doc"
and "only these fields may change," but they cannot express "decrement this
counter only if the result would still be ≥ 0" or "spend exactly N of these
M documents" as a single atomic operation — rules evaluate one document
write in isolation, not a coordinated set of them. That coordination is
exactly what a Cloud Function transaction provides, which is why the
Firestore rules for `session_badges`, `rewards.remainingQuantity`, and
`reward_redemptions` all say `allow write: if false` (or heavily restrict
direct writes) — the trusted path is *only* through these two functions.

## QR code

`RewardsScreen` displays the redemption code as both plain text and a QR
code (via `qr_flutter`, participant-side display only — no camera/scanning
package was added). The QR simply encodes the same code string; there is no
separate `qrData` field stored in Firestore, since the code itself is
sufficient input to render a QR code on demand. Partner-side verification
remains manual code entry (`PartnerVerifyCodeScreen`) — no camera-based QR
scanner was added for the MVP, since manual entry already fully satisfies
the one-time-redemption security requirement, and a scanner adds camera
permission/platform setup that wasn't explicitly required.
