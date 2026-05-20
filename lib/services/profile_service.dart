import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user_profile.dart';

Future<AppUserProfile> loadUserProfile(User user) async {
  final users = FirebaseFirestore.instance.collection("users");
  final doc = await users.doc(user.uid).get();
  var data = doc.data();

  final profileLooksIncomplete =
      data == null ||
      data.isEmpty ||
      (data["username"] == null &&
          data["gender"] == null &&
          data["photoUrls"] == null);

  if (profileLooksIncomplete && user.email != null) {
    final byEmail = await users
        .where("email", isEqualTo: user.email)
        .limit(1)
        .get();

    if (byEmail.docs.isNotEmpty) {
      data = byEmail.docs.first.data();

      if (byEmail.docs.first.id != user.uid) {
        await users.doc(user.uid).set({
          ...data,
          "uid": user.uid,
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  data ??= {};

  return AppUserProfile.fromMap({
    "username": data["username"] ?? "",
    "name": data["name"] ?? user.displayName ?? "Kullanıcı",
    "displayName": data["displayName"],
    "age": data["age"],
    "birthDate": data["birthDate"],
    "gender": data["gender"],
    "bio": data["bio"] ?? "",
    "email": data["email"] ?? user.email,
    "photoUrls": data["photoUrls"] ?? const [],
  }, user.uid);
}
