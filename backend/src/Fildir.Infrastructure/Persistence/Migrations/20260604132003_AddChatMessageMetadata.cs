using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Fildir.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddChatMessageMetadata : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "DurationSeconds",
                table: "chat_messages",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_chat_messages_ChatId_SenderId_ReadAt",
                table: "chat_messages",
                columns: new[] { "ChatId", "SenderId", "ReadAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_chat_messages_ChatId_SenderId_ReadAt",
                table: "chat_messages");

            migrationBuilder.DropColumn(
                name: "DurationSeconds",
                table: "chat_messages");
        }
    }
}
