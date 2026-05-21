import 'package:cloud_firestore/cloud_firestore.dart';

class AppUserProfile {
  final String uid;
  final String username;
  final String name;
  final int? age;
  final DateTime? birthDate;
  final String? gender;
  final String bio;
  final String? email;
  final List<String> photoUrls;

  AppUserProfile({
    required this.uid,
    required this.username,
    required this.name,
    required this.age,
    required this.birthDate,
    required this.gender,
    required this.bio,
    required this.email,
    required this.photoUrls,
  });

  factory AppUserProfile.fromMap(Map<String, dynamic> data, String uid) {
    // Firestore verisi her zaman tertemiz gelmeyebilir.
    // Bu constructor eksik/bozuk alanlari ekrani kirmayacak hale getirir.
    final birthDateData = data["birthDate"];
    final photoData = data["photoUrls"];
    final rawName = (data["displayName"] ?? data["name"] ?? "").toString();

    return AppUserProfile(
      uid: uid,
      username: data["username"]?.toString() ?? "",
      name: rawName.trim().isEmpty ? "Kullanıcı" : rawName.trim(),
      age: data["age"] is int ? data["age"] : int.tryParse("${data["age"]}"),
      birthDate: birthDateData is Timestamp ? birthDateData.toDate() : null,
      gender: data["gender"]?.toString(),
      bio: data["bio"] ?? "",
      email: data["email"]?.toString(),
      photoUrls: photoData is List
          ? photoData.map((item) => item.toString()).toList()
          : const [],
    );
  }

  Map<String, dynamic> toRequestSnapshot() {
    // Bir ilana istek atarken profilin o anki kopyasini istege ekliyoruz.
    // Ilan sahibi gelen istekte kullanicinin temel bilgilerini hemen gorebilsin.
    return {
      "requesterName": name,
      "requesterUsername": username,
      "requesterAge": age,
      "requesterGender": gender,
      "requesterBio": bio,
      "requesterEmail": email,
      "requesterPhotoUrls": photoUrls,
    };
  }
}
