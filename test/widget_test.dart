import 'package:bloom_g2w/models/bloom_reward.dart';
import 'package:bloom_g2w/models/bloom_session.dart';
import 'package:bloom_g2w/models/donation.dart';
import 'package:bloom_g2w/models/partner_profile.dart';
import 'package:bloom_g2w/models/session_registration.dart';
import 'package:bloom_g2w/models/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

BloomReward _reward({RewardStatus status = RewardStatus.approved, bool active = true, int remaining = 3, DateTime? expires}) {
  return BloomReward(
    id: 'r',
    partnerUid: 'p',
    partnerName: 'Biz',
    name: 'Gift',
    value: 25,
    quantityAvailable: 5,
    remainingQuantity: remaining,
    badgeCost: 2,
    createdAt: DateTime(2026),
    status: status,
    active: active,
    expirationDate: expires,
  );
}

void main() {
  group('session calendar dates', () {
    test('stored as midnight UTC of the picked calendar day', () {
      final ts = timestampFromCalendarDate(DateTime(2026, 10, 5));
      expect(ts.toDate().toUtc(), DateTime.utc(2026, 10, 5));
    });

    test('time of day on the picked DateTime never shifts the stored day', () {
      final ts = timestampFromCalendarDate(DateTime(2026, 10, 5, 23, 59));
      expect(ts.toDate().toUtc(), DateTime.utc(2026, 10, 5));
    });

    test('reads back the same calendar day for every viewer', () {
      final date = calendarDateFromTimestamp(Timestamp.fromDate(DateTime.utc(2026, 10, 5)));
      expect([date.year, date.month, date.day], [2026, 10, 5]);
      expect(date.isUtc, isFalse, reason: 'returned as a local calendar date for display/comparison');
    });

    test('round trip is stable', () {
      for (final d in [DateTime(2026, 1, 1), DateTime(2026, 2, 28), DateTime(2026, 12, 31)]) {
        final back = calendarDateFromTimestamp(timestampFromCalendarDate(d));
        expect([back.year, back.month, back.day], [d.year, d.month, d.day]);
      }
    });
  });

  group('rewards marketplace visibility', () {
    test('approved, active, in stock, unexpired is available', () {
      expect(_reward().isAvailable, isTrue);
    });

    test('pending or rejected rewards are never available', () {
      expect(_reward(status: RewardStatus.pending).isAvailable, isFalse);
      expect(_reward(status: RewardStatus.rejected).isAvailable, isFalse);
    });

    test('paused, depleted, or expired rewards are not available', () {
      expect(_reward(active: false).isAvailable, isFalse);
      expect(_reward(remaining: 0).isAvailable, isFalse);
      expect(_reward(expires: DateTime.now().subtract(const Duration(days: 1))).isAvailable, isFalse);
    });
  });

  group('safe status defaults', () {
    test('unknown partner status is treated as pending, never approved', () {
      expect(PartnerStatusX.fromValue('bogus'), PartnerStatus.pending);
      expect(PartnerStatusX.fromValue(null), PartnerStatus.pending);
    });

    test('unknown reward status is treated as pending, never approved', () {
      expect(RewardStatusX.fromValue('bogus'), RewardStatus.pending);
    });

    test('unknown donation status is treated as pending, never paid', () {
      expect(DonationStatusX.fromValue('bogus'), DonationStatus.pending);
    });
  });

  test('registration id is the composite sessionId_uid', () {
    expect(SessionRegistration.idFor(sessionId: 's1', uid: 'u1'), 's1_u1');
  });

  group('AppRole (Girl/Woman/Parent role split)', () {
    test('fromValue round-trips every role, including the new minor/guardian values', () {
      for (final role in AppRole.values) {
        expect(AppRoleX.fromValue(role.value), role);
      }
    });

    test('fromValue defaults an unknown or missing role to member, never escalates', () {
      expect(AppRoleX.fromValue('bogus'), AppRole.member);
      expect(AppRoleX.fromValue(null), AppRole.member);
      expect(AppRoleX.fromValue(''), AppRole.member);
    });

    test('every role has a distinct, non-empty label', () {
      final labels = AppRole.values.map((r) => r.label).toSet();
      expect(labels.length, AppRole.values.length, reason: 'labels must not collide between roles');
      for (final label in labels) {
        expect(label, isNotEmpty);
      }
    });
  });
}
