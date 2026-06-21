using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Vaveyla.Api.Data;

#nullable disable

namespace Vaveyla.Api.Migrations;

/// <inheritdoc />
[DbContext(typeof(VaveylaDbContext))]
[Migration("20260413120000_AddDeliveryChatMessages")]
public class AddDeliveryChatMessages : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "DeliveryChatMessages",
            columns: table => new
            {
                MessageId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                OrderId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                SenderUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Message = table.Column<string>(type: "nvarchar(1500)", maxLength: 1500, nullable: false),
                CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                EditedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                DeletedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_DeliveryChatMessages", x => x.MessageId);
            });

        migrationBuilder.CreateIndex(
            name: "IX_DeliveryChatMessages_OrderId",
            table: "DeliveryChatMessages",
            column: "OrderId");

        migrationBuilder.CreateIndex(
            name: "IX_DeliveryChatMessages_OrderId_CreatedAtUtc",
            table: "DeliveryChatMessages",
            columns: new[] { "OrderId", "CreatedAtUtc" });
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(
            name: "DeliveryChatMessages");
    }
}
