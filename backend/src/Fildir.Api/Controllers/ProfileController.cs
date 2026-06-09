using System.Security.Claims;
using Fildir.Api.Contracts.Profiles;
using Fildir.Domain.Entities;
using Fildir.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Fildir.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/profile")]
public sealed class ProfileController(FildirDbContext dbContext) : ControllerBase
{
    private const int MaxPhotoCount = 3;
    private const int MaxPhotoSourceLength = 750_000;

    [HttpGet("me")]
    public async Task<ActionResult<MyProfileResponse>> GetMe(
        CancellationToken cancellationToken)
    {
        var user = await GetCurrentUser(cancellationToken);

        return user is null ? Unauthorized() : Ok(ToProfileResponse(user));
    }

    [HttpPut("me")]
    public async Task<ActionResult<MyProfileResponse>> UpdateMe(
        UpdateMyProfileRequest request,
        CancellationToken cancellationToken)
    {
        var user = await GetCurrentUser(cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        var errors = ValidateUpdateRequest(request);

        if (errors.Count > 0)
        {
            return BadRequest(new ValidationProblemDetails(errors));
        }

        user.DisplayName = NormalizeOptional(request.DisplayName);
        user.BirthDate = request.BirthDate;
        user.Gender = NormalizeOptional(request.Gender);
        user.Bio = NormalizeOptional(request.Bio);
        user.PhoneNumber = NormalizeOptional(request.PhoneNumber);
        user.PhoneDigits = OnlyDigits(request.PhoneNumber);
        user.City = NormalizeOptional(request.City);
        user.PhotoUrls = request.PhotoUrls?
            .Select(photo => photo.Trim())
            .Where(photo => photo.Length > 0)
            .ToList() ?? [];
        user.UpdatedAt = DateTimeOffset.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);

        return Ok(ToProfileResponse(user));
    }

    private async Task<AppUser?> GetCurrentUser(CancellationToken cancellationToken)
    {
        var userIdValue = User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (!Guid.TryParse(userIdValue, out var userId))
        {
            return null;
        }

        return await dbContext.Users.FirstOrDefaultAsync(user =>
            user.Id == userId && !user.IsDeleted,
            cancellationToken);
    }

    private static MyProfileResponse ToProfileResponse(AppUser user)
    {
        return new MyProfileResponse(
            user.Id,
            user.UserName,
            user.Email,
            user.DisplayName,
            CalculateAge(user.BirthDate),
            user.BirthDate,
            user.Gender,
            user.Bio ?? string.Empty,
            user.PhoneNumber,
            user.City,
            user.PhotoUrls,
            user.CreatedAt,
            user.UpdatedAt);
    }

    private static Dictionary<string, string[]> ValidateUpdateRequest(
        UpdateMyProfileRequest request)
    {
        var errors = new Dictionary<string, string[]>();

        if (NormalizeOptional(request.DisplayName) is not { Length: >= 2 and <= 80 })
        {
            errors[nameof(request.DisplayName)] =
            [
                "Görünen ad 2-80 karakter arasında olmalı."
            ];
        }

        if (request.BirthDate is null)
        {
            errors[nameof(request.BirthDate)] = ["Doğum tarihi zorunlu."];
        }
        else if (CalculateAge(request.BirthDate) is < 18)
        {
            errors[nameof(request.BirthDate)] =
            [
                "Devam etmek için 18 yaşından büyük olmalısın."
            ];
        }

        if (NormalizeOptional(request.Gender) is not { Length: >= 2 and <= 40 })
        {
            errors[nameof(request.Gender)] = ["Cinsiyet alanı 2-40 karakter olmalı."];
        }

        if (NormalizeOptional(request.Bio) is { Length: > 800 })
        {
            errors[nameof(request.Bio)] = ["Bio en fazla 800 karakter olabilir."];
        }

        if (NormalizeOptional(request.PhoneNumber) is { } phoneNumber &&
            OnlyDigits(phoneNumber) is { Length: > 0 and < 10 or > 15 })
        {
            errors[nameof(request.PhoneNumber)] =
            [
                "Telefon numarası 10-15 rakam arasında olmalı."
            ];
        }

        if (NormalizeOptional(request.City) is { Length: > 80 })
        {
            errors[nameof(request.City)] = ["Şehir en fazla 80 karakter olabilir."];
        }

        var photos = request.PhotoUrls?
            .Select(photo => photo.Trim())
            .Where(photo => photo.Length > 0)
            .ToList() ?? [];

        if (photos.Count is < 1 or > MaxPhotoCount)
        {
            errors[nameof(request.PhotoUrls)] =
            [
                $"Profilde 1-{MaxPhotoCount} fotoğraf olmalı."
            ];
        }
        else if (photos.Any(photo => photo.Length > MaxPhotoSourceLength))
        {
            errors[nameof(request.PhotoUrls)] =
            [
                "Fotoğraf verisi çok büyük."
            ];
        }

        return errors;
    }

    private static int? CalculateAge(DateOnly? birthDate)
    {
        if (birthDate is null)
        {
            return null;
        }

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var age = today.Year - birthDate.Value.Year;

        if (today.Month < birthDate.Value.Month ||
            today.Month == birthDate.Value.Month && today.Day < birthDate.Value.Day)
        {
            age--;
        }

        return age;
    }

    private static string? NormalizeOptional(string? value)
    {
        var normalized = value?.Trim();
        return string.IsNullOrWhiteSpace(normalized) ? null : normalized;
    }

    private static string? OnlyDigits(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var digits = new string(value.Where(char.IsDigit).ToArray());
        return digits.Length == 0 ? null : digits;
    }
}
