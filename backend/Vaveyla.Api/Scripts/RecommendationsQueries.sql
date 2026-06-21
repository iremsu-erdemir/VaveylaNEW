/*
  Vaveyla öneri motoru — MSSQL sorguları (normalize şema + mevcut şema notları).
  Parametreler: @UserId uniqueidentifier, @RecentDays int = 30
*/

SET NOCOUNT ON;

DECLARE @UserId UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000'; /* örnek */
DECLARE @RecentDays INT = 30;
DECLARE @RecentFromUtc DATETIME2(0) = DATEADD(DAY, -@RecentDays, SYSUTCDATETIME());

/* =============================================================================
   1) NORMALİZE ŞEMA (Orders + OrderItems + Products) — üretim için önerilen
   ============================================================================= */

/* 1a) Genel en çok satılan ürünler (teslim / tamamlandı) */
/*
SELECT TOP (50)
    p.ProductId,
    p.Name AS ProductName,
    p.CategoryId,
    SUM(oi.Quantity) AS TotalQty,
    COUNT(DISTINCT o.OrderId) AS OrderCount
FROM dbo.OrderItems AS oi
INNER JOIN dbo.Orders AS o ON o.OrderId = oi.OrderId
INNER JOIN dbo.Products AS p ON p.ProductId = oi.ProductId
WHERE o.Status IN (N'Delivered', N'Completed')
GROUP BY p.ProductId, p.Name, p.CategoryId
ORDER BY TotalQty DESC, OrderCount DESC;
*/

/* 1b) Kullanıcının en çok aldığı ürünler */
/*
SELECT TOP (30)
    p.ProductId,
    p.Name AS ProductName,
    SUM(oi.Quantity) AS UserTotalQty,
    MAX(o.CreatedAtUtc) AS LastOrderedAtUtc
FROM dbo.OrderItems AS oi
INNER JOIN dbo.Orders AS o ON o.OrderId = oi.OrderId
INNER JOIN dbo.Products AS p ON p.ProductId = oi.ProductId
WHERE o.UserId = @UserId
  AND o.Status IN (N'Delivered', N'Completed')
GROUP BY p.ProductId, p.Name
ORDER BY UserTotalQty DESC;
*/

/* 1c) Trend: son @RecentDays gün içinde en çok satılan ürünler */
/*
SELECT TOP (50)
    p.ProductId,
    p.Name AS ProductName,
    SUM(oi.Quantity) AS RecentQty
FROM dbo.OrderItems AS oi
INNER JOIN dbo.Orders AS o ON o.OrderId = oi.OrderId
INNER JOIN dbo.Products AS p ON p.ProductId = oi.ProductId
WHERE o.Status IN (N'Delivered', N'Completed')
  AND o.CreatedAtUtc >= @RecentFromUtc
GROUP BY p.ProductId, p.Name
ORDER BY RecentQty DESC;
*/

/* 1d) Kullanıcı + ürün recency (son sipariş tarihi) — skor “recency” bileşeni */
/*
SELECT
    p.ProductId,
    p.Name AS ProductName,
    SUM(oi.Quantity) AS UserTotalQty,
    MAX(o.CreatedAtUtc) AS LastOrderedAtUtc
FROM dbo.OrderItems AS oi
INNER JOIN dbo.Orders AS o ON o.OrderId = oi.OrderId
INNER JOIN dbo.Products AS p ON p.ProductId = oi.ProductId
WHERE o.UserId = @UserId
  AND o.Status IN (N'Delivered', N'Completed')
GROUP BY p.ProductId, p.Name;
*/

/* 1e) Saat / gün filtresi için ham sipariş zamanı (uygulama İstanbul TZ’ye çevirir) */
/*
SELECT
    o.OrderId,
    o.CreatedAtUtc,
    DATEPART(HOUR, o.CreatedAtUtc) AS HourUtc
FROM dbo.Orders AS o
WHERE o.UserId = @UserId
  AND o.Status IN (N'Delivered', N'Completed')
ORDER BY o.CreatedAtUtc DESC;
*/

/* =============================================================================
   2) VAVEYLA MEVCUT ŞEMA (CustomerOrders.Items nvarchar)
   =============================================================================
   Ürün satırları tek metinde tutulduğu için doğru ölçeklenebilir analiz için
   CustomerOrderLines(MenuItemId, Quantity, ...) tablosuna geçiş önerilir.
   Aşağıdaki sorgular indeksli kolonlar üzerinden “ham” veriyi verir; eşleme C#’ta.
*/

/* İndeks önerisi (yoksa ekleyin): */
/*
CREATE NONCLUSTERED INDEX IX_CustomerOrders_Delivered_Created
ON dbo.CustomerOrders (Status, CreatedAtUtc)
INCLUDE (CustomerUserId, RestaurantId, Items);
*/

/* 2a) Öneri motorunun tek geçişte okuyacağı teslim siparişleri (hafif projection) */
SELECT
    co.CustomerUserId,
    co.RestaurantId,
    co.Items,
    co.CreatedAtUtc
FROM dbo.CustomerOrders AS co
WHERE co.Status = 5 /* Delivered */
ORDER BY co.CreatedAtUtc DESC;

/* 2b) Son N gün teslim siparişleri (trend / popülerlik alt kümesi) */
SELECT
    co.CustomerUserId,
    co.RestaurantId,
    co.Items,
    co.CreatedAtUtc
FROM dbo.CustomerOrders AS co
WHERE co.Status = 5
  AND co.CreatedAtUtc >= @RecentFromUtc;

/* 2c) Belirli müşterinin teslim siparişleri (kullanıcı affinitesi) */
SELECT
    co.RestaurantId,
    co.Items,
    co.CreatedAtUtc
FROM dbo.CustomerOrders AS co
WHERE co.Status = 5
  AND co.CustomerUserId = @UserId
ORDER BY co.CreatedAtUtc DESC;

/* 2d) Menü (restoran başına eşleştirme) */
SELECT
    mi.MenuItemId,
    mi.RestaurantId,
    mi.Name,
    mi.CategoryName,
    mi.IsAvailable
FROM dbo.MenuItems AS mi
WHERE mi.IsAvailable = 1;

/* =============================================================================
   3) İNDEKSLER (Vaveyla — EF migration ile de uygulanır)
   ============================================================================= */

/*
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_CustomerOrders_CustomerUserId_Status_CreatedAtUtc' AND object_id = OBJECT_ID(N'dbo.CustomerOrders'))
CREATE NONCLUSTERED INDEX IX_CustomerOrders_CustomerUserId_Status_CreatedAtUtc
ON dbo.CustomerOrders (CustomerUserId, Status, CreatedAtUtc);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_CustomerOrders_Status_CreatedAtUtc' AND object_id = OBJECT_ID(N'dbo.CustomerOrders'))
CREATE NONCLUSTERED INDEX IX_CustomerOrders_Status_CreatedAtUtc
ON dbo.CustomerOrders (Status, CreatedAtUtc);
*/

/* Normalize şema hedefi (OrderItems tablosu varsa): */
/*
CREATE NONCLUSTERED INDEX IX_Orders_UserId_Status_CreatedAtUtc
ON dbo.Orders (UserId, Status, CreatedAtUtc);

CREATE NONCLUSTERED INDEX IX_OrderItems_ProductId
ON dbo.OrderItems (ProductId);
*/
