-- Migration: CategoryName ve CustomerOrders
-- Bu scripti SQL Server Management Studio veya sqlcmd ile çalıştırın.
-- Backend'i DURDURUN, sonra bu scripti çalıştırın, ardından backend'i yeniden başlatın.

USE [VaveylaDb_Initial];
GO

-- 1. MenuItems tablosuna CategoryName sütunu ekle (yoksa)
IF NOT EXISTS (
    SELECT 1 FROM sys.columns 
    WHERE object_id = OBJECT_ID('MenuItems') AND name = 'CategoryName'
)
BEGIN
    ALTER TABLE [MenuItems] ADD [CategoryName] NVARCHAR(80) NULL;
    PRINT 'CategoryName sütunu eklendi.';
END
ELSE
    PRINT 'CategoryName zaten mevcut.';
GO

-- 2. CustomerOrders tablosu yoksa oluştur
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'CustomerOrders')
BEGIN
    CREATE TABLE [CustomerOrders] (
        [OrderId] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        [CustomerUserId] UNIQUEIDENTIFIER NOT NULL,
        [RestaurantId] UNIQUEIDENTIFIER NOT NULL,
        [Items] NVARCHAR(800) NOT NULL,
        [Total] INT NOT NULL,
        [DeliveryAddress] NVARCHAR(400) NOT NULL,
        [DeliveryAddressDetail] NVARCHAR(200) NULL,
        [CustomerLat] FLOAT NULL,
        [CustomerLng] FLOAT NULL,
        [RestaurantAddress] NVARCHAR(400) NULL,
        [RestaurantLat] FLOAT NULL,
        [RestaurantLng] FLOAT NULL,
        [CustomerName] NVARCHAR(120) NULL,
        [CustomerPhone] NVARCHAR(40) NULL,
        [Status] TINYINT NOT NULL,
        [CreatedAtUtc] DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX [IX_CustomerOrders_CustomerUserId] ON [CustomerOrders]([CustomerUserId]);
    CREATE INDEX [IX_CustomerOrders_RestaurantId] ON [CustomerOrders]([RestaurantId]);
    CREATE INDEX [IX_CustomerOrders_Status] ON [CustomerOrders]([Status]);
    PRINT 'CustomerOrders tablosu oluşturuldu.';
END
ELSE
    PRINT 'CustomerOrders zaten mevcut.';
GO
