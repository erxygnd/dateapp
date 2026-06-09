using System.Security.Claims;
using Fildir.Api.Contracts.Encounters;
using Fildir.Domain.Constants;
using Fildir.Domain.Entities;
using Fildir.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Fildir.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/encounters")]
public sealed class EncountersController(FildirDbContext dbContext) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<EncounterResponse>> Create(
        CreateEncounterRequest request,
        CancellationToken cancellationToken)
    {
        var user = await GetCurrentUser(cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        var errors = ValidateCreateRequest(request);

        if (errors.Count > 0)
        {
            return BadRequest(new ValidationProblemDetails(errors));
        }

        if (!LocationPolicy.IsLocationInAnkara(request.Latitude, request.Longitude))
        {
            return BadRequest(new
            {
                message = "Pilot bölge şimdilik Ankara. Ankara dışından itiraf bırakılamıyor."
            });
        }

        var now = DateTimeOffset.UtcNow;
        var encounter = new EncounterPost
        {
            Id = Guid.NewGuid(),
            OwnerId = user.Id,
            Place = request.Place.Trim(),
            DateTimeText = request.DateTimeText.Trim(),
            Description = request.Description.Trim(),
            Note = NormalizeOptional(request.Note),
            VehiclePlate = NormalizeOptional(request.VehiclePlate),
            PersonAppearance = NormalizeOptional(request.PersonAppearance),
            PersonTraits = NormalizeOptional(request.PersonTraits),
            IsAnonymous = request.IsAnonymous,
            Latitude = Convert.ToDecimal(request.Latitude),
            Longitude = Convert.ToDecimal(request.Longitude),
            RequestCount = 0,
            CreatedAt = now
        };

        dbContext.EncounterPosts.Add(encounter);
        await dbContext.SaveChangesAsync(cancellationToken);

        var response = ToEncounterResponse(
            encounter,
            user,
            currentUserId: user.Id,
            distanceKm: null);

        return CreatedAtAction(nameof(GetById), new { id = encounter.Id }, response);
    }

    [HttpGet]
    public async Task<ActionResult<EncounterFeedResponse>> GetNearby(
        [FromQuery] double latitude,
        [FromQuery] double longitude,
        [FromQuery] double radiusKm = LocationPolicy.DefaultRadiusKm,
        [FromQuery] int limit = LocationPolicy.DefaultFeedLimit,
        CancellationToken cancellationToken = default)
    {
        var user = await GetCurrentUser(cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        var errors = ValidateFeedRequest(latitude, longitude, radiusKm, limit);

        if (errors.Count > 0)
        {
            return BadRequest(new ValidationProblemDetails(errors));
        }

        if (!LocationPolicy.IsLocationInAnkara(latitude, longitude))
        {
            return BadRequest(new
            {
                message = "Pilot bölge şimdilik Ankara. Ankara dışındaki ilan akışı kapalı."
            });
        }

        var effectiveRadiusKm = LocationPolicy.EffectiveRadiusKm(
            radiusKm,
            latitude,
            longitude);
        var safeLimit = Math.Clamp(limit, 1, LocationPolicy.MaxFeedLimit);

        var candidates = await dbContext.EncounterPosts
            .AsNoTracking()
            .Where(post => post.DeletedAt == null)
            .OrderByDescending(post => post.CreatedAt)
            .Take(Math.Max(safeLimit * 5, safeLimit))
            .ToListAsync(cancellationToken);

        var ownerIds = candidates
            .Select(post => post.OwnerId)
            .Distinct()
            .ToArray();

        var owners = await dbContext.Users
            .AsNoTracking()
            .Where(candidate => ownerIds.Contains(candidate.Id))
            .ToDictionaryAsync(candidate => candidate.Id, cancellationToken);

        var items = candidates
            .Select(post =>
            {
                var distanceKm = LocationPolicy.DistanceKmBetween(
                    latitude,
                    longitude,
                    Convert.ToDouble(post.Latitude),
                    Convert.ToDouble(post.Longitude));

                return new
                {
                    Post = post,
                    DistanceKm = distanceKm
                };
            })
            .Where(item => item.DistanceKm <= effectiveRadiusKm)
            .OrderBy(item => item.DistanceKm)
            .ThenByDescending(item => item.Post.CreatedAt)
            .Take(safeLimit)
            .Select(item => ToEncounterResponse(
                item.Post,
                owners.GetValueOrDefault(item.Post.OwnerId),
                user.Id,
                item.DistanceKm))
            .ToList();

        return Ok(new EncounterFeedResponse(
            radiusKm,
            effectiveRadiusKm,
            items.Count,
            items));
    }

    [HttpGet("mine")]
    public async Task<ActionResult<IReadOnlyList<EncounterResponse>>> GetMine(
        [FromQuery] int limit = LocationPolicy.DefaultFeedLimit,
        CancellationToken cancellationToken = default)
    {
        var user = await GetCurrentUser(cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        var safeLimit = Math.Clamp(limit, 1, LocationPolicy.MaxFeedLimit);

        var posts = await dbContext.EncounterPosts
            .AsNoTracking()
            .Where(post => post.OwnerId == user.Id && post.DeletedAt == null)
            .OrderByDescending(post => post.CreatedAt)
            .Take(safeLimit)
            .ToListAsync(cancellationToken);

        var response = posts
            .Select(post => ToEncounterResponse(post, user, user.Id, distanceKm: null))
            .ToList();

        return Ok(response);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<EncounterResponse>> GetById(
        Guid id,
        [FromQuery] double? latitude,
        [FromQuery] double? longitude,
        CancellationToken cancellationToken)
    {
        var user = await GetCurrentUser(cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        var post = await dbContext.EncounterPosts
            .AsNoTracking()
            .FirstOrDefaultAsync(candidate =>
                candidate.Id == id && candidate.DeletedAt == null,
                cancellationToken);

        if (post is null)
        {
            return NotFound(new { message = "İtiraf bulunamadı." });
        }

        var owner = await dbContext.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(candidate => candidate.Id == post.OwnerId, cancellationToken);

        double? distanceKm = null;

        if (latitude is not null && longitude is not null)
        {
            distanceKm = LocationPolicy.DistanceKmBetween(
                latitude.Value,
                longitude.Value,
                Convert.ToDouble(post.Latitude),
                Convert.ToDouble(post.Longitude));
        }

        return Ok(ToEncounterResponse(post, owner, user.Id, distanceKm));
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> DeleteMine(
        Guid id,
        CancellationToken cancellationToken)
    {
        var user = await GetCurrentUser(cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        var post = await dbContext.EncounterPosts.FirstOrDefaultAsync(candidate =>
            candidate.Id == id && candidate.DeletedAt == null,
            cancellationToken);

        if (post is null)
        {
            return NotFound(new { message = "İtiraf bulunamadı." });
        }

        if (post.OwnerId != user.Id)
        {
            return Forbid();
        }

        post.DeletedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        return NoContent();
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

    private static EncounterResponse ToEncounterResponse(
        EncounterPost post,
        AppUser? owner,
        Guid currentUserId,
        double? distanceKm)
    {
        var ownerAge = post.IsAnonymous ? null : CalculateAge(owner?.BirthDate);
        var ownerPhotoUrls = post.IsAnonymous ? [] : owner?.PhotoUrls ?? [];
        var ownerName = post.IsAnonymous
            ? "Anonim"
            : NormalizeOptional(owner?.DisplayName) ?? owner?.UserName ?? "Kullanıcı";

        return new EncounterResponse(
            post.Id,
            post.Place,
            post.DateTimeText,
            post.Description,
            post.Note ?? string.Empty,
            post.VehiclePlate ?? string.Empty,
            post.PersonAppearance ?? string.Empty,
            post.PersonTraits ?? string.Empty,
            post.RequestCount,
            post.OwnerId,
            ownerName,
            ownerAge,
            ownerPhotoUrls,
            post.IsAnonymous,
            post.OwnerId == currentUserId,
            Convert.ToDouble(post.Latitude),
            Convert.ToDouble(post.Longitude),
            distanceKm is null ? null : Math.Round(distanceKm.Value, 3),
            post.CreatedAt);
    }

    private static Dictionary<string, string[]> ValidateCreateRequest(
        CreateEncounterRequest request)
    {
        var errors = new Dictionary<string, string[]>();

        AddLengthErrorIfInvalid(errors, nameof(request.Place), request.Place, 2, 160);
        AddLengthErrorIfInvalid(errors, nameof(request.DateTimeText), request.DateTimeText, 2, 120);
        AddLengthErrorIfInvalid(errors, nameof(request.Description), request.Description, 8, 1200);
        AddMaxLengthErrorIfInvalid(errors, nameof(request.Note), request.Note, 800);
        AddMaxLengthErrorIfInvalid(errors, nameof(request.VehiclePlate), request.VehiclePlate, 20);
        AddMaxLengthErrorIfInvalid(
            errors,
            nameof(request.PersonAppearance),
            request.PersonAppearance,
            60);
        AddMaxLengthErrorIfInvalid(errors, nameof(request.PersonTraits), request.PersonTraits, 300);

        if (!IsValidLatitude(request.Latitude))
        {
            errors[nameof(request.Latitude)] = ["Geçerli bir enlem gönder."];
        }

        if (!IsValidLongitude(request.Longitude))
        {
            errors[nameof(request.Longitude)] = ["Geçerli bir boylam gönder."];
        }

        return errors;
    }

    private static Dictionary<string, string[]> ValidateFeedRequest(
        double latitude,
        double longitude,
        double radiusKm,
        int limit)
    {
        var errors = new Dictionary<string, string[]>();

        if (!IsValidLatitude(latitude))
        {
            errors[nameof(latitude)] = ["Geçerli bir enlem gönder."];
        }

        if (!IsValidLongitude(longitude))
        {
            errors[nameof(longitude)] = ["Geçerli bir boylam gönder."];
        }

        if (double.IsNaN(radiusKm) ||
            radiusKm <= 0 ||
            radiusKm > LocationPolicy.AnkaraMaxVisibleRadiusKm)
        {
            errors[nameof(radiusKm)] =
            [
                $"Yarıçap 0-{LocationPolicy.AnkaraMaxVisibleRadiusKm} km arasında olmalı."
            ];
        }

        if (limit is < 1 or > LocationPolicy.MaxFeedLimit)
        {
            errors[nameof(limit)] =
            [
                $"Limit 1-{LocationPolicy.MaxFeedLimit} arasında olmalı."
            ];
        }

        return errors;
    }

    private static void AddLengthErrorIfInvalid(
        Dictionary<string, string[]> errors,
        string field,
        string? value,
        int minLength,
        int maxLength)
    {
        var normalized = NormalizeOptional(value);

        if (normalized is null || normalized.Length < minLength || normalized.Length > maxLength)
        {
            errors[field] =
            [
                $"{field} {minLength}-{maxLength} karakter arasında olmalı."
            ];
        }
    }

    private static void AddMaxLengthErrorIfInvalid(
        Dictionary<string, string[]> errors,
        string field,
        string? value,
        int maxLength)
    {
        var normalized = NormalizeOptional(value);

        if (normalized is { Length: > 0 } && normalized.Length > maxLength)
        {
            errors[field] = [$"{field} en fazla {maxLength} karakter olabilir."];
        }
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

    private static bool IsValidLatitude(double latitude)
    {
        return !double.IsNaN(latitude) && latitude is >= -90 and <= 90;
    }

    private static bool IsValidLongitude(double longitude)
    {
        return !double.IsNaN(longitude) && longitude is >= -180 and <= 180;
    }

    private static string? NormalizeOptional(string? value)
    {
        var normalized = value?.Trim();
        return string.IsNullOrWhiteSpace(normalized) ? null : normalized;
    }
}
