# Notification Module Guide

Bu döküman, projeye eklenen bildirim modülünün nasıl çalıştığını ve push/realtime entegrasyonunun nasıl tamamlanacağını özetler.

## Backend Bileşenleri

- Entity modelleri:
  - `backend/Vaveyla.Api/Models/Notification.cs`
  - `backend/Vaveyla.Api/Models/NotificationDtos.cs`
- Repository:
  - `backend/Vaveyla.Api/Data/NotificationRepository.cs`
- Service katmanı:
  - `backend/Vaveyla.Api/Services/NotificationService.cs`
  - `backend/Vaveyla.Api/Services/IPushNotificationSender.cs`
  - `backend/Vaveyla.Api/Services/NoopPushNotificationSender.cs`
- Realtime Hub:
  - `backend/Vaveyla.Api/Hubs/NotificationHub.cs`
- API:
  - `backend/Vaveyla.Api/Controllers/NotificationsController.cs`

## Endpointler

- `GET /api/notifications?userId={id}&page=1&pageSize=20&isRead=false`
- `GET /api/notifications/unread-count?userId={id}`
- `PUT /api/notifications/{notificationId}/read?userId={id}`
- `PUT /api/notifications/read-all?userId={id}`
- `POST /api/notifications/device-token`
- `POST /api/notifications/send` (manuel/test amaçlı)
- SignalR Hub: `GET/WS /hubs/notifications`

## Otomatik Tetiklenen Senaryolar

- Müşteri:
  - Sipariş oluşturuldu
  - Sipariş hazırlanıyor
  - Kurye yola çıktı
  - Sipariş teslim edildi
- Pastane sahibi:
  - Yeni sipariş geldi
  - Sipariş iptal edildi
  - Kurye siparişi teslim aldı
- Kurye:
  - Yeni teslimat görevi
  - Sipariş hazır
  - Teslimat tamamlandı

Bu tetikler:
- `CustomerOrdersController` (sipariş oluşturma),
- `RestaurantOwnerController` (sipariş durum güncelleme),
- `CourierController` (kurye kabul/durum güncelleme)
içine bağlanmıştır.

## FCM Push Entegrasyonu (Backend Örnek)

Varsayılan olarak `NoopPushNotificationSender` kayıtlıdır. Üretimde bunu gerçek FCM sender ile değiştirin.

```csharp
public sealed class FcmPushNotificationSender : IPushNotificationSender
{
    private readonly HttpClient _httpClient;
    private readonly string _serverKey;

    public FcmPushNotificationSender(IConfiguration configuration, HttpClient httpClient)
    {
        _httpClient = httpClient;
        _serverKey = configuration["Fcm:ServerKey"] ?? throw new InvalidOperationException("Missing Fcm:ServerKey");
    }

    public async Task SendAsync(string deviceToken, PushMessage message, CancellationToken cancellationToken)
    {
        var payload = new
        {
            to = deviceToken,
            notification = new { title = message.Title, body = message.Body },
            data = message.Data ?? new Dictionary<string, string>()
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, "https://fcm.googleapis.com/fcm/send");
        request.Headers.TryAddWithoutValidation("Authorization", $"key={_serverKey}");
        request.Content = new StringContent(
            System.Text.Json.JsonSerializer.Serialize(payload),
            System.Text.Encoding.UTF8,
            "application/json");

        var response = await _httpClient.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();
    }
}
```

`Program.cs` içinde kayıt:

```csharp
builder.Services.AddHttpClient<IPushNotificationSender, FcmPushNotificationSender>();
```

## Flutter: Bildirim Alma Akışı

Projede API geçmişini okuyan ekran ve servis eklendi:
- `lib/core/services/remote_notification_service.dart`
- `lib/features/home_feature/presentation/screens/notifications_screen.dart`
- Zil ikonu: `home_app_bar.dart` -> `NotificationsScreen`

### FCM ile Push alma (özet)

1. `firebase_messaging` paketini ekle.
2. Uygulama açılışında izin iste.
3. FCM token al ve backend’e `POST /api/notifications/device-token` ile gönder.
4. Foreground mesaj geldiğinde lokal bildirim göster (`NotificationService.instance.showLocalNotification(...)`).

Örnek:

```dart
final messaging = FirebaseMessaging.instance;
await messaging.requestPermission(alert: true, badge: true, sound: true);
final token = await messaging.getToken();
if (token != null) {
  await RemoteNotificationService().registerDeviceToken(
    userId: AppSession.userId,
    platform: 'android',
    token: token,
  );
}

FirebaseMessaging.onMessage.listen((message) async {
  final title = message.notification?.title ?? 'Yeni bildirim';
  final body = message.notification?.body ?? '';
  await NotificationService.instance.showLocalNotification(
    title: title,
    body: body,
  );
});
```

### SignalR ile realtime alma (alternatif)

- Hub URL: `/hubs/notifications`
- Bağlandıktan sonra:
  - `SubscribeUser(AppSession.userId)` çağrısı yap
  - `notification_received` eventini dinle
  - event gelince listeyi yenile veya lokal bildirimi tetikle

## Notlar

- DB migration henüz üretilmedi; yeni tablolar için migration alın:
  - `dotnet ef migrations add AddNotificationsModule`
  - `dotnet ef database update`
- Bildirim tablosu `IsRead` ve `ReadAtUtc` alanlarıyla okunma takibini destekler.
