using System.Security.Claims;
using Fildir.Api.Contracts.Chats;
using Fildir.Domain.Entities;
using Fildir.Domain.Enums;
using Fildir.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Fildir.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/chats")]
public sealed class ChatsController(FildirDbContext dbContext) : ControllerBase
{
    private const int DefaultChatLimit = 50;
    private const int MaxChatLimit = 100;
    private const int DefaultMessageLimit = 80;
    private const int MaxMessageLimit = 150;
    private const int MaxMessageContentLength = 4000;
    private const int MaxVoiceDurationSeconds = 60;

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ChatSummaryResponse>>> GetChats(
        [FromQuery] int limit = DefaultChatLimit,
        CancellationToken cancellationToken = default)
    {
        var user = await GetCurrentUser(cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        if (limit is < 1 or > MaxChatLimit)
        {
            return BadRequest(new ValidationProblemDetails(new Dictionary<string, string[]>
            {
                [nameof(limit)] = [$"Limit 1-{MaxChatLimit} arasında olmalı."]
            }));
        }

        var chats = await dbContext.Chats
            .AsNoTracking()
            .Where(chat => chat.ParticipantAId == user.Id || chat.ParticipantBId == user.Id)
            .OrderByDescending(chat => chat.LastMessageAt ?? chat.CreatedAt)
            .Take(limit)
            .ToListAsync(cancellationToken);

        if (chats.Count == 0)
        {
            return Ok(Array.Empty<ChatSummaryResponse>());
        }

        var otherUserIds = chats
            .Select(chat => OtherUserId(chat, user.Id))
            .Distinct()
            .ToArray();

        var otherUsers = await dbContext.Users
            .AsNoTracking()
            .Where(candidate => otherUserIds.Contains(candidate.Id))
            .ToDictionaryAsync(candidate => candidate.Id, cancellationToken);

        var chatIds = chats.Select(chat => chat.Id).ToArray();
        var unreadCounts = await GetUnreadCounts(chatIds, user.Id, cancellationToken);

        var response = chats
            .Select(chat => ToSummaryResponse(
                chat,
                user.Id,
                otherUsers.GetValueOrDefault(OtherUserId(chat, user.Id)),
                unreadCounts.GetValueOrDefault(chat.Id)))
            .ToList();

        return Ok(response);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ChatDetailResponse>> GetById(
        Guid id,
        CancellationToken cancellationToken)
    {
        var user = await GetCurrentUser(cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        var chat = await GetAuthorizedChat(id, user.Id, asNoTracking: true, cancellationToken);

        if (chat is null)
        {
            return NotFound(new { message = "Sohbet bulunamadı." });
        }

        var otherUser = await dbContext.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(candidate => candidate.Id == OtherUserId(chat, user.Id), cancellationToken);
        var unreadCount = await GetUnreadCount(chat.Id, user.Id, cancellationToken);

        return Ok(ToDetailResponse(chat, user.Id, otherUser, unreadCount));
    }

    [HttpGet("{id:guid}/messages")]
    public async Task<ActionResult<ChatMessagesPageResponse>> GetMessages(
        Guid id,
        [FromQuery] DateTimeOffset? before = null,
        [FromQuery] int limit = DefaultMessageLimit,
        CancellationToken cancellationToken = default)
    {
        var user = await GetCurrentUser(cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        if (limit is < 1 or > MaxMessageLimit)
        {
            return BadRequest(new ValidationProblemDetails(new Dictionary<string, string[]>
            {
                [nameof(limit)] = [$"Limit 1-{MaxMessageLimit} arasında olmalı."]
            }));
        }

        var chat = await GetAuthorizedChat(id, user.Id, asNoTracking: true, cancellationToken);

        if (chat is null)
        {
            return NotFound(new { message = "Sohbet bulunamadı." });
        }

        var query = dbContext.ChatMessages
            .AsNoTracking()
            .Where(message => message.ChatId == id);

        if (before is not null)
        {
            query = query.Where(message => message.CreatedAt < before.Value);
        }

        var messages = await query
            .OrderByDescending(message => message.CreatedAt)
            .Take(limit)
            .ToListAsync(cancellationToken);

        var response = messages
            .OrderBy(message => message.CreatedAt)
            .Select(message => ToMessageResponse(message, user.Id))
            .ToList();

        return Ok(new ChatMessagesPageResponse(response.Count, response));
    }

    [HttpPost("{id:guid}/messages")]
    public async Task<ActionResult<ChatMessageResponse>> SendMessage(
        Guid id,
        SendChatMessageRequest request,
        CancellationToken cancellationToken)
    {
        var user = await GetCurrentUser(cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        var errors = ValidateSendMessageRequest(request);

        if (errors.Count > 0)
        {
            return BadRequest(new ValidationProblemDetails(errors));
        }

        var chat = await GetAuthorizedChat(id, user.Id, asNoTracking: false, cancellationToken);

        if (chat is null)
        {
            return NotFound(new { message = "Sohbet bulunamadı." });
        }

        if (!chat.IsActive)
        {
            return Conflict(new { message = "Bu sohbet kapalı." });
        }

        var now = DateTimeOffset.UtcNow;
        var content = request.Content.Trim();
        var message = new ChatMessage
        {
            Id = Guid.NewGuid(),
            ChatId = chat.Id,
            SenderId = user.Id,
            Type = request.Type,
            Content = content,
            DurationSeconds = request.Type == ChatMessageType.Voice
                ? request.DurationSeconds
                : null,
            CreatedAt = now
        };

        dbContext.ChatMessages.Add(message);
        chat.LastMessage = PreviewFor(message);
        chat.LastSenderId = user.Id;
        chat.LastMessageAt = now;

        await dbContext.SaveChangesAsync(cancellationToken);

        return CreatedAtAction(
            nameof(GetMessages),
            new { id = chat.Id },
            ToMessageResponse(message, user.Id));
    }

    [HttpPost("{id:guid}/read")]
    public async Task<ActionResult<MarkChatReadResponse>> MarkRead(
        Guid id,
        CancellationToken cancellationToken)
    {
        var user = await GetCurrentUser(cancellationToken);

        if (user is null)
        {
            return Unauthorized();
        }

        var chat = await GetAuthorizedChat(id, user.Id, asNoTracking: true, cancellationToken);

        if (chat is null)
        {
            return NotFound(new { message = "Sohbet bulunamadı." });
        }

        var now = DateTimeOffset.UtcNow;
        var messages = await dbContext.ChatMessages
            .Where(message =>
                message.ChatId == id &&
                message.SenderId != user.Id &&
                message.ReadAt == null)
            .ToListAsync(cancellationToken);

        foreach (var message in messages)
        {
            message.ReadAt = now;
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        return Ok(new MarkChatReadResponse(id, messages.Count, now));
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

    private Task<Chat?> GetAuthorizedChat(
        Guid chatId,
        Guid userId,
        bool asNoTracking,
        CancellationToken cancellationToken)
    {
        var query = asNoTracking ? dbContext.Chats.AsNoTracking() : dbContext.Chats;

        return query.FirstOrDefaultAsync(chat =>
            chat.Id == chatId &&
            (chat.ParticipantAId == userId || chat.ParticipantBId == userId),
            cancellationToken);
    }

    private async Task<Dictionary<Guid, int>> GetUnreadCounts(
        IReadOnlyList<Guid> chatIds,
        Guid userId,
        CancellationToken cancellationToken)
    {
        return await dbContext.ChatMessages
            .AsNoTracking()
            .Where(message =>
                chatIds.Contains(message.ChatId) &&
                message.SenderId != userId &&
                message.ReadAt == null)
            .GroupBy(message => message.ChatId)
            .Select(group => new
            {
                ChatId = group.Key,
                Count = group.Count()
            })
            .ToDictionaryAsync(item => item.ChatId, item => item.Count, cancellationToken);
    }

    private async Task<int> GetUnreadCount(
        Guid chatId,
        Guid userId,
        CancellationToken cancellationToken)
    {
        return await dbContext.ChatMessages
            .AsNoTracking()
            .CountAsync(message =>
                message.ChatId == chatId &&
                message.SenderId != userId &&
                message.ReadAt == null,
                cancellationToken);
    }

    private static ChatSummaryResponse ToSummaryResponse(
        Chat chat,
        Guid currentUserId,
        AppUser? otherUser,
        int unreadCount)
    {
        return new ChatSummaryResponse(
            chat.Id,
            chat.EncounterPostId,
            OtherUserId(chat, currentUserId),
            DisplayNameFor(otherUser),
            otherUser?.PhotoUrls.FirstOrDefault(),
            chat.LastMessage ?? "Sohbet açıldı.",
            chat.LastSenderId,
            chat.LastMessageAt,
            unreadCount,
            chat.IsActive,
            chat.CreatedAt);
    }

    private static ChatDetailResponse ToDetailResponse(
        Chat chat,
        Guid currentUserId,
        AppUser? otherUser,
        int unreadCount)
    {
        return new ChatDetailResponse(
            chat.Id,
            chat.EncounterPostId,
            chat.ParticipantAId,
            chat.ParticipantBId,
            OtherUserId(chat, currentUserId),
            DisplayNameFor(otherUser),
            chat.LastMessage ?? "Sohbet açıldı.",
            chat.LastSenderId,
            chat.LastMessageAt,
            unreadCount,
            chat.IsActive,
            chat.CreatedAt);
    }

    private static ChatMessageResponse ToMessageResponse(ChatMessage message, Guid currentUserId)
    {
        return new ChatMessageResponse(
            message.Id,
            message.ChatId,
            message.SenderId,
            message.SenderId == currentUserId,
            message.Type,
            message.Content,
            message.DurationSeconds,
            message.CreatedAt,
            message.ReadAt);
    }

    private static Dictionary<string, string[]> ValidateSendMessageRequest(
        SendChatMessageRequest request)
    {
        var errors = new Dictionary<string, string[]>();
        var content = request.Content?.Trim() ?? string.Empty;

        if (content.Length is < 1 or > MaxMessageContentLength)
        {
            errors[nameof(request.Content)] =
            [
                $"Mesaj içeriği 1-{MaxMessageContentLength} karakter arasında olmalı."
            ];
        }

        if (!Enum.IsDefined(request.Type))
        {
            errors[nameof(request.Type)] = ["Geçerli bir mesaj tipi gönder."];
        }

        if (request.Type == ChatMessageType.Voice &&
            request.DurationSeconds is null or < 1 or > MaxVoiceDurationSeconds)
        {
            errors[nameof(request.DurationSeconds)] =
            [
                $"Ses kaydı 1-{MaxVoiceDurationSeconds} saniye arasında olmalı."
            ];
        }

        return errors;
    }

    private static string PreviewFor(ChatMessage message)
    {
        return message.Type switch
        {
            ChatMessageType.Photo => "Fotoğraf gönderildi.",
            ChatMessageType.Voice => "Ses kaydı gönderildi.",
            _ => message.Content
        };
    }

    private static Guid OtherUserId(Chat chat, Guid currentUserId)
    {
        return chat.ParticipantAId == currentUserId
            ? chat.ParticipantBId
            : chat.ParticipantAId;
    }

    private static string DisplayNameFor(AppUser? user)
    {
        return NormalizeOptional(user?.DisplayName) ?? user?.UserName ?? "Kullanıcı";
    }

    private static string? NormalizeOptional(string? value)
    {
        var normalized = value?.Trim();
        return string.IsNullOrWhiteSpace(normalized) ? null : normalized;
    }
}
