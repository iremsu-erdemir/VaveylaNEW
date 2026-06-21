using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Vaveyla.Api.Data;

#nullable disable

namespace Vaveyla.Api.Migrations;

[DbContext(typeof(VaveylaDbContext))]
[Migration("20260415123000_AddCustomerOrderRejectionReason")]
public class AddCustomerOrderRejectionReason : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "RejectionReason",
            table: "CustomerOrders",
            type: "nvarchar(500)",
            maxLength: 500,
            nullable: true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(
            name: "RejectionReason",
            table: "CustomerOrders");
    }
}
