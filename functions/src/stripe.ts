import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import Stripe from "stripe";

import { getStripeClient, stripeSecretKey, stripeWebhookSecret } from "./stripeClient";

const ALLOWED_CURRENCIES = ["usd"];
const MIN_AMOUNT_CENTS = 100; // $1.00 — Stripe's own practical floor for card payments
const MAX_AMOUNT_CENTS = 100_000_00; // $100,000 sanity ceiling, well above any expected single contribution

const ALLOWED_PURPOSES = ["Participant Rewards", "Workshop", "Learning Resources", "General Support", "Other"];

interface CreateDonationCheckoutRequest {
  amountCents: number;
  currency: string;
  purpose: string;
}

/**
 * Community Partner-triggered: validates the donation amount/currency/
 * purpose SERVER-SIDE (never trusts the client-supplied amount beyond
 * this validation), creates a `pending` donations/{id} record, and
 * creates a Stripe Checkout Session with that donation's ID embedded in
 * metadata so the webhook can find its way back to the right record.
 * Returns the Checkout URL for Flutter to open — Stripe hosts the actual
 * payment form; this app never collects raw card details.
 */
export const createDonationCheckout = onCall(
  { secrets: [stripeSecretKey], region: "us-central1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const db = getFirestore("bloomg2w-db");

    // Only an approved Community Partner (or an admin, for support/testing)
    // may create a donation checkout under their own partner identity —
    // read from the trusted partners/{uid} doc, never from client input.
    const [userDoc, partnerDoc] = await Promise.all([
      db.collection("users").doc(uid).get(),
      db.collection("partners").doc(uid).get(),
    ]);
    const isAdmin = userDoc.data()?.role === "admin";
    const partner = partnerDoc.data();

    if (!isAdmin && (!partner || partner.status !== "approved")) {
      throw new HttpsError("permission-denied", "Only an approved Community Partner may make a financial contribution.");
    }

    const { amountCents, currency, purpose } = request.data as CreateDonationCheckoutRequest;

    if (!Number.isInteger(amountCents) || amountCents < MIN_AMOUNT_CENTS || amountCents > MAX_AMOUNT_CENTS) {
      throw new HttpsError("invalid-argument", `Amount must be an integer number of cents between ${MIN_AMOUNT_CENTS} and ${MAX_AMOUNT_CENTS}.`);
    }
    const normalizedCurrency = (currency ?? "usd").toLowerCase();
    if (!ALLOWED_CURRENCIES.includes(normalizedCurrency)) {
      throw new HttpsError("invalid-argument", `Unsupported currency: ${currency}`);
    }
    if (!ALLOWED_PURPOSES.includes(purpose)) {
      throw new HttpsError("invalid-argument", `Unsupported purpose: ${purpose}`);
    }

    const partnerName: string = partner?.businessName ?? (isAdmin ? "Admin" : "");
    const email: string = partner?.email ?? userDoc.data()?.email ?? "";

    const donationRef = db.collection("donations").doc();
    await donationRef.set({
      partnerId: uid,
      partnerName,
      email,
      amount: amountCents,
      currency: normalizedCurrency,
      purpose,
      status: "pending",
      stripeCheckoutSessionId: null,
      stripePaymentIntentId: null,
      createdAt: Timestamp.now(),
      paidAt: null,
    });

    try {
      const stripe = getStripeClient();
      const successUrl = "https://bloomg2w.web.app/donation-success?donationId=" + donationRef.id;
      const cancelUrl = "https://bloomg2w.web.app/donation-cancelled?donationId=" + donationRef.id;

      // `managed_payments` is a newer Stripe Checkout Session parameter
      // not yet present in this project's pinned `stripe` npm package's
      // TypeScript types, so the params object is typed as `any` here
      // specifically to allow it — the Stripe API itself accepts the
      // field regardless of the SDK's type definitions (verified against
      // the exact parameter path Stripe's own error message named:
      // managed_payments[enabled]=false).
      //
      // Why disable it: this Stripe account has Managed Payments enabled
      // by default, which (a) rejects the explicit payment_method_types
      // parameter and (b) requires a product tax code on every line item.
      // A Community Partner donation is a charitable contribution, not a
      // taxable product sale, so disabling Managed Payments for this
      // specific Checkout Session — rather than inventing a tax code — is
      // the correct fit. This does not change how card payments are
      // collected or processed, only how Stripe categorizes/taxes the
      // line item.
      const sessionParams: Stripe.Checkout.SessionCreateParams & { managed_payments?: { enabled: boolean } } = {
        mode: "payment",
        managed_payments: { enabled: false },
        line_items: [
          {
            price_data: {
              currency: normalizedCurrency,
              product_data: {
                name: `Project Bloom G2W — ${purpose}`,
                description: "Community Partner contribution to Project Bloom Girls 2 Women",
              },
              unit_amount: amountCents,
            },
            quantity: 1,
          },
        ],
        customer_email: email || undefined,
        success_url: successUrl,
        cancel_url: cancelUrl,
        metadata: {
          donationId: donationRef.id,
          partnerId: uid,
          purpose,
        },
        // Checkout Session metadata is NOT automatically copied onto the
        // PaymentIntent Stripe creates for the actual charge — without this,
        // a `payment_intent.payment_failed` webhook event carries no
        // donationId and can never be matched back to this donation (QA
        // finding L-4). Setting it explicitly here makes that webhook
        // branch actually reachable for a declined card.
        payment_intent_data: {
          metadata: {
            donationId: donationRef.id,
            partnerId: uid,
            purpose,
          },
        },
      };

      const session = await stripe.checkout.sessions.create(sessionParams as Stripe.Checkout.SessionCreateParams);

      await donationRef.update({ stripeCheckoutSessionId: session.id });

      return { donationId: donationRef.id, checkoutUrl: session.url };
    } catch (error: any) {
      logger.error("createDonationCheckout: Stripe session creation failed", { donationId: donationRef.id, error: error?.message });
      await donationRef.update({ status: "failed" });
      throw new HttpsError("internal", `Could not start checkout: ${error?.message ?? error}`);
    }
  }
);

