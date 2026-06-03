import 'package:flutter/services.dart';

// Uygulamada sure, boyut ve kanal gibi ortak ayarlar burada durur.
// Tek yerde durunca ileride "5 dakika 10 dakika olsun" gibi degisiklikler kolaylasir.
const Duration profilePhotoUploadTimeout = Duration(seconds: 45);
const Duration profileSaveTimeout = Duration(seconds: 18);
const int profilePhotoPreviewCacheSize = 360;
const int profilePhotoStoredPixels = 192;
const int profilePhotoMemoryCacheLimit = 24;
const String profilePhotoDataPrefix = "data:image/png;base64,";
const Duration chatPhotoLockDuration = Duration(minutes: 5);
const Duration voiceRecordingMaxDuration = Duration(seconds: 60);
const bool enableExpensiveGlassBlur = false;
const int encounterFeedPageSize = 40;
const int swipeDeckLookaheadCount = 6;
const int incomingRequestPageSize = 60;
const int chatListPageSize = 50;
const int chatMessagePageSize = 80;

// Flutter'in Android/iOS tarafina "ses kaydi baslat/durdur" diye komut yolladigi kopru.
const MethodChannel appMediaChannel = MethodChannel("tanisma_app/media");
