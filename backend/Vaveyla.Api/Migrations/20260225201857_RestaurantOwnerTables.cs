using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <inheritdoc />
    public partial class RestaurantOwnerTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "MenuItems",
                columns: table => new
                {
                    MenuItemId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RestaurantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    Price = table.Column<int>(type: "int", nullable: false),
                    ImagePath = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    IsAvailable = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    IsFeatured = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MenuItems", x => x.MenuItemId);
                });

            migrationBuilder.CreateTable(
                name: "RestaurantOrders",
                columns: table => new
                {
                    OrderId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RestaurantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Items = table.Column<string>(type: "nvarchar(600)", maxLength: 600, nullable: false),
                    Total = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<byte>(type: "tinyint", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RestaurantOrders", x => x.OrderId);
                });

            migrationBuilder.CreateTable(
                name: "RestaurantReviews",
                columns: table => new
                {
                    ReviewId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RestaurantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CustomerName = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Rating = table.Column<byte>(type: "tinyint", nullable: false),
                    Comment = table.Column<string>(type: "nvarchar(800)", maxLength: 800, nullable: false),
                    OwnerReply = table.Column<string>(type: "nvarchar(800)", maxLength: 800, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RestaurantReviews", x => x.ReviewId);
                });

            migrationBuilder.CreateTable(
                name: "Restaurants",
                columns: table => new
                {
                    RestaurantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OwnerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    Type = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Address = table.Column<string>(type: "nvarchar(320)", maxLength: 320, nullable: false),
                    Phone = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    WorkingHours = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    OrderNotifications = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    IsOpen = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    PhotoPath = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Restaurants", x => x.RestaurantId);
                });

            migrationBuilder.CreateIndex(
                name: "IX_MenuItems_RestaurantId",
                table: "MenuItems",
                column: "RestaurantId");

            migrationBuilder.CreateIndex(
                name: "IX_RestaurantOrders_RestaurantId",
                table: "RestaurantOrders",
                column: "RestaurantId");

            migrationBuilder.CreateIndex(
                name: "IX_RestaurantReviews_RestaurantId",
                table: "RestaurantReviews",
                column: "RestaurantId");

            migrationBuilder.CreateIndex(
                name: "IX_Restaurants_OwnerUserId",
                table: "Restaurants",
                column: "OwnerUserId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "MenuItems");

            migrationBuilder.DropTable(
                name: "RestaurantOrders");

            migrationBuilder.DropTable(
                name: "RestaurantReviews");

            migrationBuilder.DropTable(
                name: "Restaurants");
        }
    }
}
