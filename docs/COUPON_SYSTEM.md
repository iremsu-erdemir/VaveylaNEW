# Kupon ve İndirim Sistemi

## Genel Özet

Trendyol benzeri kupon ve restoran indirim sistemi.

## Akış Özeti

- **Admin** müşterilere kupon atayabilir (Kupon Ata)
- **Restoranlar** yüzde indirim ekleyebilir; admin onayından sonra müşteriye yansır
- **Müşteri** "Özel Teklifler → Tümünü Gör" ile kuponları ve restoran indirimlerini görür
- **Yüzde indirime tıklanınca** sadece o indirime sahip restoranlar listelenir
- **Restoranın indirimli ürünü sepete eklenince** indirim otomatik uygulanır
- **Kupon seçilince** sepetteki tüm ürünlere kupon indirimi uygulanır
- **Restoran indirimi** pasif yapılana kadar devam eder
- **Kuponlar** tek kullanımlıktır

---

## Veritabanı Şeması

### Tablolar

**Coupons**
| Alan | Tip | Açıklama |
|------|-----|----------|
| CouponId | uniqueidentifier PK | |
| Code | nvarchar(32) UNIQUE | Kupon kodu (örn: SAVE20) |
| Description | nvarchar(400) | |
| DiscountType | int | 1=Yüzde, 2=Sabit |
| DiscountValue | decimal(18,2) | İndirim değeri |
| MinCartAmount | decimal(18,2) | Minimum sepet tutarı |
| MaxDiscountAmount | decimal(18,2) | Maksimum indirim limiti |
| ExpiresAtUtc | datetime2 | Son kullanma |
| RestaurantId | uniqueidentifier | null=global, dolu=restoran özel |
| CreatedAtUtc | datetime2 | |

**UserCoupons**
| Alan | Tip | Açıklama |
|------|-----|----------|
| UserCouponId | uniqueidentifier PK | |
| UserId | uniqueidentifier FK | |
| CouponId | uniqueidentifier FK | |
| Status | int | 1=Pending, 2=Approved, 3=Used, 4=Expired |
| UsedAtUtc | datetime2 | |
| OrderId | uniqueidentifier | Kullanıldığı sipariş |
| CreatedAtUtc | datetime2 | |

**Restaurants** (ek alan)
| Alan | Tip | Açıklama |
|------|-----|----------|
| RestaurantDiscountPercent | decimal(5,2) | 0-100, restoranın tüm ürünlere uyguladığı % indirim |

**CustomerOrders** (ek alanlar)
| Alan | Tip | Açıklama |
|------|-----|----------|
| AppliedUserCouponId | uniqueidentifier | |
| CouponDiscountAmount | decimal(18,2) | |

---

## API Endpoints

### Kullanıcı

| Method | Endpoint | Açıklama |
|--------|----------|----------|
| POST | /api/coupons/apply-code?customerUserId= | Kupon kodu gir, cüzdana ekle |
| GET | /api/coupons/my?customerUserId= | Kuponlarım listesi |
| POST | /api/customer/cart/calculate?customerUserId=&userCouponId= | Sepet hesapla (opsiyonel kupon) |
| POST | /api/customer/orders?customerUserId= | Sipariş oluştur (body: userCouponId opsiyonel) |

### Admin

| Method | Endpoint | Açıklama |
|--------|----------|----------|
| GET | /api/admin/coupons/pending | Onay bekleyen kuponlar |
| POST | /api/admin/coupons/{id}/approve | Kuponu onayla |
| POST | /api/admin/coupons | Yeni kupon oluştur |

### Restoran Sahibi

| Method | Endpoint | Açıklama |
|--------|----------|----------|
| PUT | /api/owner/settings | Body: restaurantDiscountPercent (0-100) |

---

## Örnek Request/Response

### POST /api/coupons/apply-code
**Request:**
```json
{
  "code": "SAVE20"
}
```

**Response (200):**
```json
{
  "userCouponId": "guid",
  "code": "SAVE20",
  "message": "Kupon cüzdanınıza eklendi. Hemen kullanabilirsiniz."
}
```

### GET /api/coupons/my
**Response (200):**
```json
[
  {
    "userCouponId": "guid",
    "couponId": "guid",
    "code": "SAVE20",
    "description": "%20 indirim, max 30 TL",
    "discountType": 1,
    "discountValue": 20,
    "minCartAmount": 100,
    "maxDiscountAmount": 30,
    "expiresAtUtc": "2025-06-23T00:00:00Z",
    "restaurantId": null,
    "status": "approved",
    "usedAtUtc": null
  }
]
```

### POST /api/customer/cart/calculate (yeni alanlar)
**Response (200) - Restoran indirimi varken:**
```json
{
  "items": [...],
  "totalPrice": 200,
  "totalDiscount": 20,
  "finalPrice": 180,
  "hasRestaurantDiscount": true,
  "restaurantDiscountAmount": 20,
  "canUseCoupon": false,
  "couponDiscountAmount": 0
}
```

**Response (200) - Kupon uygulanmış:**
```json
{
  "items": [...],
  "totalPrice": 200,
  "totalDiscount": 30,
  "finalPrice": 170,
  "hasRestaurantDiscount": false,
  "restaurantDiscountAmount": 0,
  "canUseCoupon": true,
  "couponDiscountAmount": 30,
  "appliedUserCouponId": "guid"
}
```

---

## İş Kuralları

1. **Restoran indirimi vs kupon:** Varsayılan olarak restoran indirimi uygulanır. Kupon seçilirse restoran indirimi atlanır, sadece kupon indirimi uygulanır (bilgi mesajı gösterilir) – Backend ve frontend’de kontrol edilir.
2. **Kupon akışı:** Kullanıcı kodu girer → UserCoupon doğrudan Approved → Kullanılabilir (admin onayı yok).
3. **Bir siparişte sadece 1 kupon** – UI ve backend ile zorunlu tutulur.
4. **Kupon kullanıldıktan sonra tekrar kullanılamaz** – Status=Used.
5. **Minimum sepet tutarı** – MinCartAmount kontrolü yapılır.
6. **Maksimum indirim limiti** – Yüzde kuponlarda MaxDiscountAmount ile sınırlanır.

---

## İndirim Hesaplama Sırası

1. **Restoran indirimi varsa, kupon seçilmemişse** → Sadece restoran indirimi uygulanır.
2. **Restoran indirimi varsa, kupon seçilmişse** → Restoran indirimi atlanır, sadece kupon uygulanır.
3. **Restoran indirimi yoksa** → Kampanyalar + (opsiyonel) Kupon uygulanır.

### Örnek
- Sepet: 200 TL, Restoran indirimi %10 → 180 TL, kupon kullanılamaz.
- Sepet: 200 TL, Restoran indirimi yok, Kupon %20 (max 30 TL) → 160 TL.

---

## Seed Verileri

Uygulama başlarken otomatik eklenen kuponlar:
- **SAVE20**: %20 indirim, min 100 TL sepet, max 30 TL
- **FIXED50**: 50 TL sabit indirim, min 150 TL sepet

---

## Flutter Ekranları

- **Kuponlarım** – Profil > Kuponlarım
- **Kupon Seç** – Sepet ekranında "Kupon Seç" butonu
- **Admin Kupon Onayları** – Admin Panel > Kupon Onayları
