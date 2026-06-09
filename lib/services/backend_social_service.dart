import '../models/backend_social_models.dart';
import '../models/encounter_post.dart';
import 'backend_api_client.dart';
import 'backend_auth_controller.dart';

final BackendSocialService backendSocialService = BackendSocialService(
  apiClient: backendAuthController.apiClient,
);

class BackendSocialService {
  final BackendApiClient apiClient;

  const BackendSocialService({required this.apiClient});

  Future<EncounterPost> createEncounter({
    required String place,
    required String dateTimeText,
    required String description,
    required String note,
    required String vehiclePlate,
    required String personAppearance,
    required String personTraits,
    required bool isAnonymous,
    required double latitude,
    required double longitude,
  }) async {
    final token = await backendAuthController.accessToken();
    final json = await apiClient.postMap("/api/encounters", {
      "place": place,
      "dateTimeText": dateTimeText,
      "description": description,
      "note": note,
      "vehiclePlate": vehiclePlate,
      "personAppearance": personAppearance,
      "personTraits": personTraits,
      "isAnonymous": isAnonymous,
      "latitude": latitude,
      "longitude": longitude,
    }, accessToken: token);

    return EncounterPost.fromBackend(json);
  }

  Future<List<EncounterWithDistance>> nearbyEncounters({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required int limit,
  }) async {
    final token = await backendAuthController.accessToken();
    final json = await apiClient.getMap(
      "/api/encounters",
      accessToken: token,
      query: {
        "latitude": latitude.toString(),
        "longitude": longitude.toString(),
        "radiusKm": radiusKm.toString(),
        "limit": limit.toString(),
      },
    );
    final rawItems = json["items"];

    if (rawItems is! List) {
      return const [];
    }

    return rawItems.whereType<Map<String, dynamic>>().map((item) {
      final post = EncounterPost.fromBackend(item);
      final distanceKm = _nullableDouble(item["distanceKm"]);
      return EncounterWithDistance(
        post: post,
        distanceMeters: (distanceKm ?? 0) * 1000,
      );
    }).toList();
  }

  Future<List<EncounterPost>> myEncounters({int limit = 80}) async {
    final token = await backendAuthController.accessToken();
    final json = await apiClient.getList(
      "/api/encounters/mine",
      accessToken: token,
      query: {"limit": limit.toString()},
    );

    return json
        .whereType<Map<String, dynamic>>()
        .map(EncounterPost.fromBackend)
        .toList();
  }

  Future<void> deleteEncounter(String id) async {
    final token = await backendAuthController.accessToken();
    await apiClient.delete("/api/encounters/$id", accessToken: token);
  }

  Future<BackendEncounterRequest> sendEncounterRequest({
    required String encounterId,
    String? message,
  }) async {
    final token = await backendAuthController.accessToken();
    final json = await apiClient.postMap(
      "/api/encounters/$encounterId/requests",
      {"message": message},
      accessToken: token,
    );

    return BackendEncounterRequest.fromJson(json);
  }

  Future<List<BackendEncounterRequest>> incomingRequests({
    String? status = "Pending",
    int limit = 60,
  }) async {
    final token = await backendAuthController.accessToken();
    final query = <String, String>{"limit": limit.toString()};

    if (status != null) {
      query["status"] = status;
    }

    final json = await apiClient.getList(
      "/api/encounter-requests/incoming",
      accessToken: token,
      query: query,
    );

    return json
        .whereType<Map<String, dynamic>>()
        .map(BackendEncounterRequest.fromJson)
        .toList();
  }

  Future<List<BackendEncounterRequest>> outgoingRequests({
    String? status,
    int limit = 60,
  }) async {
    final token = await backendAuthController.accessToken();
    final query = <String, String>{"limit": limit.toString()};

    if (status != null) {
      query["status"] = status;
    }

    final json = await apiClient.getList(
      "/api/encounter-requests/outgoing",
      accessToken: token,
      query: query,
    );

    return json
        .whereType<Map<String, dynamic>>()
        .map(BackendEncounterRequest.fromJson)
        .toList();
  }

  Future<BackendEncounterRequest> acceptRequest(String id) async {
    return _decideRequest(id, accepted: true);
  }

  Future<BackendEncounterRequest> rejectRequest(String id) async {
    return _decideRequest(id, accepted: false);
  }

  Future<BackendEncounterRequest> _decideRequest(
    String id, {
    required bool accepted,
  }) async {
    final token = await backendAuthController.accessToken();
    final action = accepted ? "accept" : "reject";
    final json = await apiClient.postMap(
      "/api/encounter-requests/$id/$action",
      const {},
      accessToken: token,
    );

    return BackendEncounterRequest.fromJson(json);
  }

  Future<List<BackendChatSummary>> chats({int limit = 50}) async {
    final token = await backendAuthController.accessToken();
    final json = await apiClient.getList(
      "/api/chats",
      accessToken: token,
      query: {"limit": limit.toString()},
    );

    return json
        .whereType<Map<String, dynamic>>()
        .map(BackendChatSummary.fromJson)
        .toList();
  }

  Future<BackendChatDetail> chatDetail(String chatId) async {
    final token = await backendAuthController.accessToken();
    final json = await apiClient.getMap(
      "/api/chats/$chatId",
      accessToken: token,
    );

    return BackendChatDetail.fromJson(json);
  }

  Future<List<BackendChatMessage>> chatMessages(
    String chatId, {
    int limit = 80,
  }) async {
    final token = await backendAuthController.accessToken();
    final json = await apiClient.getMap(
      "/api/chats/$chatId/messages",
      accessToken: token,
      query: {"limit": limit.toString()},
    );
    final rawItems = json["items"];

    if (rawItems is! List) {
      return const [];
    }

    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(BackendChatMessage.fromJson)
        .toList();
  }

  Future<BackendChatMessage> sendChatMessage({
    required String chatId,
    required String type,
    required String content,
    int? durationSeconds,
  }) async {
    final token = await backendAuthController.accessToken();
    final json = await apiClient.postMap("/api/chats/$chatId/messages", {
      "type": type,
      "content": content,
      "durationSeconds": durationSeconds,
    }, accessToken: token);

    return BackendChatMessage.fromJson(json);
  }

  Future<void> markChatRead(String chatId) async {
    final token = await backendAuthController.accessToken();
    await apiClient.postMap(
      "/api/chats/$chatId/read",
      const {},
      accessToken: token,
    );
  }
}

double? _nullableDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? "");
}
