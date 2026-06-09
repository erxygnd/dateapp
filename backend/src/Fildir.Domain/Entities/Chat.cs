namespace Fildir.Domain.Entities;

public sealed class Chat
{
    public Guid Id { get; set; }
    public Guid? EncounterPostId { get; set; }
    public Guid ParticipantAId { get; set; }
    public Guid ParticipantBId { get; set; }
    public string? LastMessage { get; set; }
    public Guid? LastSenderId { get; set; }
    public DateTimeOffset? LastMessageAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public bool IsActive { get; set; } = true;
}
