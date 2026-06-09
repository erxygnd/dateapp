using Fildir.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Fildir.Infrastructure.Persistence;

public sealed class FildirDbContext(DbContextOptions<FildirDbContext> options)
    : DbContext(options)
{
    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<EncounterPost> EncounterPosts => Set<EncounterPost>();
    public DbSet<EncounterRequest> EncounterRequests => Set<EncounterRequest>();
    public DbSet<Chat> Chats => Set<Chat>();
    public DbSet<ChatMessage> ChatMessages => Set<ChatMessage>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<AppUser>(entity =>
        {
            entity.ToTable("users");
            entity.HasKey(user => user.Id);
            entity.Property(user => user.UserName).HasMaxLength(40);
            entity.Property(user => user.NormalizedUserName).HasMaxLength(40);
            entity.Property(user => user.Email).HasMaxLength(320);
            entity.Property(user => user.NormalizedEmail).HasMaxLength(320);
            entity.Property(user => user.PasswordHash).HasMaxLength(512);
            entity.Property(user => user.DisplayName).HasMaxLength(80);
            entity.Property(user => user.Gender).HasMaxLength(40);
            entity.Property(user => user.Bio).HasMaxLength(800);
            entity.Property(user => user.PhoneNumber).HasMaxLength(32);
            entity.Property(user => user.PhoneDigits).HasMaxLength(24);
            entity.Property(user => user.City).HasMaxLength(80);
            entity.Property(user => user.PhotoUrls).HasColumnType("text[]");
            entity.HasIndex(user => user.NormalizedUserName).IsUnique();
            entity.HasIndex(user => user.NormalizedEmail).IsUnique();
        });

        modelBuilder.Entity<EncounterPost>(entity =>
        {
            entity.ToTable("encounter_posts");
            entity.HasKey(post => post.Id);
            entity.Property(post => post.Place).HasMaxLength(160);
            entity.Property(post => post.DateTimeText).HasMaxLength(120);
            entity.Property(post => post.Description).HasMaxLength(1200);
            entity.Property(post => post.Note).HasMaxLength(800);
            entity.Property(post => post.VehiclePlate).HasMaxLength(20);
            entity.Property(post => post.PersonAppearance).HasMaxLength(60);
            entity.Property(post => post.PersonTraits).HasMaxLength(300);
            entity.Property(post => post.Latitude).HasPrecision(9, 6);
            entity.Property(post => post.Longitude).HasPrecision(9, 6);
            entity.HasIndex(post => post.OwnerId);
            entity.HasIndex(post => post.CreatedAt);
        });

        modelBuilder.Entity<EncounterRequest>(entity =>
        {
            entity.ToTable("encounter_requests");
            entity.HasKey(request => request.Id);
            entity.Property(request => request.Message).HasMaxLength(800);
            entity.HasIndex(request => new { request.EncounterPostId, request.RequesterId })
                .IsUnique();
            entity.HasIndex(request => request.ChatId);
            entity.HasIndex(request => request.PostOwnerId);
            entity.HasIndex(request => request.Status);
        });

        modelBuilder.Entity<Chat>(entity =>
        {
            entity.ToTable("chats");
            entity.HasKey(chat => chat.Id);
            entity.Property(chat => chat.LastMessage).HasMaxLength(1200);
            entity.HasIndex(chat => chat.ParticipantAId);
            entity.HasIndex(chat => chat.ParticipantBId);
            entity.HasIndex(chat => chat.LastMessageAt);
            entity.HasIndex(chat => new { chat.EncounterPostId, chat.ParticipantAId, chat.ParticipantBId })
                .IsUnique();
        });

        modelBuilder.Entity<ChatMessage>(entity =>
        {
            entity.ToTable("chat_messages");
            entity.HasKey(message => message.Id);
            entity.Property(message => message.Content).HasMaxLength(4000);
            entity.Property(message => message.DurationSeconds);
            entity.HasIndex(message => new { message.ChatId, message.CreatedAt });
            entity.HasIndex(message => new { message.ChatId, message.SenderId, message.ReadAt });
        });

        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.ToTable("refresh_tokens");
            entity.HasKey(token => token.Id);
            entity.Property(token => token.TokenHash).HasMaxLength(128);
            entity.Property(token => token.CreatedByIp).HasMaxLength(64);
            entity.Property(token => token.RevokedByIp).HasMaxLength(64);
            entity.Property(token => token.ReplacedByTokenHash).HasMaxLength(128);
            entity.HasIndex(token => token.UserId);
            entity.HasIndex(token => token.TokenHash).IsUnique();
            entity.HasIndex(token => token.ExpiresAt);
        });
    }
}
