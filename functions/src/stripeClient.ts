import { defineSecret } from "firebase-functions/params";
import Stripe from "stripe";

export const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");
export const stripeWebhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");

let cachedClient: Stripe | null = null;

/**
 * Lazily constructs the Stripe SDK client using the secret's resolved
 * runtime value — never cached across cold starts in a way that could
 * outlive a rotated secret, since Cloud Functions instances are
 * short-lived and each invocation re-reads the current secret binding.
 */
export function getStripeClient(): Stripe {
  if (!cachedClient) {
    cachedClient = new Stripe(stripeSecretKey.value(), { apiVersion: "2025-02-24.acacia" });
  }
  return cachedClient;
}
