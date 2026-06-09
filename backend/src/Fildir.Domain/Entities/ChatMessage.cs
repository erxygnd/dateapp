using Fildir.Domain.Enums;

namespace Fildir.Domain.Entities;

public sealed class ChatMessage
{
    public Guid Id { get; set; }
    public Guid ChatId { get; set; }
    public Guid SenderId { get; set; }
    public ChatMessageType Type { get; set; } = ChatMessageType.Text;
    public required string Content { get; set; }
    public int? DurationSeconds { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? ReadAt { get; set; }
}
