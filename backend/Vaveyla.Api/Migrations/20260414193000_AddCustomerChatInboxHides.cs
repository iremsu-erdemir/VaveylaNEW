using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Vaveyla.Api.Data;

#nullable disable

namespace Vaveyla.Api.Migrations;

[DbContext(typeof(VaveylaDbContext))]
[Migration("20260414193000_AddCustomerChatInboxHides")]
public class AddCustomerChatInboxHides : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "CustomerChatInboxHides",
            columns: table => new
            {
                HideId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                CustomerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                RestaurantId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                OrderId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                HiddenAtUtc = table.Column<DateTime>(
                    type: "datetime2",
                    nullable: false,
                    defaultValueSql: "SYSUTCDATETIME()"),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_CustomerChatInboxHides", x => x.HideId);
            });

        migrationBuilder.CreateIndex(
            name: "IX_CustomerChatInboxHides_CustomerUserId",
            table: "CustomerChatInboxHides",
            column: "CustomerUserId");

        migrationBuilder.CreateIndex(
            name: "IX_CustomerChatInboxHides_CustomerUserId_RestaurantId",
            table: "CustomerChatInboxHides",
            columns: new[] { "CustomerUserId", "RestaurantId" },
            unique: true,
            filter: "[RestaurantId] IS NOT NULL");

        migrationBuilder.CreateIndex(
            name: "IX_CustomerChatInboxHides_CustomerUserId_OrderId",
            table: "CustomerChatInboxHides",
            columns: new[] { "CustomerUserId", "OrderId" },
            unique: true,
            filter: "[OrderId] IS NOT NULL");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "CustomerChatInboxHides");
    }
}
