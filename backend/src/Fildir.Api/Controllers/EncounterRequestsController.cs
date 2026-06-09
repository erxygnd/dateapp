using System.Security.Claims;
using Fildir.Api.Contracts.Requests;
using Fildir.Domain.Entities;
using Fildir.Domain.Enums;
using Fildir.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Fildir.Api.Controllers;

[Authorize]
[ApiController]
[Route("api")]
public sealed class EncounterRequestsController(FildirDbContext dbContext) : ControllerBase
{
    private const int DefaultRequestLimit = 50;
    private const int MaxRequestLimit = 100;

    [HttpPost("encounters/{encounterId:guid}/requests")]
    public async Task<ActionResult<EncounterRequestResponse>> Send(
        Guid encounterId,
        SendEncounterRequestRequest request,
        CancellationToken cancellationToken)
    {
        var user = await GetCurrentUser(cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        var message = NormalizeOptional(request.Message);

        if (message is { Length: > 800 })
        {
            return BadRequest(new ValidationProblemDetails(new Dictionary<string, string[]>
            {
                [nameof(request.Message)] = ["Mesaj en fazla 800 karakter olabilir."]
            }));
        }

        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);

        var post = await dbContext.EncounterPosts.FirstOrDefaultAsync(candidate =>
            candidate.Id == encounterId && candidate.DeletedAt == null,
            cancellationToken);

        if (post is null)
        {
            return NotFound(new { message = "İtiraf bulunamadı." });
        }

        if (post.OwnerId == user.Id)
        {
            return BadRequest(new { message = "Kendi ilanına istek gönderemezsin." });
        }

        var existingRequest = await dbContext.EncounterRequests.FirstOrDefaultAsync(candidate =>
            candidate.EncounterPostId == encounterId &&
            candidate.RequesterId == user.Id,
            cancellationToken);

        if (existingRequest is null)
        {
            existingRequest = new EncounterRequest
            {
                Id = Guid.NewGuid(),
                EncounterPostId = post.Id,
                RequesterId = user.Id,
                PostOwnerId = post.OwnerId,
                Message = message,
                Status = EncounterRequestStatus.Pending,
                CreatedAt = DateTimeOffset.UtcNow
            };

            post.RequestCount++;
            dbContext.EncounterRequests.Add(existingRequest);
        }
        else if (existingRequest.Status is EncounterRequestStatus.Pending or EncounterRequestStatus.Accepted)
        {
            await transaction.RollbackAsync(cancellationToken);
            return Ok(await ToResponse(existingRequest, cancellationToken));
        }
        else
        {
            existingRequest.Status = EncounterRequestStatus.Pending;
            existingRequest.Message = message;
            existingRequest.ChatId = null;
            existingRequest.DecidedAt = null;
            existingRequest.CreatedAt = DateTimeOffset.UtcNow;
            post.RequestCount++;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return CreatedAtAction(
            nameof(GetById),
            new { id = existingRequest.Id },
            await ToResponse(existingRequest, cancellationToken));
    }

    [HttpGet("encounter-requests/incoming")]
    public Task<ActionResult<IReadOnlyList<EncounterRequestResponse>>> Incoming(
        [FromQuery] EncounterRequestStatus? status = EncounterRequestStatus.Pending,
        [FromQuery] int limit = DefaultRequestLimit,
        CancellationToken cancellationToken = default)
    {
        return ListRequests(
            mineSelector: RequestListSelector.Incoming,
            status,
            limit,
            cancellationToken);
    }

    [HttpGet("encounter-requests/outgoing")]
    public Task<ActionResult<IReadOnlyList<EncounterRequestResponse>>> Outgoing(
        [FromQuery] EncounterRequestStatus? status = null,
        [FromQuery] int limit = DefaultRequestLimit,
        CancellationToken cancellationToken = default)
    {
        return ListRequests(
            mineSelector: RequestListSelector.Outgoing,
            status,
            limit,
            cancellationToken);
    }

    [HttpGet("encounter-requests/{id:guid}")]
    public async Task<ActionResult<EncounterRequestResponse>> GetById(
        Guid id,
        CancellationToken cancellationToken)
    {
        var user = await GetCurrentUser(cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        var request = await dbContext.EncounterRequests.AsNoTracking().FirstOrDefaultAsync(candidate =>
            candidate.Id == id &&
            (candidate.PostOwnerId == user.Id || candidate.RequesterId == user.Id),
            cancellationToken);

        if (request is null)
        {
            return NotFound(new { message = "İstek bulunamadı." });
        }

        return Ok(await ToResponse(request, cancellationToken));
    }

    [HttpPost("encounter-requests/{id:guid}/accept")]
    public async Task<ActionResult<EncounterRequestResponse>> Accept(
        Guid id,
        CancellationToken cancellationToken)
    {
        return await Decide(id, accepted: true, cancellationToken);
    }

    [HttpPost("encounter-requests/{id:guid}/reject")]
    public async Task<ActionResult<EncounterRequestResponse>> Reject(
        Guid id,
        CancellationToken cancellationToken)
    {
        return await Decide(id, accepted: false, cancellationToken);
    }

    private async Task<ActionResult<EncounterRequestResponse>> Decide(
        Guid id,
        bool accepted,
        CancellationToken cancellationToken)
    {
        var user = await GetCurrentUser(cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);

        var request = await dbContext.EncounterRequests.FirstOrDefaultAsync(candidate =>
            candidate.Id == id,
            cancellationToken);

        if (request is null)
        {
            return NotFound(new { message = "İstek bulunamadı." });
        }

        if (request.PostOwnerId != user.Id)
        {
            return Forbid();
        }

        if (!accepted)
        {
            if (request.Status == EncounterRequestStatus.Accepted)
            {
                return Conflict(new { message = "Kabul edilmiş istek reddedilemez." });
            }

            request.Status = EncounterRequestStatus.Rejected;
            request.DecidedAt = DateTimeOffset.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return Ok(await ToResponse(request, cancellationToken));
        }

        if (request.Status == EncounterRequestStatus.Accepted)
        {
            await transaction.RollbackAsync(cancellationToken);
            return Ok(await ToResponse(request, cancellationToken));
        }

        if (request.Status != EncounterRequestStatus.Pending)
        {
            return Conflict(new { message = "Sadece bekleyen istek kabul edilebilir." });
        }

        var post = await dbContext.EncounterPosts.FirstOrDefaultAsync(candidate =>
            candidate.Id == request.EncounterPostId && candidate.DeletedAt == null,
            cancellationToken);

        if (post is null)
        {
            return NotFound(new { message = "İtiraf bulunamadı." });
        }

        var now = DateTimeOffset.UtcNow;
        var participantAId = request.PostOwnerId.CompareTo(request.RequesterId) <= 0
            ? request.PostOwnerId
            : request.RequesterId;
        var participantBId = participantAId == request.PostOwnerId
            ? request.RequesterId
            : request.PostOwnerId;

        var chat = await dbContext.Chats.FirstOrDefaultAsync(candidate =>
            candidate.EncounterPostId == request.EncounterPostId &&
            candidate.ParticipantAId == participantAId &&
            candidate.ParticipantBId == participantBId,
            cancellationToken);

        if (chat is null)
        {
            chat = new Chat
            {
                Id = Guid.NewGuid(),
                EncounterPostId = request.EncounterPostId,
                ParticipantAId = participantAId,
                ParticipantBId = participantBId,
                LastMessage = "Sohbet açıldı.",
                LastMessageAt = now,
                CreatedAt = now,
                IsActive = true
            };

            dbContext.Chats.Add(chat);
        }

        request.ChatId = chat.Id;
        request.Status = EncounterRequestStatus.Accepted;
        request.DecidedAt = now;

        await dbContext.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return Ok(await ToResponse(request, cancellationToken));
    }

    private async Task<ActionResult<IReadOnlyList<EncounterRequestResponse>>> ListRequests(
        RequestListSelector mineSelector,
        EncounterRequestStatus? status,
        int limit,
        CancellationToken cancellationToken)
    {
        var user = await GetCurrentUser(cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        if (limit is < 1 or > MaxRequestLimit)
        {
            return BadRequest(new ValidationProblemDetails(new Dictionary<string, string[]>
            {
                [nameof(limit)] = [$"Limit 1-{MaxRequestLimit} arasında olmalı."]
            }));
        }

        var query = dbContext.EncounterRequests.AsNoTracking();

        query = mineSelector == RequestListSelector.Incoming
            ? query.Where(request => request.PostOwnerId == user.Id)
            : query.Where(request => request.RequesterId == user.Id);

        if (status is not null)
        {
            query = query.Where(request => request.Status == status);
        }

        var requests = await query
            .OrderByDescending(request => request.CreatedAt)
            .Take(limit)
            .ToListAsync(cancellationToken);

        return Ok(await ToResponses(requests, cancellationToken));
    }

    private async Task<IReadOnlyList<EncounterRequestResponse>> ToResponses(
        IReadOnlyList<EncounterRequest> requests,
        CancellationToken cancellationToken)
    {
        if (requests.Count == 0)
        {
            return [];
        }

        var postIds = requests.Select(request => request.EncounterPostId).Distinct().ToArray();
        var userIds = requests
            .SelectMany(request => new[] { request.PostOwnerId, request.RequesterId })
            .Distinct()
            .ToArray();

        var posts = await dbContext.EncounterPosts
            .AsNoTracking()
            .Where(post => postIds.Contains(post.Id))
            .ToDictionaryAsync(post => post.Id, cancellationToken);

        var users = await dbContext.Users
            .AsNoTracking()
            .Where(user => userIds.Contains(user.Id))
            .ToDictionaryAsync(user => user.Id, cancellationToken);

        return requests
            .Select(request => ToResponse(
                request,
                posts.GetValueOrDefault(request.EncounterPostId),
                users.GetValueOrDefault(request.RequesterId),
                users.GetValueOrDefault(request.PostOwnerId)))
            .ToList();
    }

    private async Task<EncounterRequestResponse> ToResponse(
        EncounterRequest request,
        CancellationToken cancellationToken)
    {
        var post = await dbContext.EncounterPosts
            .AsNoTracking()
            .FirstOrDefaultAsync(candidate => candidate.Id == request.EncounterPostId, cancellationToken);
        var requester = await dbContext.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(candidate => candidate.Id == request.RequesterId, cancellationToken);
        var owner = await dbContext.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(candidate => candidate.Id == request.PostOwnerId, cancellationToken);

        return ToResponse(request, post, requester, owner);
    }

    private static EncounterRequestResponse ToResponse(
        EncounterRequest request,
        EncounterPost? post,
        AppUser? requester,
        AppUser? owner)
    {
        return new EncounterRequestResponse(
            request.Id,
            request.EncounterPostId,
            request.RequesterId,
            request.PostOwnerId,
            request.ChatId,
            request.Status,
            request.Message ?? string.Empty,
            post?.Place ?? string.Empty,
            post?.Description ?? string.Empty,
            DisplayNameFor(requester),
            CalculateAge(requester?.BirthDate),
            requester?.Bio ?? string.Empty,
            requester?.PhotoUrls ?? [],
            DisplayNameFor(owner),
            request.CreatedAt,
            request.DecidedAt);
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

    private static string DisplayNameFor(AppUser? user)
    {
        return NormalizeOptional(user?.DisplayName) ?? user?.UserName ?? "Kullanıcı";
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

    private enum RequestListSelector
    {
        Incoming,
        Outgoing
    }
}
