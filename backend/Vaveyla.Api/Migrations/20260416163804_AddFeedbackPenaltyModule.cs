using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Vaveyla.Api.Migrations;

/// <summary>
/// Idempotent: daha önce yarım kalan veya tabloların elle var olduğu veritabanlarında tekrar çalıştırılabilir.
/// </summary>
public partial class AddFeedbackPenaltyModule : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("""
            IF COL_LENGTH(N'dbo.Users', N'IsPermanentlyBanned') IS NULL
                ALTER TABLE [Users] ADD [IsPermanentlyBanned] bit NOT NULL CONSTRAINT [DF_Users_IsPermanentlyBanned_AddFb] DEFAULT CAST(0 AS bit);

            IF COL_LENGTH(N'dbo.Users', N'PenaltySuspensionEndUtc') IS NULL
                ALTER TABLE [Users] ADD [PenaltySuspensionEndUtc] datetime2 NULL;

            IF COL_LENGTH(N'dbo.Users', N'TotalPenaltyPoints') IS NULL
                ALTER TABLE [Users] ADD [TotalPenaltyPoints] int NOT NULL CONSTRAINT [DF_Users_TotalPenaltyPoints_AddFb] DEFAULT 0;
            """);

        migrationBuilder.Sql("""
            IF OBJECT_ID(N'[dbo].[AdminActionLogs]', N'U') IS NULL
            BEGIN
                CREATE TABLE [AdminActionLogs] (
                    [LogId] uniqueidentifier NOT NULL,
                    [AdminUserId] uniqueidentifier NOT NULL,
                    [ActionType] nvarchar(120) NOT NULL,
                    [Details] nvarchar(2000) NOT NULL,
                    [RelatedFeedbackId] uniqueidentifier NULL,
                    [RelatedUserId] uniqueidentifier NULL,
                    [CreatedAtUtc] datetime2 NOT NULL CONSTRAINT [DF_AdminActionLogs_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()),
                    CONSTRAINT [PK_AdminActionLogs] PRIMARY KEY ([LogId])
                );
            END

            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_AdminActionLogs_AdminUserId' AND object_id = OBJECT_ID(N'[dbo].[AdminActionLogs]'))
                CREATE INDEX [IX_AdminActionLogs_AdminUserId] ON [AdminActionLogs] ([AdminUserId]);

            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_AdminActionLogs_CreatedAtUtc' AND object_id = OBJECT_ID(N'[dbo].[AdminActionLogs]'))
                CREATE INDEX [IX_AdminActionLogs_CreatedAtUtc] ON [AdminActionLogs] ([CreatedAtUtc]);
            """);

        migrationBuilder.Sql("""
            IF OBJECT_ID(N'[dbo].[Feedbacks]', N'U') IS NULL
            BEGIN
                CREATE TABLE [Feedbacks] (
                    [FeedbackId] uniqueidentifier NOT NULL,
                    [CustomerUserId] uniqueidentifier NOT NULL,
                    [TargetType] tinyint NOT NULL,
                    [MenuItemId] uniqueidentifier NULL,
                    [OrderId] uniqueidentifier NULL,
                    [CourierUserId] uniqueidentifier NULL,
                    [Description] nvarchar(1200) NOT NULL,
                    [Status] tinyint NOT NULL,
                    [CreatedAtUtc] datetime2 NOT NULL CONSTRAINT [DF_Feedbacks_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()),
                    CONSTRAINT [PK_Feedbacks] PRIMARY KEY ([FeedbackId])
                );
            END

            IF OBJECT_ID(N'[dbo].[Feedbacks]', N'U') IS NOT NULL
               AND COL_LENGTH(N'dbo.Feedbacks', N'FeedbackId') IS NOT NULL
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Feedbacks_CreatedAtUtc' AND object_id = OBJECT_ID(N'[dbo].[Feedbacks]'))
                    CREATE INDEX [IX_Feedbacks_CreatedAtUtc] ON [Feedbacks] ([CreatedAtUtc]);
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Feedbacks_CustomerUserId' AND object_id = OBJECT_ID(N'[dbo].[Feedbacks]'))
                    CREATE INDEX [IX_Feedbacks_CustomerUserId] ON [Feedbacks] ([CustomerUserId]);
            END
            """);

        migrationBuilder.Sql("""
            IF OBJECT_ID(N'[dbo].[Penalties]', N'U') IS NULL
            BEGIN
                CREATE TABLE [Penalties] (
                    [PenaltyId] uniqueidentifier NOT NULL,
                    [FeedbackId] uniqueidentifier NOT NULL,
                    [AdminUserId] uniqueidentifier NOT NULL,
                    [PenalizedUserId] uniqueidentifier NOT NULL,
                    [Points] int NOT NULL,
                    [Kind] tinyint NOT NULL,
                    [CreatedAtUtc] datetime2 NOT NULL CONSTRAINT [DF_Penalties_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()),
                    CONSTRAINT [PK_Penalties] PRIMARY KEY ([PenaltyId])
                );
            END

            IF OBJECT_ID(N'[dbo].[Penalties]', N'U') IS NOT NULL
               AND COL_LENGTH(N'dbo.Penalties', N'PenaltyId') IS NOT NULL
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Penalties_FeedbackId' AND object_id = OBJECT_ID(N'[dbo].[Penalties]'))
                    CREATE INDEX [IX_Penalties_FeedbackId] ON [Penalties] ([FeedbackId]);
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Penalties_PenalizedUserId' AND object_id = OBJECT_ID(N'[dbo].[Penalties]'))
                    CREATE INDEX [IX_Penalties_PenalizedUserId] ON [Penalties] ([PenalizedUserId]);
            END
            """);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "AdminActionLogs");
        migrationBuilder.DropTable(name: "Feedbacks");
        migrationBuilder.DropTable(name: "Penalties");

        migrationBuilder.DropColumn(name: "IsPermanentlyBanned", table: "Users");
        migrationBuilder.DropColumn(name: "PenaltySuspensionEndUtc", table: "Users");
        migrationBuilder.DropColumn(name: "TotalPenaltyPoints", table: "Users");
    }
}
