using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddRestaurantChatMessages : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "RestaurantChatMessages",
                columns: table => new
                {
                    ChatMessageId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RestaurantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CustomerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SenderUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SenderType = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Message = table.Column<string>(type: "nvarchar(1500)", maxLength: 1500, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RestaurantChatMessages", x => x.ChatMessageId);
                });

            migrationBuilder.CreateIndex(
                name: "IX_RestaurantChatMessages_CreatedAtUtc",
                table: "RestaurantChatMessages",
                column: "CreatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_RestaurantChatMessages_CustomerUserId",
                table: "RestaurantChatMessages",
                column: "CustomerUserId");

            migrationBuilder.CreateIndex(
                name: "IX_RestaurantChatMessages_RestaurantId",
                table: "RestaurantChatMessages",
                column: "RestaurantId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RestaurantChatMessages");
        }
    }
}
