using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddReviewTargets : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "TargetId",
                table: "RestaurantReviews",
                type: "uniqueidentifier",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.AddColumn<string>(
                name: "TargetType",
                table: "RestaurantReviews",
                type: "nvarchar(30)",
                maxLength: 30,
                nullable: false,
                defaultValue: "restaurant");

            migrationBuilder.Sql(
                """
                UPDATE dbo.RestaurantReviews
                SET
                    TargetType = CASE WHEN ProductId IS NULL THEN 'restaurant' ELSE 'menu' END,
                    TargetId = CASE WHEN ProductId IS NULL THEN RestaurantId ELSE ProductId END
                """);

            migrationBuilder.CreateIndex(
                name: "IX_RestaurantReviews_TargetType_TargetId",
                table: "RestaurantReviews",
                columns: new[] { "TargetType", "TargetId" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_RestaurantReviews_TargetType_TargetId",
                table: "RestaurantReviews");

            migrationBuilder.DropColumn(
                name: "TargetId",
                table: "RestaurantReviews");

            migrationBuilder.DropColumn(
                name: "TargetType",
                table: "RestaurantReviews");
        }
    }
}
