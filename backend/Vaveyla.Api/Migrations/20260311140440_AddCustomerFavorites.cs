using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddCustomerFavorites : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "CustomerFavorites",
                columns: table => new
                {
                    FavoriteId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CustomerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FavoriteType = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    TargetId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CustomerFavorites", x => x.FavoriteId);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CustomerFavorites_CustomerUserId",
                table: "CustomerFavorites",
                column: "CustomerUserId");

            migrationBuilder.CreateIndex(
                name: "IX_CustomerFavorites_CustomerUserId_FavoriteType_TargetId",
                table: "CustomerFavorites",
                columns: new[] { "CustomerUserId", "FavoriteType", "TargetId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CustomerFavorites");
        }
    }
}
