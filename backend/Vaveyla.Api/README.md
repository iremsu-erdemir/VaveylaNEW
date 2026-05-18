# Vaveyla API

## Gmail SMTP — şifre sıfırlama

Doğrulama kodu **yalnızca SMTP başarılı olduğunda** gönderilir ve veritabanına yazılır. SMTP başarısızsa API hata döner; kullanıcıya “kod gönderildi” denmez.

### Config dosyaları (yüklenme sırası)

| Dosya | Rol |
|-------|-----|
| `appsettings.json` | Temel ayarlar (her ortam) |
| `appsettings.Development.json` | `dotnet run` ile Development override |
| User Secrets | Hassas `Username` / `Password` (repoya yazmayın) |
| Ortam değişkenleri | Production (`Email__Password` vb.) |

Örnek şablon: `appsettings.example.json`

Backend başlarken terminalde **hangi kaynakların** yüklendiği ve SMTP alanlarının dolu/boş durumu loglanır (şifre loglanmaz).

### Kurulum adımları

1. [Google Hesap → Güvenlik](https://myaccount.google.com/security) → **2 adımlı doğrulama** açın.
2. [Uygulama şifresi](https://myaccount.google.com/apppasswords) oluşturun (16 karakter).
3. `Vaveyla.Api` klasöründe User Secrets (önerilen):

```powershell
cd backend\Vaveyla.Api
dotnet user-secrets set "Email:Username" "sizin@gmail.com"
dotnet user-secrets set "Email:Password" "xxxx xxxx xxxx xxxx"
dotnet user-secrets set "Email:FromAddress" "sizin@gmail.com"
dotnet user-secrets set "Email:FromName" "Vaveyla"
```

4. `appsettings.Development.json` içinde Gmail host/port kalabilir; kimlik bilgilerini repoya yazmayın.

5. API’yi başlatın ve logları kontrol edin:

```powershell
dotnet run
```

`Password=DOLU` ve `SMTP yapılandırması eksik` uyarısı **olmamalı**.

6. **Gerçek Gmail** ile kayıtlı bir hesapta şifre sıfırlamayı deneyin; gelen kutusu + **Spam** klasörünü kontrol edin.

### Gmail ayarları

| Alan | Değer |
|------|--------|
| SmtpHost | `smtp.gmail.com` |
| SmtpPort | `587` |
| EnableSsl | `true` |
| Username | Gmail adresiniz |
| FromAddress | Aynı Gmail adresi |
| Password | Google uygulama şifresi (boşluklar otomatik temizlenir) |

### Test hesapları (@vaveyla.com)

`musteri@vaveyla.com`, `mevlana@vaveyla.com` vb. adresler **yalnızca veritabanı seed kayıtlarıdır**; gerçek posta kutusu yoktur. Bu adreslere mail **gelmez**. Test için:

- Gerçek Gmail ile kayıt olun, veya
- Veritabanında test kullanıcısının e-postasını kendi Gmail’inizle güncelleyin.

### Production

Tüm `Email` alanlarını ortam değişkenleri veya güvenli secret store ile sağlayın:

- `Email__Username`
- `Email__Password`
- `Email__FromAddress`
- `Email__SmtpHost`
- `Email__SmtpPort`

SMTP hatalıysa API `503`/`500` döner; kod veritabanına yazılmaz.

### API

Varsayılan: `http://localhost:5142`
