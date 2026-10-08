# Community Partner Workflow — Project Bloom G2W

## End-to-end flow

```text
Partner registers (registration/partner/*)
        ↓
partners/{uid} created, status = "pending"
        ↓  (partner is NOT yet visible in the member-facing directory)
Admin reviews (Admin → Community Partners)
        ↓
Admin approves → partners/{uid}.status = "approved"
        ↓         AND partner_profiles/{uid} is published (public, PII-free)
Partner proposes a reward (My Rewards → Create Reward)
        ↓
rewards/{id} created, status = "pending" (never visible to participants yet)
        ↓
Admin reviews the reward (Partner Detail → Rewards Proposed)
        ↓
Admin approves → rewards/{id}.status = "approved"
        ↓         (now visible in the participant Rewards Marketplace,
        ↓          subject to also being active/in-stock/unexpired)
Participant redeems (badge-gated, atomic Cloud Function transaction)
        ↓
reward_redemptions/{id} created with a unique one-time code
        ↓
Participant shows code (or its QR code) to the partner
        ↓
Partner verifies (Verify Code screen → markRedemptionUsed Cloud Function)
        ↓
Redemption atomically flips issued → used (cannot happen twice)
        ↓
Partner receives a thank-you notification (app_notifications, reused
infrastructure — AppNotificationType.general)
```

## Partner statuses

| Status | Meaning |
|---|---|
| `pending` | Just registered, awaiting admin review. Invisible to members. |
| `approved` | Admin-approved. Published to the public directory. May propose rewards and make financial contributions. |
| `rejected` | Admin declined the application. Never published. |
| `suspended` | Was approved, now paused by an admin. Retracted from the public directory; existing rewards are not deleted but the partner should be re-reviewed before re-approving. |

Only an admin can change a partner's status — see
`PartnerService.approvePartner()` / `PartnerService.setPartnerStatus()`
(Flutter) and the corresponding `isValidAdminPartnerStatusUpdate()` rule in
`firestore.rules`.

## Reward statuses

Rewards have **two independent controls**:

- **`status`** (admin-controlled approval lifecycle): `pending` → `approved`
  (or `rejected`). Only an admin can move a reward into `approved` — a
  partner can never self-approve.
- **`active`** (partner-controlled pause toggle): once approved, the owning
  partner may flip `active` off to temporarily hide the reward without
  losing its approval, then flip it back on later.

Both `status == 'approved'` AND `active == true` (plus in-stock and
unexpired) are required for a reward to appear in the Rewards Marketplace —
see `BloomReward.isAvailable` and `PartnerService.watchMarketplaceRewards()`.

`paused`/`expired`/`depleted` in the spec's status vocabulary are
represented as: `active == false` (paused by the partner), an expired
`expirationDate`, or `remainingQuantity == 0` — rather than as separate
`status` enum values the admin sets by hand, since these are computed facts
about the reward, not admin judgment calls. `rejected` is the one additional
`status` value an admin can set directly.

## Badge eligibility (reused, not reinvented)

A reward's `badgeCost` is the number of the participant's own **unspent**
`session_badges` docs required to redeem it. A badge counts as unspent until
it has been spent on some redemption (`redemptionId == null`). This is the
existing Bloom badge system — no parallel eligibility system was created.

`requiredBadgeIds` (specific badges, not just a count) was not implemented:
the existing badge model has no concept of distinct "badge types" to select
from — every badge currently represents "attended + completed a session,"
undifferentiated. Implementing `requiredBadgeIds` meaningfully would require
first introducing a badge taxonomy, which is a larger change than this task
covers. If the client needs a specific-badge requirement, that starts with
a badge-type field on `session_badges`.

## One-time redemption security

Redemption and verification are both Cloud Functions using Firestore
transactions — never a client-side `if status == issued` check:

- **`redeemReward`**: verifies unspent badge balance ≥ cost, spends exactly
  that many badges, decrements `remainingQuantity`, creates a unique code —
  all inside one transaction. Two concurrent redemption attempts by the same
  participant (or against the same reward's last unit) cannot both succeed;
  Firestore's optimistic concurrency forces one to retry against fresh data.
- **`markRedemptionUsed`**: looks up a code scoped to the calling partner's
  own uid (one partner can never touch another's codes), and atomically
  flips `status: issued → used`. A second call against an already-used code
  returns a clear "already redeemed" error rather than silently succeeding.

See `docs/reward_redemption.md` for the full technical detail.

## What a Community Partner can and cannot see

Enforced by Firestore rules, not just UI hiding:

- Can see: their own `partners/{uid}` doc (full PII), their own proposed
  rewards, their own donation history, their own redemption history
  (`reward_redemptions` scoped by `partnerUid`)
- Cannot see: another partner's private data, any participant's private
  survey/check-in responses, any participant's profile beyond what a
  redemption record itself carries (`participantUid` only — no name, email,
  or history is attached to a redemption doc)
