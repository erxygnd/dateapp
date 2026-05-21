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
}

class EncounterWithDistance {
  // Ilanin kendisini ve kullaniciya uzakligini beraber tasimak icin kucuk paket.
  final EncounterPost post;
  final double distanceMeters;

  EncounterWithDistance({required this.post, required this.distanceMeters});
}
