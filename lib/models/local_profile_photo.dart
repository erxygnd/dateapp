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

  // Resim dosyasini Firestore'a yazilabilecek tek parca metne cevirir.
  // Yani "fotograf" burada aslinda base64 denen uzun bir yaziya donusur.
  String toDataUrl() => "$profilePhotoDataPrefix${base64Encode(bytes)}";
}
