using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Vaveyla.Api.Data;

#nullable disable

namespace Vaveyla.Api.Migrations;

[DbContext(typeof(VaveylaDbContext))]
[Migration("20260518120000_AddOperationalFeatures")]
public class AddOperationalFeatures : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<decimal>(
            name: "MinimumOrderAmount",
            table: "Restaurants",
            type: "decimal(18,2)",
            nullable: true);

        migrationBuilder.AddColumn<decimal>(
            name: "DeliveryFeePerKm",
            table: "Restaurants",
            type: "decimal(18,2)",
            nullable: false,
            defaultValue: 5m);

        migrationBuilder.AddColumn<decimal>(
            name: "MaxDeliveryDistanceKm",
            table: "Restaurants",
            type: "decimal(18,2)",
            nullable: false,
            defaultValue: 15m);

        migrationBuilder.AddColumn<decimal>(
            name: "FreeDeliveryThreshold",
            table: "Restaurants",
            type: "decimal(18,2)",
            nullable: true);

        migrationBuilder.AddColumn<decimal>(
            name: "Subtotal",
            table: "CustomerOrders",
            type: "decimal(18,2)",
            nullable: false,
            defaultValue: 0m);

        migrationBuilder.AddColumn<decimal>(
            name: "DeliveryFee",
            table: "CustomerOrders",
            type: "decimal(18,2)",
            nullable: false,
            defaultValue: 0m);

        migrationBuilder.AddColumn<string>(
            name: "PaymentMethod",
            table: "CustomerOrders",
            type: "nvarchar(64)",
            maxLength: 64,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "OrderNotes",
            table: "CustomerOrders",
            type: "nvarchar(500)",
            maxLength: 500,
            nullable: true);

        migrationBuilder.AddColumn<byte>(
            name: "CancellationReason",
            table: "CustomerOrders",
            type: "tinyint",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "CancellationReasonNote",
            table: "CustomerOrders",
            type: "nvarchar(500)",
            maxLength: 500,
            nullable: true);

        migrationBuilder.AddColumn<DateTime>(
            name: "CancelledAtUtc",
            table: "CustomerOrders",
            type: "datetime2",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "CancelledByRole",
            table: "CustomerOrders",
            type: "nvarchar(32)",
            maxLength: 32,
            nullable: true);

        migrationBuilder.AddColumn<byte>(
            name: "LabelType",
            table: "UserAddresses",
            type: "tinyint",
            nullable: false,
            defaultValue: (byte)3);

        migrationBuilder.AddColumn<string>(
            name: "Floor",
            table: "UserAddresses",
            type: "nvarchar(20)",
            maxLength: 20,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "Apartment",
            table: "UserAddresses",
            type: "nvarchar(20)",
            maxLength: 20,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "DirectionsNote",
            table: "UserAddresses",
            type: "nvarchar(500)",
            maxLength: 500,
            nullable: true);

        migrationBuilder.AddColumn<double>(
            name: "Latitude",
            table: "UserAddresses",
            type: "float",
            nullable: true);

        migrationBuilder.AddColumn<double>(
            name: "Longitude",
            table: "UserAddresses",
            type: "float",
            nullable: true);

        migrationBuilder.AddColumn<bool>(
            name: "EmailVerified",
            table: "Users",
            type: "bit",
            nullable: false,
            defaultValue: false);

        migrationBuilder.AddColumn<string>(
            name: "EmailVerificationCodeHash",
            table: "Users",
            type: "nvarchar(200)",
            maxLength: 200,
            nullable: true);

        migrationBuilder.AddColumn<DateTime>(
            name: "EmailVerificationExpiresAtUtc",
            table: "Users",
            type: "datetime2",
            nullable: true);

        migrationBuilder.AddColumn<bool>(
            name: "PhoneVerified",
            table: "Users",
            type: "bit",
            nullable: false,
            defaultValue: false);

        migrationBuilder.AddColumn<string>(
            name: "SmsOtpCodeHash",
            table: "Users",
            type: "nvarchar(200)",
            maxLength: 200,
            nullable: true);

        migrationBuilder.AddColumn<DateTime>(
            name: "SmsOtpExpiresAtUtc",
            table: "Users",
            type: "datetime2",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "PasswordResetTokenUsedHash",
            table: "Users",
            type: "nvarchar(200)",
            maxLength: 200,
            nullable: true);

        migrationBuilder.AddColumn<bool>(
            name: "IsDeleted",
            table: "Users",
            type: "bit",
            nullable: false,
            defaultValue: false);

        migrationBuilder.AddColumn<DateTime>(
            name: "DeletedAtUtc",
            table: "Users",
            type: "datetime2",
            nullable: true);

        migrationBuilder.AddColumn<DateTime>(
            name: "DeletionScheduledAtUtc",
            table: "Users",
            type: "datetime2",
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "AnonymizedDisplayName",
            table: "Users",
            type: "nvarchar(120)",
            maxLength: 120,
            nullable: true);

        migrationBuilder.CreateTable(
            name: "CustomerOrderLineItems",
            columns: table => new
            {
                LineItemId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                OrderId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                ProductId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                ProductName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                ImagePath = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                Quantity = table.Column<int>(type: "int", nullable: false),
                WeightKg = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                SaleUnit = table.Column<byte>(type: "tinyint", nullable: false),
                UnitPrice = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                LineTotal = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                VariationJson = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_CustomerOrderLineItems", x => x.LineItemId);
                table.ForeignKey(
                    name: "FK_CustomerOrderLineItems_CustomerOrders_OrderId",
                    column: x => x.OrderId,
                    principalTable: "CustomerOrders",
                    principalColumn: "OrderId",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "OrderStatusHistories",
            columns: table => new
            {
                HistoryId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                OrderId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Status = table.Column<byte>(type: "tinyint", nullable: false),
                Note = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                ActorRole = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: true),
                ActorUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_OrderStatusHistories", x => x.HistoryId);
                table.ForeignKey(
                    name: "FK_OrderStatusHistories_CustomerOrders_OrderId",
                    column: x => x.OrderId,
                    principalTable: "CustomerOrders",
                    principalColumn: "OrderId",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "OrderRefundRequests",
            columns: table => new
            {
                RefundRequestId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                OrderId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                CustomerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                RestaurantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Status = table.Column<byte>(type: "tinyint", nullable: false),
                Reason = table.Column<byte>(type: "tinyint", nullable: false),
                ReasonNote = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                RestaurantResponse = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                ResolvedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                ResolvedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_OrderRefundRequests", x => x.RefundRequestId);
                table.ForeignKey(
                    name: "FK_OrderRefundRequests_CustomerOrders_OrderId",
                    column: x => x.OrderId,
                    principalTable: "CustomerOrders",
                    principalColumn: "OrderId",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "AccountDeletionAuditLogs",
            columns: table => new
            {
                AuditId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Action = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                IpAddress = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                UserAgent = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_AccountDeletionAuditLogs", x => x.AuditId);
            });

        migrationBuilder.CreateIndex(
            name: "IX_CustomerOrderLineItems_OrderId",
            table: "CustomerOrderLineItems",
            column: "OrderId");

        migrationBuilder.CreateIndex(
            name: "IX_OrderStatusHistories_OrderId",
            table: "OrderStatusHistories",
            column: "OrderId");

        migrationBuilder.CreateIndex(
            name: "IX_OrderRefundRequests_OrderId",
            table: "OrderRefundRequests",
            column: "OrderId");

        migrationBuilder.CreateIndex(
            name: "IX_OrderRefundRequests_CustomerUserId",
            table: "OrderRefundRequests",
            column: "CustomerUserId");

        migrationBuilder.CreateIndex(
            name: "IX_AccountDeletionAuditLogs_UserId",
            table: "AccountDeletionAuditLogs",
            column: "UserId");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "AccountDeletionAuditLogs");
        migrationBuilder.DropTable(name: "OrderRefundRequests");
        migrationBuilder.DropTable(name: "OrderStatusHistories");
        migrationBuilder.DropTable(name: "CustomerOrderLineItems");

        migrationBuilder.DropColumn(name: "AnonymizedDisplayName", table: "Users");
        migrationBuilder.DropColumn(name: "DeletionScheduledAtUtc", table: "Users");
        migrationBuilder.DropColumn(name: "DeletedAtUtc", table: "Users");
        migrationBuilder.DropColumn(name: "IsDeleted", table: "Users");
        migrationBuilder.DropColumn(name: "PasswordResetTokenUsedHash", table: "Users");
        migrationBuilder.DropColumn(name: "SmsOtpExpiresAtUtc", table: "Users");
        migrationBuilder.DropColumn(name: "SmsOtpCodeHash", table: "Users");
        migrationBuilder.DropColumn(name: "PhoneVerified", table: "Users");
        migrationBuilder.DropColumn(name: "EmailVerificationExpiresAtUtc", table: "Users");
        migrationBuilder.DropColumn(name: "EmailVerificationCodeHash", table: "Users");
        migrationBuilder.DropColumn(name: "EmailVerified", table: "Users");

        migrationBuilder.DropColumn(name: "Longitude", table: "UserAddresses");
        migrationBuilder.DropColumn(name: "Latitude", table: "UserAddresses");
        migrationBuilder.DropColumn(name: "DirectionsNote", table: "UserAddresses");
        migrationBuilder.DropColumn(name: "Apartment", table: "UserAddresses");
        migrationBuilder.DropColumn(name: "Floor", table: "UserAddresses");
        migrationBuilder.DropColumn(name: "LabelType", table: "UserAddresses");

        migrationBuilder.DropColumn(name: "CancelledByRole", table: "CustomerOrders");
        migrationBuilder.DropColumn(name: "CancelledAtUtc", table: "CustomerOrders");
        migrationBuilder.DropColumn(name: "CancellationReasonNote", table: "CustomerOrders");
        migrationBuilder.DropColumn(name: "CancellationReason", table: "CustomerOrders");
        migrationBuilder.DropColumn(name: "OrderNotes", table: "CustomerOrders");
        migrationBuilder.DropColumn(name: "PaymentMethod", table: "CustomerOrders");
        migrationBuilder.DropColumn(name: "DeliveryFee", table: "CustomerOrders");
        migrationBuilder.DropColumn(name: "Subtotal", table: "CustomerOrders");

        migrationBuilder.DropColumn(name: "FreeDeliveryThreshold", table: "Restaurants");
        migrationBuilder.DropColumn(name: "MaxDeliveryDistanceKm", table: "Restaurants");
        migrationBuilder.DropColumn(name: "DeliveryFeePerKm", table: "Restaurants");
        migrationBuilder.DropColumn(name: "MinimumOrderAmount", table: "Restaurants");
    }
}
