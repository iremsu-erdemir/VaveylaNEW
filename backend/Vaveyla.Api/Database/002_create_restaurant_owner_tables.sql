IF OBJECT_ID('dbo.Restaurants', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Restaurants (
        RestaurantId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        OwnerUserId UNIQUEIDENTIFIER NOT NULL,
        Name NVARCHAR(160) NOT NULL,
        Type NVARCHAR(120) NOT NULL,
        Address NVARCHAR(320) NOT NULL,
        Phone NVARCHAR(40) NOT NULL,
        WorkingHours NVARCHAR(60) NOT NULL,
        OrderNotifications BIT NOT NULL CONSTRAINT DF_Restaurants_OrderNotifications DEFAULT(1),
        IsOpen BIT NOT NULL CONSTRAINT DF_Restaurants_IsOpen DEFAULT(1),
        PhotoPath NVARCHAR(512) NULL,
        CreatedAtUtc DATETIME2 NOT NULL CONSTRAINT DF_Restaurants_CreatedAtUtc DEFAULT (SYSUTCDATETIME())
    );
    CREATE UNIQUE INDEX IX_Restaurants_OwnerUserId ON dbo.Restaurants(OwnerUserId);
END

IF OBJECT_ID('dbo.MenuItems', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.MenuItems (
        MenuItemId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        RestaurantId UNIQUEIDENTIFIER NOT NULL,
        Name NVARCHAR(160) NOT NULL,
        Price INT NOT NULL,
        ImagePath NVARCHAR(512) NOT NULL,
        IsAvailable BIT NOT NULL CONSTRAINT DF_MenuItems_IsAvailable DEFAULT(1),
        IsFeatured BIT NOT NULL CONSTRAINT DF_MenuItems_IsFeatured DEFAULT(0),
        CreatedAtUtc DATETIME2 NOT NULL CONSTRAINT DF_MenuItems_CreatedAtUtc DEFAULT (SYSUTCDATETIME())
    );
    CREATE INDEX IX_MenuItems_RestaurantId ON dbo.MenuItems(RestaurantId);
    ALTER TABLE dbo.MenuItems WITH CHECK
        ADD CONSTRAINT FK_MenuItems_Restaurants
        FOREIGN KEY (RestaurantId) REFERENCES dbo.Restaurants(RestaurantId);
END

IF OBJECT_ID('dbo.RestaurantOrders', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.RestaurantOrders (
        OrderId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        RestaurantId UNIQUEIDENTIFIER NOT NULL,
        Items NVARCHAR(600) NOT NULL,
        Total INT NOT NULL,
        Status TINYINT NOT NULL,
        CreatedAtUtc DATETIME2 NOT NULL CONSTRAINT DF_RestaurantOrders_CreatedAtUtc DEFAULT (SYSUTCDATETIME())
    );
    CREATE INDEX IX_RestaurantOrders_RestaurantId ON dbo.RestaurantOrders(RestaurantId);
    ALTER TABLE dbo.RestaurantOrders WITH CHECK
        ADD CONSTRAINT FK_RestaurantOrders_Restaurants
        FOREIGN KEY (RestaurantId) REFERENCES dbo.Restaurants(RestaurantId);
END

IF OBJECT_ID('dbo.RestaurantReviews', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.RestaurantReviews (
        ReviewId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        RestaurantId UNIQUEIDENTIFIER NOT NULL,
        CustomerName NVARCHAR(120) NOT NULL,
        Rating TINYINT NOT NULL,
        Comment NVARCHAR(800) NOT NULL,
        OwnerReply NVARCHAR(800) NULL,
        CreatedAtUtc DATETIME2 NOT NULL CONSTRAINT DF_RestaurantReviews_CreatedAtUtc DEFAULT (SYSUTCDATETIME())
    );
    CREATE INDEX IX_RestaurantReviews_RestaurantId ON dbo.RestaurantReviews(RestaurantId);
    ALTER TABLE dbo.RestaurantReviews WITH CHECK
        ADD CONSTRAINT FK_RestaurantReviews_Restaurants
        FOREIGN KEY (RestaurantId) REFERENCES dbo.Restaurants(RestaurantId);
END
