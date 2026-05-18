using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddCourierTrackingAndAssignment : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "AssignedCourierUserId",
                table: "CustomerOrders",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "CourierLat",
                table: "CustomerOrders",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "CourierLng",
                table: "CustomerOrders",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CourierLocationUpdatedAtUtc",
                table: "CustomerOrders",
                type: "datetime2",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "CourierLocationLogs",
                columns: table => new
                {
                    CourierLocationLogId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OrderId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CourierUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Latitude = table.Column<double>(type: "float", nullable: false),
                    Longitude = table.Column<double>(type: "float", nullable: false),
                    TimestampUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CourierLocationLogs", x => x.CourierLocationLogId);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CustomerOrders_AssignedCourierUserId",
                table: "CustomerOrders",
                column: "AssignedCourierUserId");

            migrationBuilder.CreateIndex(
                name: "IX_CourierLocationLogs_CourierUserId",
                table: "CourierLocationLogs",
                column: "CourierUserId");

            migrationBuilder.CreateIndex(
                name: "IX_CourierLocationLogs_OrderId",
                table: "CourierLocationLogs",
                column: "OrderId");

            migrationBuilder.CreateIndex(
                name: "IX_CourierLocationLogs_TimestampUtc",
                table: "CourierLocationLogs",
                column: "TimestampUtc");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CourierLocationLogs");

            migrationBuilder.DropIndex(
                name: "IX_CustomerOrders_AssignedCourierUserId",
                table: "CustomerOrders");

            migrationBuilder.DropColumn(
                name: "AssignedCourierUserId",
                table: "CustomerOrders");

            migrationBuilder.DropColumn(
                name: "CourierLat",
                table: "CustomerOrders");

            migrationBuilder.DropColumn(
                name: "CourierLng",
                table: "CustomerOrders");

            migrationBuilder.DropColumn(
                name: "CourierLocationUpdatedAtUtc",
                table: "CustomerOrders");
        }
    }
}
