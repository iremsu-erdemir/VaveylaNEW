# Kupon ve Restoran İndirimi Test Rehberi

## 1. Ortam Hazırlığı

### Backend API'yi Başlat

```powershell
cd backend\Vaveyla.Api
dotnet run
```

- API: **http://localhost:5142** (veya çıktıda görünen port)
- Swagger: **http://localhost:5142/swagger**

### Flutter Uygulamasını Başlat

```powershell
cd Vaveyla_4-master  # proje kökü
flutter run
```

> **Not:** Emülatör/simülatör veya fiziksel cihaz kullanıyorsanız:
> - Android: `10.0.2.2:5142` API’ye erişir
> - iOS: `127.0.0.1:5142` veya bilgisayarınızın IP’si gerekebilir

---

## 2. Test Hesapları

| Rol | E-posta | Şifre |
|-----|---------|-------|
| **Admin** | admin@vaveyla.com | Test123! |
| **Restoran** | mevlana@vaveyla.com | Test123! |
| **Restoran** | sar@vaveyla.com | Test123! |
| **Müşteri** | Uygulamadan kayıt olun | - |

---

## 3. API ile Test (Postman / Swagger)

### 3.1 Token Alma

**POST** `/api/auth/login`

```json
{
  "email": "admin@vaveyla.com",
  "password": "Test123!"
}
```

Yanıttaki `token` değerini kopyalayın. Admin, restoran ve müşteri için ayrı token alabilirsiniz.

### 3.2 Admin - Müşteriye Kupon Ata

1. Admin ile giriş yapıp token alın.
2. **GET** `/api/admin/coupons/customers` → Müşteri listesi
3. **GET** `/api/admin/coupons` → Mevcut kuponlar (SAVE20, FIXED50)
4. **POST** `/api/admin/coupons/assign-to-customer`

```json
{
  "couponId": "<kupon-guid>",
  "customerUserId": "<müşteri-guid>"
}
```

Header: `Authorization: Bearer <admin-token>`

### 3.3 Müşteri - Kuponlarım

**GET** `/api/coupons/my?customerUserId=<müşteri-guid>`

### 3.4 Sepet Hesaplama (indirim çakışması)

**POST** `/api/customer/cart/calculate?customerUserId=<müşteri-guid>&userCouponId=<opsiyonel>`

- Kupon yok: Restoran indirimi uygulanır (varsa).
- Kupon var: Sadece kupon indirimi, restoran indirimi devre dışı.

### 3.5 Restoran İndirimi Onaylama / Reddetme

**GET** `/api/admin/restaurants/pending-discounts`  
**POST** `/api/admin/restaurants/<restaurantId>/approve-discount`  
**POST** `/api/admin/restaurants/<restaurantId>/reject-discount`

---

## 4. Flutter ile Manuel Test Senaryoları

### Senaryo A: Kupon Atama

1. **Müşteri hesabı:** Uygulamadan kayıt olun (roleId: 0 = Customer).
2. **Admin girişi:** admin@vaveyla.com ile giriş yapın.
3. Admin Panel → **Kupon Ata** → Müşteri ve kupon seçin → **Ata**.

### Senaryo B: Kuponlarım

1. Müşteri ile giriş yapın.
2. Profil → **Kuponlarım**.
3. Atanan kuponların göründüğünü kontrol edin.
4. Opsiyonel: Kupon kodu girip `apply-code` ile yeni kupon ekleyin.

### Senaryo C: Sepet – Sadece Restoran İndirimi

1. Restoran sahibi olarak **sar@vaveyla.com** ile giriş yapın.
2. Ayarlar → Restoran indirimi ekleyin (örn. %10) → Kaydet.
3. Admin Panel → **Restoran İndirimi Onayı** → Onayla.
4. Müşteri ile giriş yapın.
5. Şar Pastanesi’nden sepete ürün ekleyin (min. ~100 TL).
6. Sepette **restoran indirimi**nin uygulandığını kontrol edin.
7. **Kupon Seç**e tıklayın → Kupon seçin.
8. **“Kupon seçtiniz. Restoran indirimi uygulanmayacak...”** mesajının çıktığını kontrol edin.
9. Toplam tutarın sadece kupon indirimiyle hesaplandığını kontrol edin.

### Senaryo D: Sepet – Sadece Kupon (Restoran İndirimi Yok)

1. İndirimi olmayan bir restorandan sepete ürün ekleyin.
2. **Kupon Seç** → Kupon seçin (SAVE20: min 100 TL, FIXED50: min 150 TL).
3. Kupon indirimi hesaplamasını kontrol edin.

### Senaryo E: Sipariş ile Kupon Kullanımı

1. Sepete ürün ekleyin, kupon seçin.
2. **Ödemeye Geç** → Adres, ödeme → Sipariş verin.
3. Kuponun **Kullanıldı** olduğunu kontrol edin:
   - Profil → Kuponlarım
   - Admin Panel → Kupon Listesi

### Senaryo F: Restoran İndirimi Onay / Red

1. Restoran sahibi ile giriş → Ayarlar → İndirim oranı ekleyin.
2. Admin Panel → **Restoran İndirimi Onayı**.
3. **Onayla** ile indirimi onaylayın.
4. Yeni bir restoran indirimi oluşturup bu kez **Reddet** ile reddedin.

---

## 5. İndirim Çakışma Kuralları (Özet)

| Restoran indirimi | Kupon seçildi mi? | Sonuç |
|-------------------|-------------------|-------|
| Var | Hayır | Restoran indirimi uygulanır |
| Var | Evet | Sadece kupon uygulanır |
| Yok | Hayır | İndirim yok |
| Yok | Evet | Sadece kupon uygulanır |

---

## 6. Seed Kuponları

- **SAVE20:** %20 indirim, min 100 TL, max 30 TL
- **FIXED50:** 50 TL sabit indirim, min 150 TL sepet
