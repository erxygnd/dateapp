namespace Fildir.Api.Contracts.Auth;

public sealed record AuthResponse(
    Guid UserId,
    string UserName,
    string Email,
    string AccessToken,
    DateTimeOffset AccessTokenExpiresAt,
    string RefreshToken,
    DateTimeOffset RefreshTokenExpiresAt);

public sealed record MeResponse(
    Guid UserId,
    string UserName,
    string Email,
    string? DisplayName,
    DateOnly? BirthDate,
    string? City);
