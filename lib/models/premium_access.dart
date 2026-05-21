import '../app_config.dart';

class PremiumAccess {
  static const String freeTier = "free";
  static const String plusTier = "plus";
  static const String premiumTier = "premium";

  static Map<String, dynamic> defaultUserState() {
    // Yeni kayit olan herkes once ucretsiz paketle baslar.
    // Premium alanlari simdiden var ki ileride paket acinca veri yapisi hazir olsun.
    return {
      "tier": freeTier,
      "entitlements": {
        "priorityVisibility": false,
        "extendedRadius": false,
        "unlimitedRewinds": false,
        "earlyPhotoUnlock": false,
        "readReceipts": false,
      },
      "subscriptionProvider": null,
      "subscriptionStatus": "inactive",
      "expiresAt": null,
    };
  }

  static Map<String, dynamic> defaultChatPolicy() {
    // Sohbet acilinca hangi kurallar gecerli olacak burada belirlenir.
    // Ornek: fotograf kilidi kac saniye, ses mesaji acik mi?
    return {
      "photoLockSeconds": chatPhotoLockDuration.inSeconds,
      "voiceMessagesEnabled": true,
      "paidOverridesEnabled": true,
      "earlyPhotoUnlockRequires": premiumTier,
    };
  }
}
