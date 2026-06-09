using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using System.Text.RegularExpressions;
using Fildir.Api.Auth;
using Fildir.Api.Contracts.Auth;
using Fildir.Domain.Entities;
using Fildir.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Fildir.Api.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController(
    FildirDbContext dbContext,
    IPasswordHasher<AppUser> passwordHasher,
    IAuthTokenService tokenService) : ControllerBase
{
    private static readonly Regex UserNameRegex = new(
        "^[a-zA-Z0-9_.]{3,30}$",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register(
        RegisterRequest request,
        CancellationToken cancellationToken)
    {
        var userName = (request.UserName ?? string.Empty).Trim().ToLowerInvariant();
        var email = (request.Email ?? string.Empty).Trim().ToLowerInvariant();
        var password = request.Password ?? string.Empty;
        var errors = ValidateRegisterRequest(userName, email, password, request);

        if (errors.Count > 0)
        {
            return BadRequest(new ValidationProblemDetails(errors));
        }

        var normalizedUserName = Normalize(userName);
        var normalizedEmail = Normalize(email);

        var exists = await dbContext.Users.AnyAsync(user =>
            user.NormalizedUserName == normalizedUserName ||
            user.NormalizedEmail == normalizedEmail,
            cancellationToken);

        if (exists)
        {
            return Conflict(new
            {
                message = "Bu kullanıcı adı veya e-posta zaten kullanılıyor."
            });
        }

        var now = DateTimeOffset.UtcNow;
        var user = new AppUser
        {
            Id = Guid.NewGuid(),
            UserName = userName,
            NormalizedUserName = normalizedUserName,
            Email = email,
            NormalizedEmail = normalizedEmail,
            PasswordHash = string.Empty,
            DisplayName = NormalizeOptional(request.DisplayName),
            BirthDate = request.BirthDate,
            City = NormalizeOptional(request.City),
            CreatedAt = now
        };

        user.PasswordHash = passwordHasher.HashPassword(user, password);
        var tokens = tokenService.CreateTokenPair(user);

        dbContext.Users.Add(user);
        dbContext.RefreshTokens.Add(CreateRefreshToken(user.Id, tokens, now));
        await dbContext.SaveChangesAsync(cancellationToken);

        return Ok(ToAuthResponse(user, tokens));
    }

    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(
        LoginRequest request,
        CancellationToken cancellationToken)
    {
        var login = (request.Login ?? string.Empty).Trim();
        var password = request.Password ?? string.Empty;

        if (string.IsNullOrWhiteSpace(login) || string.IsNullOrWhiteSpace(password))
        {
            return Unauthorized(new { message = "Giriş bilgileri hatalı." });
        }

        var normalizedLogin = Normalize(login);
        var user = await dbContext.Users.FirstOrDefaultAsync(candidate =>
            !candidate.IsDeleted &&
            (candidate.NormalizedEmail == normalizedLogin ||
             candidate.NormalizedUserName == normalizedLogin),
            cancellationToken);

        if (user is null)
        {
            return Unauthorized(new { message = "Giriş bilgileri hatalı." });
        }

        var passwordResult = passwordHasher.VerifyHashedPassword(
            user,
            user.PasswordHash,
            password);

        if (passwordResult == PasswordVerificationResult.Failed)
        {
            return Unauthorized(new { message = "Giriş bilgileri hatalı." });
        }

        if (passwordResult == PasswordVerificationResult.SuccessRehashNeeded)
        {
            user.PasswordHash = passwordHasher.HashPassword(user, password);
            user.UpdatedAt = DateTimeOffset.UtcNow;
        }

        var now = DateTimeOffset.UtcNow;
        var tokens = tokenService.CreateTokenPair(user);
        dbContext.RefreshTokens.Add(CreateRefreshToken(user.Id, tokens, now));
        await dbContext.SaveChangesAsync(cancellationToken);

        return Ok(ToAuthResponse(user, tokens));
    }

    [HttpPost("refresh")]
    public async Task<ActionResult<AuthResponse>> Refresh(
        RefreshTokenRequest request,
        CancellationToken cancellationToken)
    {
        var refreshToken = request.RefreshToken ?? string.Empty;

        if (string.IsNullOrWhiteSpace(refreshToken))
        {
            return Unauthorized(new { message = "Refresh token geçersiz." });
        }

        var now = DateTimeOffset.UtcNow;
        var tokenHash = tokenService.HashRefreshToken(refreshToken);
        var storedToken = await dbContext.RefreshTokens.FirstOrDefaultAsync(token =>
            token.TokenHash == tokenHash,
            cancellationToken);

        if (storedToken is null ||
            storedToken.RevokedAt is not null ||
            storedToken.ExpiresAt <= now)
        {
            return Unauthorized(new { message = "Refresh token geçersiz." });
        }

        var user = await dbContext.Users.FirstOrDefaultAsync(candidate =>
            candidate.Id == storedToken.UserId && !candidate.IsDeleted,
            cancellationToken);

        if (user is null)
        {
            return Unauthorized(new { message = "Refresh token geçersiz." });
        }

        var tokens = tokenService.CreateTokenPair(user);
        storedToken.RevokedAt = now;
        storedToken.RevokedByIp = GetRemoteIp();
        storedToken.ReplacedByTokenHash = tokens.RefreshTokenHash;

        dbContext.RefreshTokens.Add(CreateRefreshToken(user.Id, tokens, now));
        await dbContext.SaveChangesAsync(cancellationToken);

        return Ok(ToAuthResponse(user, tokens));
    }

    [HttpPost("logout")]
    public async Task<IActionResult> Logout(
        LogoutRequest request,
        CancellationToken cancellationToken)
    {
        var refreshToken = request.RefreshToken ?? string.Empty;

        if (!string.IsNullOrWhiteSpace(refreshToken))
        {
            var tokenHash = tokenService.HashRefreshToken(refreshToken);
            var storedToken = await dbContext.RefreshTokens.FirstOrDefaultAsync(token =>
                token.TokenHash == tokenHash,
                cancellationToken);

            if (storedToken is not null && storedToken.RevokedAt is null)
            {
                storedToken.RevokedAt = DateTimeOffset.UtcNow;
                storedToken.RevokedByIp = GetRemoteIp();
                await dbContext.SaveChangesAsync(cancellationToken);
            }
        }

        return NoContent();
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<ActionResult<MeResponse>> Me(CancellationToken cancellationToken)
    {
        var userIdValue = User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (!Guid.TryParse(userIdValue, out var userId))
        {
            return Unauthorized();
        }

        var user = await dbContext.Users.FirstOrDefaultAsync(candidate =>
            candidate.Id == userId && !candidate.IsDeleted,
            cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        return Ok(new MeResponse(
            user.Id,
            user.UserName,
            user.Email,
            user.DisplayName,
            user.BirthDate,
            user.City));
    }

    private RefreshToken CreateRefreshToken(Guid userId, TokenPair tokens, DateTimeOffset now)
    {
        return new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TokenHash = tokens.RefreshTokenHash,
            CreatedByIp = GetRemoteIp(),
            ExpiresAt = tokens.RefreshTokenExpiresAt,
            CreatedAt = now
        };
    }

    private static AuthResponse ToAuthResponse(AppUser user, TokenPair tokens)
    {
        return new AuthResponse(
            user.Id,
            user.UserName,
            user.Email,
            tokens.AccessToken,
            tokens.AccessTokenExpiresAt,
            tokens.RefreshToken,
            tokens.RefreshTokenExpiresAt);
    }

    private static Dictionary<string, string[]> ValidateRegisterRequest(
        string userName,
        string email,
        string password,
        RegisterRequest request)
    {
        var errors = new Dictionary<string, string[]>();

        if (!UserNameRegex.IsMatch(userName))
        {
            errors[nameof(request.UserName)] =
            [
                "Kullanıcı adı 3-30 karakter olmalı; harf, rakam, nokta veya alt çizgi içerebilir."
            ];
        }

        if (!new EmailAddressAttribute().IsValid(email))
        {
            errors[nameof(request.Email)] = ["Geçerli bir e-posta gir."];
        }

        if (password.Length < 8 ||
            !password.Any(char.IsLetter) ||
            !password.Any(char.IsDigit))
        {
            errors[nameof(request.Password)] =
            [
                "Şifre en az 8 karakter olmalı ve harf ile rakam içermeli."
            ];
        }

        if (NormalizeOptional(request.DisplayName) is { Length: > 80 })
        {
            errors[nameof(request.DisplayName)] = ["Görünen ad en fazla 80 karakter olabilir."];
        }

        if (NormalizeOptional(request.City) is { Length: > 80 })
        {
            errors[nameof(request.City)] = ["Şehir en fazla 80 karakter olabilir."];
        }

        return errors;
    }

    private static string Normalize(string value)
    {
        return value.Trim().ToUpperInvariant();
    }

    private static string? NormalizeOptional(string? value)
    {
        var normalized = value?.Trim();
        return string.IsNullOrWhiteSpace(normalized) ? null : normalized;
    }

    private string? GetRemoteIp()
    {
        return HttpContext.Connection.RemoteIpAddress?.ToString();
    }
}
