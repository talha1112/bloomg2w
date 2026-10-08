# Stripe Setup — Project Bloom G2W

This document covers everything needed to get the Community Partner financial
contribution flow working end-to-end, in Stripe **test mode** first.

## 1. Where secrets live

Two secrets are stored in Google Secret Manager (never in the Flutter app,
never in this repo):

| Secret name | Purpose |
|---|---|
| `STRIPE_SECRET_KEY` | Server-side Stripe API key used by `createDonationCheckout` and `stripeWebhook` |
| `STRIPE_WEBHOOK_SECRET` | Verifies that incoming webhook requests actually came from Stripe |

Both are bound to the Cloud Functions via `defineSecret()` in
`functions/src/stripeClient.ts` and consumed only inside the deployed
functions — the Flutter client never sees either value.

`STRIPE_SECRET_KEY` has already been set from a Stripe **test-mode** secret
key provided during setup. **That key was pasted into a chat conversation and
must be rotated** in the Stripe Dashboard (Developers → API keys → roll key)
before this goes anywhere near production, even though it is test-mode only.

## 2. Setting/rotating a secret

Run this yourself in a terminal — never paste the actual key value into a
chat session or commit it anywhere:

```bash
cd functions
firebase functions:secrets:set STRIPE_SECRET_KEY --project bloomg2w
# You'll be prompted to paste the key (input is hidden)
```

After rotating, redeploy the two functions that use it:

```bash
firebase deploy --only functions:createDonationCheckout,functions:stripeWebhook --project bloomg2w
```

## 3. Registering the webhook endpoint (required step — not yet done)

The webhook function is deployed at:

```
https://us-central1-bloomg2w.cloudfunctions.net/stripeWebhook
```

To register it in Stripe:

1. Go to the [Stripe Dashboard](https://dashboard.stripe.com/) → **Developers → Webhooks**
2. Make sure you're in **Test mode** (toggle top-right)
3. Click **Add endpoint**
4. Endpoint URL: the URL above
5. Select these events to listen for:
   - `checkout.session.completed`
   - `checkout.session.async_payment_succeeded`
   - `checkout.session.expired`
   - `payment_intent.payment_failed`
6. Save the endpoint
7. Stripe will show a **Signing secret** (starts with `whsec_...`) — copy it

## 4. Setting the real webhook signing secret

A **placeholder** value is currently stored in `STRIPE_WEBHOOK_SECRET` so the
function could deploy at all (the real secret can only be generated *after*
Stripe knows the endpoint URL, and the endpoint had to exist to have a URL to
register — this is expected, not a mistake). Once you have the real
`whsec_...` value from step 3 above:

```bash
cd functions
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --project bloomg2w
# Paste the real whsec_... value when prompted

firebase deploy --only functions:stripeWebhook --project bloomg2w
```

Until this step is done, `stripeWebhook` will reject every request with a
signature-verification failure — this is the correct, secure behavior (see
Part 15 of the original spec: an unsigned/mis-signed webhook must never be
trusted), not a bug.

## 5. Testing the full flow in Stripe test mode

1. In the app, sign in as an **approved** Community Partner
2. Go to Partner Dashboard → Financial Contribution
3. Pick an amount and purpose, tap **Continue to Payment**
4. On Stripe's hosted Checkout page, use a [Stripe test card](https://docs.stripe.com/testing#cards):
   - Success: `4242 4242 4242 4242`, any future expiry, any CVC
   - Decline: `4000 0000 0000 0002`
5. After completing payment, you're returned to the app's confirmation screen
6. The screen shows **"Confirming Your Payment…"** until the webhook fires
   (usually a few seconds), then updates to **"Thank You! 🌸"** once Stripe's
   webhook has actually confirmed the charge — the app never claims success
   just because Checkout redirected back
7. Check Firestore: `donations/{id}` should show `status: "paid"`,
   `paidAt` set, and `stripePaymentIntentId` populated
8. Check the Stripe Dashboard → Webhooks → your endpoint → **Recent
   deliveries** to confirm the event was delivered and returned `200 OK`

## 6. Currency and amount limits

- Currently only `usd` is accepted (`ALLOWED_CURRENCIES` in
  `functions/src/stripe.ts`) — add more there if the client needs
  multi-currency support later
- Amounts are validated server-side: minimum $1.00 (100 cents), maximum
  $100,000 per contribution — both are sanity limits, adjust in
  `functions/src/stripe.ts` if needed

## 7. Moving to live credentials

When ready to accept real payments:

1. In the Stripe Dashboard, toggle to **Live mode**
2. Get the live secret key (`sk_live_...`) and set it:
   ```bash
   firebase functions:secrets:set STRIPE_SECRET_KEY --project bloomg2w
   ```
3. Register a **new** webhook endpoint under Live mode (same URL, since the
   Cloud Function URL doesn't change between test/live — only the Stripe
   Dashboard mode toggle differs) and get its live signing secret:
   ```bash
   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --project bloomg2w
   ```
4. Redeploy:
   ```bash
   firebase deploy --only functions:createDonationCheckout,functions:stripeWebhook --project bloomg2w
   ```

**No Flutter source code changes are required** to move from test to live —
the switch is entirely in which Stripe API keys are bound to the secrets.

## 8. Success/cancel redirect URLs

`createDonationCheckout` currently redirects to:

- Success: `https://bloomg2w.web.app/donation-success?donationId=...`
- Cancel: `https://bloomg2w.web.app/donation-cancelled?donationId=...`

These are placeholder web URLs. Since the actual "did it work" state is read
live from Firestore by `DonationConfirmationScreen` (not from the URL a
browser lands on), these redirect targets mainly matter for the web build —
confirm they point at wherever the deployed Flutter web app actually serves
those routes, or adjust `functions/src/stripe.ts` if the hosting domain
differs from `bloomg2w.web.app`.
