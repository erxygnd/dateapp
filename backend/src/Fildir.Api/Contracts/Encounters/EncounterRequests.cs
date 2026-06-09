namespace Fildir.Api.Contracts.Encounters;

public sealed record CreateEncounterRequest(
    string Place,
    string DateTimeText,
    string Description,
    string? Note,
    string? VehiclePlate,
    string? PersonAppearance,
    string? PersonTraits,
    bool IsAnonymous,
    double Latitude,
    double Longitude);
