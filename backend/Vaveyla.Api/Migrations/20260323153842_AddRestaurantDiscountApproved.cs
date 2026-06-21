using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddRestaurantDiscountApproved : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "RestaurantDiscountApproved",
                table: "Restaurants",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RestaurantDiscountApproved",
                table: "Restaurants");
        }
    }
}
