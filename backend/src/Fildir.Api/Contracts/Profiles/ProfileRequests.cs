namespace Fildir.Api.Contracts.Profiles;

public sealed record UpdateMyProfileRequest(
    string? DisplayName,
    DateOnly? BirthDate,
    string? Gender,
    string? Bio,
    string? PhoneNumber,
    string? City,
    IReadOnlyList<string>? PhotoUrls);
