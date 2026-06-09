namespace Fildir.Api.Contracts.Encounters;

public sealed record EncounterResponse(
    Guid Id,
    string Place,
    string DateTimeText,
    string Description,
    string Note,
    string VehiclePlate,
    string PersonAppearance,
    string PersonTraits,
    int RequestCount,
    Guid OwnerId,
    string OwnerName,
    int? OwnerAge,
    IReadOnlyList<string> OwnerPhotoUrls,
    bool IsAnonymous,
    bool IsMine,
    double Latitude,
    double Longitude,
    double? DistanceKm,
    DateTimeOffset CreatedAt);

public sealed record EncounterFeedResponse(
    double RequestedRadiusKm,
    double EffectiveRadiusKm,
    int Count,
    IReadOnlyList<EncounterResponse> Items);
