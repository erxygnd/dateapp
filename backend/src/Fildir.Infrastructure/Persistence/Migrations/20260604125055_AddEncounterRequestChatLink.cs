using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Fildir.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddEncounterRequestChatLink : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "ChatId",
                table: "encounter_requests",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_encounter_requests_ChatId",
                table: "encounter_requests",
                column: "ChatId");

            migrationBuilder.CreateIndex(
                name: "IX_chats_EncounterPostId_ParticipantAId_ParticipantBId",
                table: "chats",
                columns: new[] { "EncounterPostId", "ParticipantAId", "ParticipantBId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_encounter_requests_ChatId",
                table: "encounter_requests");

            migrationBuilder.DropIndex(
                name: "IX_chats_EncounterPostId_ParticipantAId_ParticipantBId",
                table: "chats");

            migrationBuilder.DropColumn(
                name: "ChatId",
                table: "encounter_requests");
        }
    }
}
