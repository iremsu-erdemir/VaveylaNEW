using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <summary>
    /// Designer olmadan eklenmiş 20260306000000 / 20260306000001 migration dosyaları EF zincirinde
    /// yoktu; CustomerOrders ve MenuItems.CategoryName veritabanında oluşmuyordu. Bu migration
    /// aynı şemayı idempotent SQL ile uygular.
    /// </summary>
    public partial class EnsureCustomerOrdersBaseline : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                IF OBJECT_ID(N'[dbo].[CustomerOrders]', N'U') IS NULL
                BEGIN
                    CREATE TABLE [dbo].[CustomerOrders] (
                        [OrderId] uniqueidentifier NOT NULL,
                        [CustomerUserId] uniqueidentifier NOT NULL,
                        [RestaurantId] uniqueidentifier NOT NULL,
                        [Items] nvarchar(800) NOT NULL,
                        [Total] int NOT NULL,
                        [DeliveryAddress] nvarchar(400) NOT NULL,
                        [DeliveryAddressDetail] nvarchar(200) NULL,
                        [CustomerLat] float NULL,
                        [CustomerLng] float NULL,
                        [RestaurantAddress] nvarchar(400) NULL,
                        [RestaurantLat] float NULL,
                        [RestaurantLng] float NULL,
                        [CustomerName] nvarchar(120) NULL,
                        [CustomerPhone] nvarchar(40) NULL,
                        [Status] tinyint NOT NULL,
                        [CreatedAtUtc] datetime2 NOT NULL CONSTRAINT [DF_CustomerOrders_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()),
                        CONSTRAINT [PK_CustomerOrders] PRIMARY KEY ([OrderId])
                    );
                    CREATE INDEX [IX_CustomerOrders_CustomerUserId] ON [dbo].[CustomerOrders] ([CustomerUserId]);
                    CREATE INDEX [IX_CustomerOrders_RestaurantId] ON [dbo].[CustomerOrders] ([RestaurantId]);
                    CREATE INDEX [IX_CustomerOrders_Status] ON [dbo].[CustomerOrders] ([Status]);
                END
                """);

            migrationBuilder.Sql(
                """
                IF COL_LENGTH(N'dbo.MenuItems', N'CategoryName') IS NULL
                BEGIN
                    ALTER TABLE [dbo].[MenuItems] ADD [CategoryName] nvarchar(80) NULL;
                END
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                IF COL_LENGTH(N'dbo.MenuItems', N'CategoryName') IS NOT NULL
                BEGIN
                    ALTER TABLE [dbo].[MenuItems] DROP COLUMN [CategoryName];
                END
                """);

            migrationBuilder.Sql(
                """
                IF OBJECT_ID(N'[dbo].[CustomerOrders]', N'U') IS NOT NULL
                BEGIN
                    DROP TABLE [dbo].[CustomerOrders];
                END
                """);
        }
    }
}