/**
 * Public HTTPS endpoint Stripe calls directly (not a callable — Stripe
 * cannot send Firebase Auth tokens). Trust comes entirely from verifying
 * the raw request body's signature against STRIPE_WEBHOOK_SECRET; an
 * unsigned or mis-signed request is rejected before any Firestore write.
 * This is the ONLY code path that may ever set a donation to 'paid' —
 * the Flutter app returning from Stripe's success URL proves nothing on
 * its own and never writes donation status.
 */
export const stripeWebhook = onRequest(
  { secrets: [stripeSecretKey, stripeWebhookSecret], region: "us-central1" },
  async (req, res) => {
    const signature = req.headers["stripe-signature"];
    if (!signature || typeof signature !== "string") {
      res.status(400).send("Missing Stripe-Signature header");
      return;
    }

    let event: Stripe.Event;
    try {
      const stripe = getStripeClient();
      // req.rawBody is populated by the Cloud Functions runtime for
      // onRequest handlers — using it (not req.body, which Express may
      // have already parsed/re-serialized) is required for the signature
      // to verify correctly.
      event = stripe.webhooks.constructEvent((req as any).rawBody, signature, stripeWebhookSecret.value());
    } catch (error: any) {
      logger.error("stripeWebhook: signature verification failed", { error: error?.message });
      res.status(400).send(`Webhook signature verification failed: ${error?.message ?? error}`);
      return;
    }

    const db = getFirestore("bloomg2w-db");

    // Idempotency: record every processed Stripe event ID before acting
    // on it, inside the same transaction as the donation update, so a
    // retried/duplicate delivery of the same event (Stripe explicitly
    // does not guarantee exactly-once delivery) can never double-process
    // a payment or create a duplicate funding action.
    const eventLogRef = db.collection("stripe_webhook_events").doc(event.id);

    try {
      if (event.type === "checkout.session.completed" || event.type === "checkout.session.async_payment_succeeded") {
        const session = event.data.object as Stripe.Checkout.Session;
        const donationId = session.metadata?.donationId;
        if (!donationId) {
          logger.error("stripeWebhook: checkout session missing donationId metadata", { sessionId: session.id });
          res.status(200).send("Ignored: no donationId in metadata");
          return;
        }

        const donationRef = db.collection("donations").doc(donationId);

        await db.runTransaction(async (tx) => {
          const eventLogDoc = await tx.get(eventLogRef);
          if (eventLogDoc.exists) {
            // Already processed this exact Stripe event — do nothing.
            return;
          }
          const donationDoc = await tx.get(donationRef);
          if (!donationDoc.exists) {
            logger.error("stripeWebhook: donation record not found", { donationId });
            tx.set(eventLogRef, { type: event.type, processedAt: Timestamp.now(), note: "donation not found" });
            return;
          }
          if (donationDoc.data()?.status === "paid") {
            // Already paid (e.g. a second qualifying event for the same
            // session) — record this event as seen and stop.
            tx.set(eventLogRef, { type: event.type, processedAt: Timestamp.now(), note: "already paid" });
            return;
          }

          tx.update(donationRef, {
            status: "paid",
            paidAt: Timestamp.now(),
            stripePaymentIntentId: typeof session.payment_intent === "string" ? session.payment_intent : session.payment_intent?.id ?? null,
          });
          tx.set(eventLogRef, { type: event.type, processedAt: Timestamp.now(), donationId });
        });
      } else if (event.type === "checkout.session.expired" || event.type === "payment_intent.payment_failed") {
        // payment_intent.payment_failed now carries donationId because
        // createDonationCheckout sets payment_intent_data.metadata on the
        // Checkout Session (QA finding L-4) — a Checkout Session's own
        // metadata is not copied to its PaymentIntent by Stripe by default.
        const obj = event.data.object as Stripe.Checkout.Session | Stripe.PaymentIntent;
        const donationId = (obj as any).metadata?.donationId;
        if (donationId) {
          const donationRef = db.collection("donations").doc(donationId);
          await db.runTransaction(async (tx) => {
            const eventLogDoc = await tx.get(eventLogRef);
            if (eventLogDoc.exists) return;
            const donationDoc = await tx.get(donationRef);
            if (donationDoc.exists && donationDoc.data()?.status === "pending") {
              tx.update(donationRef, { status: "failed" });
            }
            tx.set(eventLogRef, { type: event.type, processedAt: Timestamp.now(), donationId });
          });
        }
      } else {
        // Unhandled event type — acknowledge so Stripe doesn't retry, but
        // do nothing else.
        logger.info("stripeWebhook: unhandled event type", { type: event.type });
      }

      res.status(200).send("OK");
    } catch (error: any) {
      logger.error("stripeWebhook: processing failed", { eventId: event.id, type: event.type, error: error?.message });
      // 500 so Stripe retries delivery — the idempotency check above
      // ensures a retry is always safe.
      res.status(500).send("Internal error processing webhook");
    }
  }
);
