import 'package:flutter/services.dart';

const Duration profilePhotoUploadTimeout = Duration(seconds: 45);
const Duration profileSaveTimeout = Duration(seconds: 18);
const int profilePhotoPreviewCacheSize = 360;
const int profilePhotoStoredPixels = 192;
const String profilePhotoDataPrefix = "data:image/png;base64,";
const Duration chatPhotoLockDuration = Duration(minutes: 5);
const Duration voiceRecordingMaxDuration = Duration(seconds: 60);
const MethodChannel appMediaChannel = MethodChannel("tanisma_app/media");
