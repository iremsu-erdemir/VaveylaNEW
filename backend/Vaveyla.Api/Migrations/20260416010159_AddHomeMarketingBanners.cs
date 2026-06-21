using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddHomeMarketingBanners : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "HomeMarketingBanners",
                columns: table => new
                {
                    BannerId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ImageUrl = table.Column<string>(type: "nvarchar(2048)", maxLength: 2048, nullable: false),
                    Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    Subtitle = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    BadgeText = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: true),
                    BodyText = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    SortOrder = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    IsActive = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    StartsAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    EndsAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ActionType = table.Column<byte>(type: "tinyint", nullable: false),
                    ActionTarget = table.Column<string>(type: "nvarchar(2048)", maxLength: 2048, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HomeMarketingBanners", x => x.BannerId);
                });

            migrationBuilder.CreateIndex(
                name: "IX_HomeMarketingBanners_IsActive_SortOrder",
                table: "HomeMarketingBanners",
                columns: new[] { "IsActive", "SortOrder" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "HomeMarketingBanners");
        }
    }
}
