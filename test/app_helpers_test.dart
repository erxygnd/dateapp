import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tanisma_app/app_config.dart';
import 'package:tanisma_app/main.dart';
import 'package:tanisma_app/models/local_profile_photo.dart';
import 'package:tanisma_app/utils/chat_utils.dart';
import 'package:tanisma_app/utils/location_rules.dart';

void main() {
  group('profile helper functions', () {
    test('calculateAge handles birthdays before and after today', () {
      final today = DateTime(2026, 5, 7);

      expect(calculateAge(DateTime(2000, 5, 7), today: today), 26);
      expect(calculateAge(DateTime(2000, 5, 8), today: today), 25);
    });

    test('formats birth date as dd.mm.yyyy', () {
      expect(formatBirthDate(DateTime(1998, 1, 9)), '09.01.1998');
    });

    test('normalizes and validates usernames', () {
      expect(normalizeUsername('  Eray_24  '), 'eray_24');
      expect(isValidUsername('eray_24'), isTrue);
      expect(isValidUsername('er'), isFalse);
      expect(isValidUsername('eray-24'), isFalse);
    });
  });

  test('buildChatId returns a stable id independent of argument order', () {
    expect(buildChatId('user_b', 'user_a'), 'user_a_user_b');
    expect(buildChatId('user_a', 'user_b'), 'user_a_user_b');
  });

  test(
    'profile photos are embedded and decoded without Storage URLs',
    () async {
      final photos = await prepareProfilePhotoSources(
        photos: [
          LocalProfilePhoto(
            bytes: Uint8List.fromList([1, 2, 3]),
            fileName: 'profile.png',
            contentType: 'image/png',
          ),
        ],
      );

      expect(photos.single.startsWith(profilePhotoDataPrefix), isTrue);
      expect(embeddedProfilePhotoBytes(photos.single), [1, 2, 3]);
    },
  );

  group('location visibility rules', () {
    test('Ankara users can choose up to 50 km', () {
      expect(
        isLocationInAnkara(latitude: 39.92077, longitude: 32.85411),
        isTrue,
      );
      expect(
        radiusOptionsForLocation(latitude: 39.92077, longitude: 32.85411),
        contains(50),
      );
      expect(
        effectiveRadiusKmForLocation(
          requestedRadiusKm: 100,
          latitude: 39.92077,
          longitude: 32.85411,
        ),
        50,
      );
    });

    test('non-Ankara users keep the default radius choices', () {
      expect(
        isLocationInAnkara(latitude: 41.0082, longitude: 28.9784),
        isFalse,
      );
      expect(
        radiusOptionsForLocation(latitude: 41.0082, longitude: 28.9784),
        defaultRadiusOptionsKm,
      );
    });
  });
}
