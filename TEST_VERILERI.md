# Test Verileri – Vaveyla Uygulama

## Giriş Bilgileri

### Müşteri (Customer) – Adres ekleme / ödeme testi
| Alan | Değer |
|------|-------|
| **E-posta** | `musteri@vaveyla.com` |
| **Şifre** | `Test123!` |

### Restoran Sahipleri (Pastaneler)
| Restoran | E-posta | Şifre |
|----------|---------|-------|
| Mevlana Pastaneleri | `mevlana@vaveyla.com` | `Test123!` |
| Şar Pastanesi | `sar@vaveyla.com` | `Test123!` |
| Safran Pastanesi | `safran@vaveyla.com` | `Test123!` |

### Admin
| Alan | Değer |
|------|-------|
| **E-posta** | `admin@vaveyla.com` |
| **Şifre** | `Test123!` |

---

## Kupon Kodları
- `SAVE20` – %20 indirim, max 30 TL, min 100 TL sepet
- `FIXED50` – 50 TL sabit indirim, min 150 TL sepet

---

## Uygulamayı Çalıştırma

### 1. Backend API
```powershell
cd Vaveyla_4-master\backend\Vaveyla.Api
dotnet run
```
API: `http://localhost:5142`

### 2. Flutter Uygulaması
```powershell
cd Vaveyla_4-master
flutter pub get
flutter run
```

**Not:** Emülatör/cihaz için API adresi:
- Android emülatör: `http://10.0.2.2:5142`
- Fiziksel cihaz: `http://[BILGISAYAR_IP]:5142`

---

## Adres Test Senaryosu

1. **Giriş:** `musteri@vaveyla.com` / `Test123!`
2. **Sepete ürün ekle** (örn. Şar Pastanesi'nden)
3. **Sepet → Ödemeye Geç**
4. **Adresi değiştir** → **+** ile yeni adres ekle
5. **Adres ara** (örn. "Saraçlar Edirne")
6. **Onayla** → Adres başlığı seç (Ev/Ofis vb.), Adres Tarifi: `daire 12`
7. **Adresi Kaydet** → Hata almadan kaydedilmesi gerekir
8. **Uygula** ile seçili adresle devam et
