import 'package:cloud_firestore/cloud_firestore.dart';

class EncounterPost {
  final String id;
  final String place;
  final String dateTimeText;
  final String description;
  final String note;
  final String vehiclePlate;
  final String personAppearance;
  final String personTraits;
  final int requestCount;
  final String ownerId;
  final String ownerName;
  // Ilan acik kimlikle birakildiysa kartta ad/yas/fotograf gosterebilmek icin
  // kullanicinin profilinden o anki kucuk bir ozet sakliyoruz.
  final int? ownerAge;
  final List<String> ownerPhotoUrls;
  final bool isAnonymous;
  final GeoPoint location;
  final Timestamp? createdAt;

  EncounterPost({
    required this.id,
    required this.place,
    required this.dateTimeText,
    required this.description,
    required this.note,
    required this.vehiclePlate,
    required this.personAppearance,
    required this.personTraits,
    required this.requestCount,
    required this.ownerId,
    required this.ownerName,
    required this.ownerAge,
    required this.ownerPhotoUrls,
    required this.isAnonymous,
    required this.location,
    required this.createdAt,
  });

  factory EncounterPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    // Firestore belgesini uygulamanin anlayacagi EncounterPost nesnesine ceviriyoruz.
    // Eksik alan varsa bos/metin/sifir gibi guvenli degerlerle dolduruyoruz.
    final data = doc.data() ?? {};
    final dynamic locationData = data["location"];
    final dynamic ownerPhotoData = data["ownerPhotoUrls"];

    return EncounterPost(
      id: doc.id,
      place: data["place"] ?? "",
      dateTimeText: data["dateTimeText"] ?? "",
      description: data["description"] ?? "",
      note: data["note"] ?? "",
      vehiclePlate: data["vehiclePlate"]?.toString() ?? "",
      personAppearance: data["personAppearance"]?.toString() ?? "",
      personTraits: data["personTraits"]?.toString() ?? "",
      requestCount: data["requestCount"] is int
          ? data["requestCount"]
          : int.tryParse("${data["requestCount"]}") ?? 0,
      ownerId: data["ownerId"] ?? "",
      ownerName: data["ownerName"] ?? "Kullanıcı",
      ownerAge: data["ownerAge"] is int
          ? data["ownerAge"]
          : int.tryParse("${data["ownerAge"]}"),
      ownerPhotoUrls: ownerPhotoData is List
          ? ownerPhotoData.map((item) => item.toString()).toList()
          : const [],
      isAnonymous: data["isAnonymous"] == true,
      location: locationData is GeoPoint ? locationData : const GeoPoint(0, 0),
      createdAt: data["createdAt"] is Timestamp ? data["createdAt"] : null,
    );
  }

  factory EncounterPost.fromBackend(Map<String, dynamic> json) {
    return EncounterPost(
      id: json["id"]?.toString() ?? "",
      place: json["place"]?.toString() ?? "",
      dateTimeText: json["dateTimeText"]?.toString() ?? "",
      description: json["description"]?.toString() ?? "",
      note: json["note"]?.toString() ?? "",
      vehiclePlate: json["vehiclePlate"]?.toString() ?? "",
      personAppearance: json["personAppearance"]?.toString() ?? "",
      personTraits: json["personTraits"]?.toString() ?? "",
      requestCount: json["requestCount"] is int
          ? json["requestCount"]
          : int.tryParse("${json["requestCount"]}") ?? 0,
      ownerId: json["ownerId"]?.toString() ?? "",
      ownerName: json["ownerName"]?.toString() ?? "Kullanici",
      ownerAge: json["ownerAge"] is int
          ? json["ownerAge"]
          : int.tryParse("${json["ownerAge"]}"),
      ownerPhotoUrls: json["ownerPhotoUrls"] is List
          ? (json["ownerPhotoUrls"] as List)
                .map((item) => item.toString())
                .toList()
          : const [],
      isAnonymous: json["isAnonymous"] == true,
      location: GeoPoint(
        _doubleFrom(json["latitude"]),
        _doubleFrom(json["longitude"]),
      ),
      createdAt: _timestampFrom(json["createdAt"]),
    );
  }
}

class EncounterWithDistance {
  // Ilanin kendisini ve kullaniciya uzakligini beraber tasimak icin kucuk paket.
  final EncounterPost post;
  final double distanceMeters;

  EncounterWithDistance({required this.post, required this.distanceMeters});
}

double _doubleFrom(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? "") ?? 0;
}

Timestamp? _timestampFrom(dynamic value) {
  if (value == null) {
    return null;
  }

  final parsed = DateTime.tryParse(value.toString());
  return parsed == null ? null : Timestamp.fromDate(parsed.toLocal());
}
