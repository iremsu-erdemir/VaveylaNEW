using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <inheritdoc />
    public partial class RemoveUserCouponsUniqueConstraint : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_UserCoupons_UserId_CouponId",
                table: "UserCoupons");

            migrationBuilder.CreateIndex(
                name: "IX_UserCoupons_UserId_CouponId",
                table: "UserCoupons",
                columns: new[] { "UserId", "CouponId" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_UserCoupons_UserId_CouponId",
                table: "UserCoupons");

            migrationBuilder.CreateIndex(
                name: "IX_UserCoupons_UserId_CouponId",
                table: "UserCoupons",
                columns: new[] { "UserId", "CouponId" },
                unique: true);
        }
    }
}
