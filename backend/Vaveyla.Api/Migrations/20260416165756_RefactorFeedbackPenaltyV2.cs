using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <inheritdoc />
    public partial class RefactorFeedbackPenaltyV2 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "Penalties");
            migrationBuilder.DropTable(name: "AdminActionLogs");
            migrationBuilder.DropTable(name: "Feedbacks");

            migrationBuilder.CreateTable(
                name: "Feedbacks",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CustomerId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TargetType = table.Column<byte>(type: "tinyint", nullable: false),
                    TargetEntityId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Message = table.Column<string>(type: "nvarchar(1200)", maxLength: 1200, nullable: false),
                    Status = table.Column<byte>(type: "tinyint", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(
                        type: "datetime2",
                        nullable: false,
                        defaultValueSql: "SYSUTCDATETIME()"),
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Feedbacks", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Penalties",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Points = table.Column<int>(type: "int", nullable: false),
                    Type = table.Column<byte>(type: "tinyint", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(
                        type: "datetime2",
                        nullable: false,
                        defaultValueSql: "SYSUTCDATETIME()"),
                    SuspendedUntil = table.Column<DateTime>(type: "datetime2", nullable: true),
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Penalties", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "AdminActionLogs",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    AdminUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ActionType = table.Column<byte>(type: "tinyint", nullable: false),
                    Details = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    RelatedFeedbackId = table.Column<int>(type: "int", nullable: true),
                    RelatedUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(
                        type: "datetime2",
                        nullable: false,
                        defaultValueSql: "SYSUTCDATETIME()"),
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AdminActionLogs", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Feedbacks_CreatedAtUtc",
                table: "Feedbacks",
                column: "CreatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_Feedbacks_CustomerId",
                table: "Feedbacks",
                column: "CustomerId");

            migrationBuilder.CreateIndex(
                name: "IX_Feedbacks_TargetType_TargetEntityId",
                table: "Feedbacks",
                columns: new[] { "TargetType", "TargetEntityId" });

            migrationBuilder.CreateIndex(
                name: "IX_Penalties_UserId",
                table: "Penalties",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_Penalties_CreatedAtUtc",
                table: "Penalties",
                column: "CreatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_AdminActionLogs_AdminUserId",
                table: "AdminActionLogs",
                column: "AdminUserId");

            migrationBuilder.CreateIndex(
                name: "IX_AdminActionLogs_CreatedAtUtc",
                table: "AdminActionLogs",
                column: "CreatedAtUtc");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "Penalties");
            migrationBuilder.DropTable(name: "AdminActionLogs");
            migrationBuilder.DropTable(name: "Feedbacks");

            migrationBuilder.CreateTable(
                name: "Feedbacks",
                columns: table => new
                {
                    FeedbackId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CustomerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TargetType = table.Column<byte>(type: "tinyint", nullable: false),
                    MenuItemId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    OrderId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CourierUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Description = table.Column<string>(type: "nvarchar(1200)", maxLength: 1200, nullable: false),
                    Status = table.Column<byte>(type: "tinyint", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(
                        type: "datetime2",
                        nullable: false,
                        defaultValueSql: "SYSUTCDATETIME()"),
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Feedbacks", x => x.FeedbackId);
                });

            migrationBuilder.CreateTable(
                name: "Penalties",
                columns: table => new
                {
                    PenaltyId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FeedbackId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AdminUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PenalizedUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Points = table.Column<int>(type: "int", nullable: false),
                    Kind = table.Column<byte>(type: "tinyint", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(
                        type: "datetime2",
                        nullable: false,
                        defaultValueSql: "SYSUTCDATETIME()"),
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Penalties", x => x.PenaltyId);
                });

            migrationBuilder.CreateTable(
                name: "AdminActionLogs",
                columns: table => new
                {
                    LogId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AdminUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ActionType = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Details = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    RelatedFeedbackId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    RelatedUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(
                        type: "datetime2",
                        nullable: false,
                        defaultValueSql: "SYSUTCDATETIME()"),
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AdminActionLogs", x => x.LogId);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Feedbacks_CreatedAtUtc",
                table: "Feedbacks",
                column: "CreatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_Feedbacks_CustomerUserId",
                table: "Feedbacks",
                column: "CustomerUserId");

            migrationBuilder.CreateIndex(
                name: "IX_Penalties_FeedbackId",
                table: "Penalties",
                column: "FeedbackId");

            migrationBuilder.CreateIndex(
                name: "IX_Penalties_PenalizedUserId",
                table: "Penalties",
                column: "PenalizedUserId");

            migrationBuilder.CreateIndex(
                name: "IX_AdminActionLogs_AdminUserId",
                table: "AdminActionLogs",
                column: "AdminUserId");

            migrationBuilder.CreateIndex(
                name: "IX_AdminActionLogs_CreatedAtUtc",
                table: "AdminActionLogs",
                column: "CreatedAtUtc");
        }
    }
}
