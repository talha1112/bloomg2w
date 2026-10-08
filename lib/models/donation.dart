import 'package:cloud_firestore/cloud_firestore.dart';

enum DonationStatus { pending, paid, failed, cancelled, refunded }

extension DonationStatusX on DonationStatus {
  String get value => name;

  static DonationStatus fromValue(String? value) {
    return DonationStatus.values.firstWhere(
      (s) => s.value == value?.trim(),
      orElse: () => DonationStatus.pending,
    );
  }

  String get label {
    switch (this) {
      case DonationStatus.pending:
        return 'Pending';
      case DonationStatus.paid:
        return 'Paid';
      case DonationStatus.failed:
        return 'Failed';
      case DonationStatus.cancelled:
        return 'Cancelled';
      case DonationStatus.refunded:
        return 'Refunded';
    }
  }
}

const kDonationPurposes = [
  'Participant Rewards',
  'Workshop',
  'Learning Resources',
  'General Support',
  'Other',
];

/// A Community Partner's financial contribution via Stripe Checkout.
/// Created server-side by the createDonationCheckout Cloud Function
/// (status starts 'pending') and moved to 'paid'/'failed' EXCLUSIVELY by
/// the stripeWebhook Cloud Function once Stripe confirms the payment —
/// never by the Flutter client, which only ever reads this doc.
class Donation {
  Donation({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.email,
    required this.amount,
    required this.currency,
    required this.purpose,
    required this.status,
    required this.createdAt,
    this.stripeCheckoutSessionId,
    this.stripePaymentIntentId,
    this.paidAt,
  });

  final String id;
  final String partnerId;
  final String partnerName;
  final String email;

  /// Amount in the currency's smallest unit (cents for USD) — matches
  /// what Stripe itself uses, avoiding floating-point currency math.
  final int amount;
  final String currency;
  final String purpose;
  final DonationStatus status;
  final DateTime createdAt;
  final String? stripeCheckoutSessionId;
  final String? stripePaymentIntentId;
  final DateTime? paidAt;

  double get amountDollars => amount / 100;

  factory Donation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Donation(
      id: doc.id,
      partnerId: data['partnerId'] as String? ?? '',
      partnerName: data['partnerName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'usd',
      purpose: data['purpose'] as String? ?? '',
      status: DonationStatusX.fromValue(data['status'] as String?),
      stripeCheckoutSessionId: data['stripeCheckoutSessionId'] as String?,
      stripePaymentIntentId: data['stripePaymentIntentId'] as String?,
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      paidAt: data['paidAt'] is Timestamp ? (data['paidAt'] as Timestamp).toDate() : null,
    );
  }
}
