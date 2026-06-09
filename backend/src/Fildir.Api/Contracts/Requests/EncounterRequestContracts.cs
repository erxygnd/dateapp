using Fildir.Domain.Enums;

namespace Fildir.Api.Contracts.Requests;

public sealed record SendEncounterRequestRequest(string? Message);

public sealed record EncounterRequestResponse(
    Guid Id,
    Guid EncounterPostId,
    Guid RequesterId,
    Guid PostOwnerId,
    Guid? ChatId,
    EncounterRequestStatus Status,
    string Message,
    string PostPlace,
    string PostDescription,
    string RequesterName,
    int? RequesterAge,
    string RequesterBio,
    IReadOnlyList<string> RequesterPhotoUrls,
    string OwnerName,
    DateTimeOffset CreatedAt,
    DateTimeOffset? DecidedAt);
