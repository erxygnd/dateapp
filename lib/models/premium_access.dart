import '../app_config.dart';

class PremiumAccess {
  static const String freeTier = "free";
  static const String plusTier = "plus";
  static const String premiumTier = "premium";

  static Map<String, dynamic> defaultUserState() {
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
    return {
      "photoLockSeconds": chatPhotoLockDuration.inSeconds,
      "voiceMessagesEnabled": true,
      "paidOverridesEnabled": true,
      "earlyPhotoUnlockRequires": premiumTier,
    };
  }
}
