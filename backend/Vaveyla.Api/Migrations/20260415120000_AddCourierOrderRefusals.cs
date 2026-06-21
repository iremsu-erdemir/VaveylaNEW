using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Vaveyla.Api.Data;

#nullable disable

namespace Vaveyla.Api.Migrations;

[DbContext(typeof(VaveylaDbContext))]
[Migration("20260415120000_AddCourierOrderRefusals")]
public class AddCourierOrderRefusals : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "CourierOrderRefusals",
            columns: table => new
            {
                RefusalId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                OrderId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                CourierUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Reason = table.Column<string>(type: "nvarchar(600)", maxLength: 600, nullable: false),
                CreatedAtUtc = table.Column<DateTime>(
                    type: "datetime2",
                    nullable: false,
                    defaultValueSql: "SYSUTCDATETIME()"),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_CourierOrderRefusals", x => x.RefusalId);
            });

        migrationBuilder.CreateIndex(
            name: "IX_CourierOrderRefusals_OrderId_CourierUserId",
            table: "CourierOrderRefusals",
            columns: new[] { "OrderId", "CourierUserId" },
            unique: true);

        migrationBuilder.CreateIndex(
            name: "IX_CourierOrderRefusals_CourierUserId",
            table: "CourierOrderRefusals",
            column: "CourierUserId");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "CourierOrderRefusals");
    }
}
