namespace Fildir.Domain.Entities;

public sealed class AppUser
{
    public Guid Id { get; set; }
    public required string UserName { get; set; }
    public required string NormalizedUserName { get; set; }
    public required string Email { get; set; }
    public required string NormalizedEmail { get; set; }
    public required string PasswordHash { get; set; }
    public string? DisplayName { get; set; }
    public DateOnly? BirthDate { get; set; }
    public string? Gender { get; set; }
    public string? Bio { get; set; }
    public string? PhoneNumber { get; set; }
    public string? PhoneDigits { get; set; }
    public string? City { get; set; }
    public List<string> PhotoUrls { get; set; } = [];
    public bool IsDeleted { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? UpdatedAt { get; set; }
}
