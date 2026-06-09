namespace Fildir.Domain.Entities;

public sealed class EncounterPost
{
    public Guid Id { get; set; }
    public Guid OwnerId { get; set; }
    public required string Place { get; set; }
    public required string DateTimeText { get; set; }
    public required string Description { get; set; }
    public string? Note { get; set; }
    public string? VehiclePlate { get; set; }
    public string? PersonAppearance { get; set; }
    public string? PersonTraits { get; set; }
    public bool IsAnonymous { get; set; }
    public decimal Latitude { get; set; }
    public decimal Longitude { get; set; }
    public int RequestCount { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
}
