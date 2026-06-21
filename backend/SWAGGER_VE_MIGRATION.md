# Swagger "Failed to load API definition" Çözümü

## Yapılan Düzeltmeler

1. **Swagger hatası:** `IFormFile` kullanan upload endpoint'leri Swagger'dan çıkarıldı (API çalışmaya devam ediyor).
2. **Veritabanı:** `CategoryName` sütunu eklenmeli.

## Adımlar

### 1. Backend'i Durdurun
Çalışan backend terminalinde **Ctrl+C** ile durdurun.

### 2. Migration'ları Uygulayın
```powershell
cd backend\Vaveyla.Api
dotnet ef database update
```

### 3. Backend'i Yeniden Başlatın
```powershell
dotnet run
```

### 4. Swagger'ı Kontrol Edin
Tarayıcıda http://localhost:5142/swagger açın. Artık çalışmalı.

---

**Alternatif (Migration çalışmazsa):** SQL Server Management Studio veya sqlcmd ile:

```sql
ALTER TABLE MenuItems ADD CategoryName NVARCHAR(80) NULL;
```

(CustomerOrders tablosu yoksa `dotnet ef database update` gerekli.)
