import 'dart:convert';
import 'dart:typed_data';

import '../app_config.dart';

class LocalProfilePhoto {
  final Uint8List bytes;
  final String fileName;
  final String contentType;

  const LocalProfilePhoto({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  String toDataUrl() => "$profilePhotoDataPrefix${base64Encode(bytes)}";
}
