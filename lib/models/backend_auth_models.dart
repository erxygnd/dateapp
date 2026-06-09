class BackendAuthSession {
  final String userId;
  final String userName;
  final String email;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;

  const BackendAuthSession({
    required this.userId,
    required this.userName,
    required this.email,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
  });

  factory BackendAuthSession.fromJson(Map<String, dynamic> json) {
    return BackendAuthSession(
      userId: json["userId"].toString(),
      userName: json["userName"].toString(),
      email: json["email"].toString(),
      accessToken: json["accessToken"].toString(),
      accessTokenExpiresAt: DateTime.parse(
        json["accessTokenExpiresAt"].toString(),
      ),
      refreshToken: json["refreshToken"].toString(),
      refreshTokenExpiresAt: DateTime.parse(
        json["refreshTokenExpiresAt"].toString(),
      ),
    );
  }
}

class BackendProfile {
  final String userId;
  final String userName;
  final String email;
  final String? displayName;
  final int? age;
  final DateTime? birthDate;
  final String? gender;
  final String bio;
  final String? phoneNumber;
  final String? city;
  final List<String> photoUrls;

  const BackendProfile({
    required this.userId,
    required this.userName,
    required this.email,
    required this.displayName,
    required this.age,
    required this.birthDate,
    required this.gender,
    required this.bio,
    required this.phoneNumber,
    required this.city,
    required this.photoUrls,
  });

  factory BackendProfile.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json["photoUrls"];

    return BackendProfile(
      userId: json["userId"].toString(),
      userName: json["userName"].toString(),
      email: json["email"].toString(),
      displayName: _nullableString(json["displayName"]),
      age: json["age"] is int ? json["age"] : int.tryParse("${json["age"]}"),
      birthDate: _parseDateOnly(json["birthDate"]),
      gender: _nullableString(json["gender"]),
      bio: json["bio"]?.toString() ?? "",
      phoneNumber: _nullableString(json["phoneNumber"]),
      city: _nullableString(json["city"]),
      photoUrls: rawPhotos is List
          ? rawPhotos.map((item) => item.toString()).toList()
          : const [],
    );
  }
}

String backendDateOnly(DateTime date) {
  final month = date.month.toString().padLeft(2, "0");
  final day = date.day.toString().padLeft(2, "0");
  return "${date.year}-$month-$day";
}

DateTime? _parseDateOnly(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString());
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
