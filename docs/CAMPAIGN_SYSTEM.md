# Kampanya Yönetim Sistemi

Bu doküman, Vaveyla pastane projesine eklenen kampanya yönetim sisteminin teknik özetini içerir.

## Veritabanı (MSSQL)

### Campaigns Tablosu
- `CampaignId` (Guid, PK)
- `Name`, `Description`
- `DiscountType` (1: Yüzde, 2: Sabit)
- `DiscountValue`
- `TargetType` (1: Ürün, 2: Kategori, 3: Sepet)
- `TargetId`, `TargetCategoryName` (kategori için)
- `MinCartAmount` (sepet kampanyaları için)
- `IsActive`, `Status` (Pending, Active, Rejected)
- `DiscountOwner` (1: Restoran, 2: Platform)
- `RestaurantId` (null = global kampanya)
- `StartDate`, `EndDate`, `CreatedAtUtc`

### Users Tablosu
- `Role` enum'a **Admin** (4) eklendi

### Restaurants Tablosu
- `CommissionRate` (varsayılan %10)
- `IsEnabled` (aktif/pasif)

### CustomerOrders Tablosu
- `TotalDiscount`, `RestaurantEarning`, `PlatformEarning`

## JWT Yetkilendirme

- Login ve Register cevabında `token` alanı döner.
- Admin ve Restaurant API'leri `Authorization: Bearer {token}` header'ı ile korunur.
- `appsettings.json` içinde Jwt:Key, Issuer, Audience, ExpiryMinutes yapılandırılır.
- Production'da Jwt:Key mutlaka güçlü ve gizli tutulmalıdır.

## Backend API

### CalculateCart
- **POST** `/api/customer/cart/calculate?customerUserId={id}`
- Sepeti veritabanından alır, kampanyaları uygular
- Response: `items`, `totalPrice`, `totalDiscount`, `finalPrice`, `customerPaidAmount`, `restaurantEarning`, `platformEarning`

### Admin API (JWT Bearer token ile)
- `GET /api/admin/campaigns` - Tüm kampanyalar
- `POST /api/admin/campaigns` - Global kampanya oluştur
- `PUT /api/admin/campaigns/{id}/approve` - Onayla
- `PUT /api/admin/campaigns/{id}/reject` - Reddet
- `PUT /api/admin/campaigns/{id}/deactivate` - Devre dışı
- `GET /api/admin/restaurants` - Restoran listesi
- `PUT /api/admin/restaurants/{id}/toggle-status` - Aktif/pasif
- `PUT /api/admin/restaurants/{id}/set-commission` - Komisyon oranı
- `GET /api/admin/orders` - Sipariş listesi
- `GET /api/admin/orders/{id}` - Sipariş detay (finansal alanlar dahil)

### Restaurant API (JWT Bearer token ile)
- `GET /api/restaurant/campaigns` - Restoran kampanyaları
- `POST /api/restaurant/campaigns` - Kampanya oluştur (Status=Pending)
- `PUT /api/restaurant/campaigns/{id}` - Güncelle
- `DELETE /api/restaurant/campaigns/{id}` - Sil

### Kampanya Listesi (müşteri)
- `GET /api/campaigns/active?restaurantId={opsiyonel}` - Aktif kampanyalar

## Flutter

### Sepet
- `CartCubit.loadCart()` → `CalculateCart` API çağrısı
- `CartLoaded`: `totalDiscount`, `finalPrice`, item bazlı `originalLinePrice`, `discountedLinePrice`
- Sepet ekranında üstü çizili eski fiyat, indirimli fiyat, "Kazancınız: X ₺" gösterimi

### Özel Teklifler
- `SpecialOffers` ekranı API'den kampanyaları çeker
- Kategori kampanyasına tıklanınca ilgili kategoriye yönlendirir

### Admin Panel
- Giriş: `admin@vaveyla.com` / `Test123!`
- Kampanya yönetimi, restoran yönetimi, sipariş/finans dashboard

### Restoran Panel
- Dashboard'da "Kampanyalar" kartı
- Kampanya oluşturma formu (indirim tipi, hedef, tarih)
- Pending / Active / Rejected ayrımı

### Kurye Panel
- Sipariş kartında "Hakediş Özeti": Müşteri Ödemesi, İndirim, Restoran Hakedişi

## Migration

```bash
cd backend/Vaveyla.Api
dotnet ef database update
```

## Hakediş Mantığı

- **DiscountOwner = Restaurant**: İndirim restoranın kazancından düşülür
- **DiscountOwner = Platform**: Restoran tam fiyat üzerinden kazanır, platform indirimi karşılar
- Komisyon oranı (Restaurant.CommissionRate) üzerinden `RestaurantEarning` ve `PlatformEarning` hesaplanır
