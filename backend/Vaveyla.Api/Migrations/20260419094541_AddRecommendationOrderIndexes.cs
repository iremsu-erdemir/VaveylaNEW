using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddRecommendationOrderIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_CustomerOrders_CustomerUserId_Status_CreatedAtUtc' AND object_id = OBJECT_ID(N'dbo.CustomerOrders'))
                CREATE NONCLUSTERED INDEX IX_CustomerOrders_CustomerUserId_Status_CreatedAtUtc
                ON dbo.CustomerOrders (CustomerUserId, Status, CreatedAtUtc);

                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_CustomerOrders_Status_CreatedAtUtc' AND object_id = OBJECT_ID(N'dbo.CustomerOrders'))
                CREATE NONCLUSTERED INDEX IX_CustomerOrders_Status_CreatedAtUtc
                ON dbo.CustomerOrders (Status, CreatedAtUtc);
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_CustomerOrders_CustomerUserId_Status_CreatedAtUtc' AND object_id = OBJECT_ID(N'dbo.CustomerOrders'))
                DROP INDEX IX_CustomerOrders_CustomerUserId_Status_CreatedAtUtc ON dbo.CustomerOrders;

                IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_CustomerOrders_Status_CreatedAtUtc' AND object_id = OBJECT_ID(N'dbo.CustomerOrders'))
                DROP INDEX IX_CustomerOrders_Status_CreatedAtUtc ON dbo.CustomerOrders;
                """);
        }
    }
}
