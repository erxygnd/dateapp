using Fildir.Domain.Enums;

namespace Fildir.Domain.Entities;

public sealed class EncounterRequest
{
    public Guid Id { get; set; }
    public Guid EncounterPostId { get; set; }
    public Guid RequesterId { get; set; }
    public Guid PostOwnerId { get; set; }
    public Guid? ChatId { get; set; }
    public EncounterRequestStatus Status { get; set; } = EncounterRequestStatus.Pending;
    public string? Message { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? DecidedAt { get; set; }
}
