using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddReviewOwnershipAndProduct : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "CustomerUserId",
                table: "RestaurantReviews",
                type: "uniqueidentifier",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.AddColumn<Guid>(
                name: "ProductId",
                table: "RestaurantReviews",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_RestaurantReviews_CustomerUserId",
                table: "RestaurantReviews",
                column: "CustomerUserId");

            migrationBuilder.CreateIndex(
                name: "IX_RestaurantReviews_ProductId",
                table: "RestaurantReviews",
                column: "ProductId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_RestaurantReviews_CustomerUserId",
                table: "RestaurantReviews");

            migrationBuilder.DropIndex(
                name: "IX_RestaurantReviews_ProductId",
                table: "RestaurantReviews");

            migrationBuilder.DropColumn(
                name: "CustomerUserId",
                table: "RestaurantReviews");

            migrationBuilder.DropColumn(
                name: "ProductId",
                table: "RestaurantReviews");
        }
    }
}
