# Restoran Kampanya + Kupon Sistemi - Dokümantasyon

## 1. Sistem Genel Mantığı

### İndirim Türleri

| Tür | Oluşturan | Onay | Sepette |
|-----|-----------|------|---------|
| **Restoran Kampanyası** | Restoran | Admin onayı | Otomatik uygulanır |
| **Kupon** | Admin (müşteriye atar) | Direkt onaylı | Müşteri manuel seçer |

### Kritik Kural: Tek İndirim
- Kupon seçilirse → Restoran indirimi iptal, sadece kupon uygulanır
- Kupon seçilmezse → Restoran kampanyası otomatik uygulanır

---

## 2. Restoran Kampanya Modülü

### Entity Yapısı
Basit "%X indirim" kampanyaları **Restaurant** entity'sinde tutulur:
- `RestaurantDiscountPercent` (0-100)
- `RestaurantDiscountApproved` (Admin onayı)
- `RestaurantDiscountIsActive` (Restoran aktif/pasif toggle)

Karmaşık kampanyalar (ürün/kategori bazlı) **Campaign** tablosunda.

### Kurallar
1. Restoran kampanya oluşturur → Admin onayına düşer
2. Admin onaylar (`RestaurantDiscountApproved = true`) → Aktif olur
3. Admin reddeder → Pasif kalır
4. Restoran `RestaurantDiscountIsActive` ile aç/kapa yapabilir (onaylıysa)
5. **Aynı restoran aynı anda SADECE 1 aktif kampanya** (validasyon mevcut)

### API Endpoints
| Endpoint | Açıklama |
|----------|----------|
| `POST api/restaurant/campaigns` | Kampanya oluştur |
| `PUT api/restaurant/settings/discount/toggle` | Aktif/Pasif toggle |
| `PUT api/admin/restaurants/{id}/approve-restaurant-discount` | Admin onay |

---

## 3. Kupon Sistemi

### Entity: UserCoupon
```csharp
// Her atama = yeni satır (INSERT). Aynı kupon tekrar atanabilir.
UserCouponId, UserId, CouponId, Status, UsedAtUtc, OrderId, CreatedAtUtc
```

### Kurallar
- Admin → Kullanıcıya kupon atar
- Kupon sadece atanmış kullanıcı tarafından görülebilir
- **1 kez kullanılabilir** (Status = Used sonrası)
- **Aynı kupon tekrar atanabilir** → Her atama yeni `UserCoupon` kaydı (INSERT)
- ❌ UPDATE existing coupon yasak

### Veritabanı
- `IX_UserCoupons_UserId_CouponId` **non-unique** (çoklu atama için)
- Her atama benzersiz `UserCouponId` ile yeni satır

### API Endpoints
| Endpoint | Açıklama |
|----------|----------|
| `POST api/admin/coupons/assign-to-customer` | Admin kupon atar |
| `GET api/coupons/my` | Kullanıcının kuponları |
| `POST api/coupons/apply-code` | Kupon kodu ile cüzdana ekleme |

---

## 4. Sepet İndirim Mantığı

### Backend: CartCalculationService
```
if (userCouponId seçildi && customerUserId var)
    → CalculateWithCouponOnly (restoran indirimi atlanır)
else if (restoran indirimi var)
    → CalculateWithRestaurantDiscountOnly
else
    → CalculateWithCouponOrNoDiscountAsync
```

### Response Alanları
- `hasRestaurantDiscount` - Restoran indirimi uygulandı mı
- `hasRestaurantDiscountSkippedForCoupon` - Kupon seçildiği için restoran indirimi atlandı
- `canUseCoupon` - Kupon seçilebilir mi (her zaman true - seçilirse restoran iptal)
- `appliedUserCouponId` - Uygulanan kupon ID

---

## 5. Flutter (Frontend)

### Müşteri Sepeti
- **CartScreen**: Kampanya otomatik görünür, "Kupon Seç" butonu
- **CouponSelectScreen**: Sadece `status == 'approved'` kuponlar seçilebilir
- Kupon seçilince → `selectCoupon(userCouponId)` → `loadCart()` → Yeni fiyat

### Admin Panel
- Kampanya onay: `api/admin/restaurants/{id}/approve-restaurant-discount`
- Kupon atama: `api/admin/coupons/assign-to-customer`

### Restoran Panel
- Kampanya oluşturma: `api/restaurant/campaigns`
- Aktif/Pasif toggle: `api/restaurant/settings/discount/toggle`

---

## 6. Bug Önleme (Yapılan Düzeltmeler)

| Sorun | Çözüm |
|-------|-------|
| Unique constraint (UserId+CouponId) | Migration ile kaldırıldı - aynı kupon tekrar atanabilir |
| HasActiveUserCoupon atama engeli | Admin AssignToCustomer'dan kaldırıldı - her zaman INSERT |
| GetUserCouponAsync çoklu instance | OrderByDescending(CreatedAtUtc) - en son atanan döner |
| Sepet çakışması | Tek indirim kuralı - kupon seçilince restoran iptal |

---

## 7. Mimari

- **Service + Repository** pattern
- **CartCalculationService** - Sepet hesaplama
- **CouponService** - Kupon işlemleri (apply, calculate, mark used)
- **CampaignRepository**, **CouponRepository** - Veri erişimi
