using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddCustomerCartItems : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                IF OBJECT_ID(N'[dbo].[CustomerCartItems]', N'U') IS NULL
                BEGIN
                    CREATE TABLE [dbo].[CustomerCartItems] (
                        [CartItemId] uniqueidentifier NOT NULL,
                        [CustomerUserId] uniqueidentifier NOT NULL,
                        [ProductId] uniqueidentifier NOT NULL,
                        [RestaurantId] uniqueidentifier NOT NULL,
                        [ProductName] nvarchar(160) NOT NULL,
                        [ImagePath] nvarchar(512) NOT NULL,
                        [UnitPrice] int NOT NULL,
                        [WeightKg] decimal(5,2) NOT NULL,
                        [Quantity] int NOT NULL,
                        [CreatedAtUtc] datetime2 NOT NULL CONSTRAINT [DF_CustomerCartItems_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()),
                        [UpdatedAtUtc] datetime2 NOT NULL CONSTRAINT [DF_CustomerCartItems_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()),
                        CONSTRAINT [PK_CustomerCartItems] PRIMARY KEY ([CartItemId])
                    );
                END
                """);

            migrationBuilder.Sql(
                """
                IF NOT EXISTS (
                    SELECT 1 FROM sys.indexes
                    WHERE name = N'IX_CustomerCartItems_CustomerUserId'
                      AND object_id = OBJECT_ID(N'[dbo].[CustomerCartItems]')
                )
                BEGIN
                    CREATE INDEX [IX_CustomerCartItems_CustomerUserId]
                    ON [dbo].[CustomerCartItems] ([CustomerUserId]);
                END
                """);

            migrationBuilder.Sql(
                """
                IF NOT EXISTS (
                    SELECT 1 FROM sys.indexes
                    WHERE name = N'IX_CustomerCartItems_CustomerUserId_ProductId_WeightKg'
                      AND object_id = OBJECT_ID(N'[dbo].[CustomerCartItems]')
                )
                BEGIN
                    CREATE UNIQUE INDEX [IX_CustomerCartItems_CustomerUserId_ProductId_WeightKg]
                    ON [dbo].[CustomerCartItems] ([CustomerUserId], [ProductId], [WeightKg]);
                END
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                IF OBJECT_ID(N'[dbo].[CustomerCartItems]', N'U') IS NOT NULL
                BEGIN
                    DROP TABLE [dbo].[CustomerCartItems];
                END
                """);
        }
    }
}
