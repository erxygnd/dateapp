namespace Fildir.Api.Contracts.Auth;

public sealed record RegisterRequest(
    string UserName,
    string Email,
    string Password,
    string? DisplayName,
    DateOnly? BirthDate,
    string? City);

public sealed record LoginRequest(
    string Login,
    string Password);

public sealed record RefreshTokenRequest(
    string RefreshToken);

public sealed record LogoutRequest(
    string RefreshToken);
