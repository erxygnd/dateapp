namespace Fildir.Api.Contracts.Profiles;

public sealed record MyProfileResponse(
    Guid UserId,
    string UserName,
    string Email,
    string? DisplayName,
    int? Age,
    DateOnly? BirthDate,
    string? Gender,
    string Bio,
    string? PhoneNumber,
    string? City,
    IReadOnlyList<string> PhotoUrls,
    DateTimeOffset CreatedAt,
    DateTimeOffset? UpdatedAt);
