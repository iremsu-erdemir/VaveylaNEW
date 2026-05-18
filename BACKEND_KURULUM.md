# Backend Bağlantı Hatası Çözümü

**Hata:** `ClientException: Failed to fetch, uri=http://localhost:5142/api/auth/login`

Bu hata, Flutter uygulamasının backend API'ye ulaşamadığını gösterir.

## Adım 1: Backend'i Başlatın

1. Yeni bir terminal açın
2. Backend klasörüne gidin:
   ```
   cd backend\Vaveyla.Api
   ```
3. API'yi çalıştırın:
   ```
   dotnet run
   ```
4. "Now listening on: http://localhost:5142" mesajını görmelisiniz

## Adım 2: Veritabanı Migration'ları

İlk kez çalıştırıyorsanız:

```
cd backend\Vaveyla.Api
dotnet ef database update
```

## Adım 3: Flutter Uygulamasını Çalıştırın

Backend çalışırken Flutter uygulamasını başlatın:

```
flutter run -d chrome
```
veya
```
flutter run -d windows
```

## Kontrol

- Tarayıcıda http://localhost:5142/swagger açın – API çalışıyorsa Swagger sayfası açılır
- Giriş: tatli@vaveyla.com / Test123!

## Sorun Devam Ederse

- **Windows Firewall:** localhost bağlantılarına izin verildiğinden emin olun
- **Farklı port:** Backend farklı portta çalışıyorsa `launchSettings.json` içindeki `applicationUrl` değerini kontrol edin
