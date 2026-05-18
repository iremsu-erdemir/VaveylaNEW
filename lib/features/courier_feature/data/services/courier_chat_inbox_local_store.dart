import 'package:shared_preferences/shared_preferences.dart';

/// Kurye teslimat sohbetleri listesinden satırı yerelde gizler (mesajlar silinmez).
class CourierChatInboxLocalStore {
  CourierChatInboxLocalStore._();

  static String _key(String courierUserId) =>
      'courier_delivery_chat_hidden_v1_${courierUserId.trim()}';

  static Future<Set<String>> loadHiddenOrderIds(String courierUserId) async {
    if (courierUserId.trim().isEmpty) return {};
    final p = await SharedPreferences.getInstance();
    return {...?p.getStringList(_key(courierUserId))};
  }

  static Future<void> hideOrderRow({
    required String courierUserId,
    required String orderId,
  }) async {
    final uid = courierUserId.trim();
    final oid = orderId.trim();
    if (uid.isEmpty || oid.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final key = _key(uid);
    final next = {...?p.getStringList(key), oid};
    await p.setStringList(key, next.toList());
  }
}
