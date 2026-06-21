# "Failed to fetch" Bağlantı Hatası Çözümü

## 1. Backend'i Başlatın (ÖNCE BU!)

**PowerShell'de:**
```powershell
.\start_backend.ps1
```
veya
```powershell
cd backend\Vaveyla.Api
dotnet run
```

**"Now listening on: http://localhost:5142"** görünene kadar bekleyin.

## 2. Veritabanı (İlk Kez veya "Invalid column name 'CategoryName'" hatası)

**Seçenek A - SQL script (Backend çalışırken):**
```powershell
sqlcmd -S "(localdb)\MSSQLLocalDB" -d VaveylaDb_Initial -E -i backend\Vaveyla.Api\apply_migrations.sql
```
Sonra backend'i yeniden başlatın.

**Seçenek B - EF migration (Backend kapalıyken):**
```powershell
cd backend\Vaveyla.Api
dotnet ef database update
```

## 3. Flutter Web CORS Sorunu

Chrome bazen CORS nedeniyle engelleyebilir. Şunu deneyin:

```powershell
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

## 4. Windows/MacOS Masaüstü (CORS yok)

```powershell
flutter run -d windows
```

## 5. Kontrol

Tarayıcıda **http://localhost:5142/swagger** açın. Sayfa açılıyorsa API çalışıyordur.

## Giriş Bilgileri

Müşteri paneli ve pastane paneli için detaylı giriş bilgileri:
- **Pastane paneli (satıcılar):** [SATICI_GIRIS_BILGILERI.md](SATICI_GIRIS_BILGILERI.md)
- **Örnek:** mevlana@vaveyla.com / Test123! (Mevlana Pastaneleri - Edirne)
