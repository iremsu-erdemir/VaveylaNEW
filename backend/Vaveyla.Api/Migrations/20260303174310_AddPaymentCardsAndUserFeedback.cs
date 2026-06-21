using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddPaymentCardsAndUserFeedback : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PaymentCards",
                columns: table => new
                {
                    PaymentCardId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CardholderName = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    CardNumber = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    Expiration = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    CVV = table.Column<string>(type: "nvarchar(4)", maxLength: 4, nullable: false),
                    BankName = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    CardAlias = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PaymentCards", x => x.PaymentCardId);
                    table.ForeignKey(
                        name: "FK_PaymentCards_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "UserId",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserFeedbacks",
                columns: table => new
                {
                    FeedbackId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RestaurantName = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    Message = table.Column<string>(type: "nvarchar(1200)", maxLength: 1200, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserFeedbacks", x => x.FeedbackId);
                    table.ForeignKey(
                        name: "FK_UserFeedbacks_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "UserId",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PaymentCards_UserId",
                table: "PaymentCards",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_UserFeedbacks_UserId",
                table: "UserFeedbacks",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PaymentCards");

            migrationBuilder.DropTable(
                name: "UserFeedbacks");
        }
    }
}
