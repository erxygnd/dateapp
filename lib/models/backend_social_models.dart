class BackendEncounterRequest {
  final String id;
  final String encounterPostId;
  final String requesterId;
  final String postOwnerId;
  final String? chatId;
  final String status;
  final String message;
  final String postPlace;
  final String postDescription;
  final String requesterName;
  final int? requesterAge;
  final String requesterBio;
  final List<String> requesterPhotoUrls;
  final String ownerName;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  const BackendEncounterRequest({
    required this.id,
    required this.encounterPostId,
    required this.requesterId,
    required this.postOwnerId,
    required this.chatId,
    required this.status,
    required this.message,
    required this.postPlace,
    required this.postDescription,
    required this.requesterName,
    required this.requesterAge,
    required this.requesterBio,
    required this.requesterPhotoUrls,
    required this.ownerName,
    required this.createdAt,
    required this.decidedAt,
  });

  bool get isPending => status.toLowerCase() == "pending";
  bool get isAccepted => status.toLowerCase() == "accepted";
  bool get isRejected => status.toLowerCase() == "rejected";

  factory BackendEncounterRequest.fromJson(Map<String, dynamic> json) {
    return BackendEncounterRequest(
      id: json["id"]?.toString() ?? "",
      encounterPostId: json["encounterPostId"]?.toString() ?? "",
      requesterId: json["requesterId"]?.toString() ?? "",
      postOwnerId: json["postOwnerId"]?.toString() ?? "",
      chatId: _nullableString(json["chatId"]),
      status: json["status"]?.toString() ?? "",
      message: json["message"]?.toString() ?? "",
      postPlace: json["postPlace"]?.toString() ?? "",
      postDescription: json["postDescription"]?.toString() ?? "",
      requesterName: json["requesterName"]?.toString() ?? "Kullanici",
      requesterAge: _nullableInt(json["requesterAge"]),
      requesterBio: json["requesterBio"]?.toString() ?? "",
      requesterPhotoUrls: _stringList(json["requesterPhotoUrls"]),
      ownerName: json["ownerName"]?.toString() ?? "Kullanici",
      createdAt: _nullableDate(json["createdAt"]),
      decidedAt: _nullableDate(json["decidedAt"]),
    );
  }
}

class BackendChatSummary {
  final String id;
  final String? encounterPostId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;
  final String lastMessage;
  final String? lastSenderId;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isActive;
  final DateTime? createdAt;

  const BackendChatSummary({
    required this.id,
    required this.encounterPostId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhotoUrl,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.isActive,
    required this.createdAt,
  });

  factory BackendChatSummary.fromJson(Map<String, dynamic> json) {
    return BackendChatSummary(
      id: json["id"]?.toString() ?? "",
      encounterPostId: _nullableString(json["encounterPostId"]),
      otherUserId: json["otherUserId"]?.toString() ?? "",
      otherUserName: json["otherUserName"]?.toString() ?? "Kullanici",
      otherUserPhotoUrl: _nullableString(json["otherUserPhotoUrl"]),
      lastMessage: json["lastMessage"]?.toString() ?? "Sohbet acildi.",
      lastSenderId: _nullableString(json["lastSenderId"]),
      lastMessageAt: _nullableDate(json["lastMessageAt"]),
      unreadCount: _nullableInt(json["unreadCount"]) ?? 0,
      isActive: json["isActive"] != false,
      createdAt: _nullableDate(json["createdAt"]),
    );
  }
}

class BackendChatDetail {
  final String id;
  final String? encounterPostId;
  final String otherUserId;
  final String otherUserName;
  final String lastMessage;
  final String? lastSenderId;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isActive;
  final DateTime? createdAt;

  const BackendChatDetail({
    required this.id,
    required this.encounterPostId,
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.isActive,
    required this.createdAt,
  });

  factory BackendChatDetail.fromJson(Map<String, dynamic> json) {
    return BackendChatDetail(
      id: json["id"]?.toString() ?? "",
      encounterPostId: _nullableString(json["encounterPostId"]),
      otherUserId: json["otherUserId"]?.toString() ?? "",
      otherUserName: json["otherUserName"]?.toString() ?? "Kullanici",
      lastMessage: json["lastMessage"]?.toString() ?? "Sohbet acildi.",
      lastSenderId: _nullableString(json["lastSenderId"]),
      lastMessageAt: _nullableDate(json["lastMessageAt"]),
      unreadCount: _nullableInt(json["unreadCount"]) ?? 0,
      isActive: json["isActive"] != false,
      createdAt: _nullableDate(json["createdAt"]),
    );
  }
}

class BackendChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final bool isMine;
  final String type;
  final String content;
  final int? durationSeconds;
  final DateTime? createdAt;
  final DateTime? readAt;

  const BackendChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.isMine,
    required this.type,
    required this.content,
    required this.durationSeconds,
    required this.createdAt,
    required this.readAt,
  });

  String get localType {
    switch (type.toLowerCase()) {
      case "photo":
        return "image";
      case "voice":
        return "voice";
      default:
        return "text";
    }
  }

  Map<String, dynamic> toBubbleData() {
    return {
      "senderId": senderId,
      "type": localType,
      if (localType == "image") "imageSource": content,
      if (localType == "voice") "audioSource": content,
      if (localType == "text") "text": content,
      "durationSeconds": durationSeconds,
      "createdAt": createdAt,
    };
  }

  factory BackendChatMessage.fromJson(Map<String, dynamic> json) {
    return BackendChatMessage(
      id: json["id"]?.toString() ?? "",
      chatId: json["chatId"]?.toString() ?? "",
      senderId: json["senderId"]?.toString() ?? "",
      isMine: json["isMine"] == true,
      type: json["type"]?.toString() ?? "Text",
      content: json["content"]?.toString() ?? "",
      durationSeconds: _nullableInt(json["durationSeconds"]),
      createdAt: _nullableDate(json["createdAt"]),
      readAt: _nullableDate(json["readAt"]),
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }

  return const [];
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _nullableInt(dynamic value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? "");
}

DateTime? _nullableDate(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString())?.toLocal();
}
