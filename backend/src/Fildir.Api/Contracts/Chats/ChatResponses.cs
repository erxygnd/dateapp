using Fildir.Domain.Enums;

namespace Fildir.Api.Contracts.Chats;

public sealed record ChatSummaryResponse(
    Guid Id,
    Guid? EncounterPostId,
    Guid OtherUserId,
    string OtherUserName,
    string? OtherUserPhotoUrl,
    string LastMessage,
    Guid? LastSenderId,
    DateTimeOffset? LastMessageAt,
    int UnreadCount,
    bool IsActive,
    DateTimeOffset CreatedAt);

public sealed record ChatDetailResponse(
    Guid Id,
    Guid? EncounterPostId,
    Guid ParticipantAId,
    Guid ParticipantBId,
    Guid OtherUserId,
    string OtherUserName,
    string LastMessage,
    Guid? LastSenderId,
    DateTimeOffset? LastMessageAt,
    int UnreadCount,
    bool IsActive,
    DateTimeOffset CreatedAt);

public sealed record ChatMessageResponse(
    Guid Id,
    Guid ChatId,
    Guid SenderId,
    bool IsMine,
    ChatMessageType Type,
    string Content,
    int? DurationSeconds,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ReadAt);

public sealed record ChatMessagesPageResponse(
    int Count,
    IReadOnlyList<ChatMessageResponse> Items);

public sealed record MarkChatReadResponse(
    Guid ChatId,
    int MarkedCount,
    DateTimeOffset ReadAt);
