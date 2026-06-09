using Fildir.Domain.Enums;

namespace Fildir.Api.Contracts.Chats;

public sealed record SendChatMessageRequest(
    ChatMessageType Type,
    string Content,
    int? DurationSeconds);
