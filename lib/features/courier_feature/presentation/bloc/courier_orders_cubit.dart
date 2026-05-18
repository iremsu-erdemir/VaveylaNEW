import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/data/models/courier_order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/data/services/courier_service.dart';

class CourierOrdersCubit extends Cubit<List<CourierOrderModel>> {
  CourierOrdersCubit(this._service, this._courierUserId) : super(const []);

  final CourierService _service;
  final String _courierUserId;
  Timer? _pollTimer;
  static const int _defaultPollSeconds = 4;
  int _pollIntervalSeconds = _defaultPollSeconds;

  Future<void> loadOrders() async {
    try {
      final loaded = await _service.getOrders(courierUserId: _courierUserId);
      final merged = _mergeWithCurrentState(loaded);
      emit(merged);
    } catch (_) {
      // Polling sırasında geçici ağ/API hatalarında UI'ı çökertmemek için
      // mevcut state korunur.
    }
  }

  void startPolling() {
    _pollIntervalSeconds = _defaultPollSeconds;
    _restartPollingTimer();
  }

  void setPollingIntervalSeconds(int seconds) {
    if (seconds < 1) return;
    if (_pollIntervalSeconds == seconds) return;
    _pollIntervalSeconds = seconds;
    _restartPollingTimer();
  }

  void _restartPollingTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: _pollIntervalSeconds), (_) {
      loadOrders();
    });
  }

  /// Yerel olarak güncellenmiş durumları korur. Yenile sonrası teslim edilen
  /// siparişlerin tekrar bekleyene düşmesini önler.
  List<CourierOrderModel> _mergeWithCurrentState(
    List<CourierOrderModel> loaded,
  ) {
    if (state.isEmpty) return loaded;
    final existingById = {for (final o in state) o.id: o};
    final merged = loaded.map((loadedOrder) {
      final existing = existingById[loadedOrder.id];
      if (existing != null &&
          _statusOrder(existing.status) > _statusOrder(loadedOrder.status)) {
        return existing.copyWith(
          courierDeclined: loadedOrder.courierDeclined,
          courierDeclineReason: loadedOrder.courierDeclineReason,
        );
      }
      return loadedOrder;
    }).toList();

    // Eski API cevabı teslim edilenleri listelemezse bile "Teslim" sekmesinde kalsın.
    final inMerged = {for (final o in merged) _normId(o.id): true};
    for (final o in state) {
      if (o.status != CourierOrderStatus.delivered) continue;
      if (inMerged[_normId(o.id)] == true) continue;
      merged.add(o);
    }
    // Bu kuryenin reddettiği sipariş API listesinden düşerse "Reddedilenler" geçmişi korunur.
    for (final o in state) {
      if (!o.courierDeclined) continue;
      if (inMerged[_normId(o.id)] == true) continue;
      merged.add(o);
    }
    return merged;
  }

  static String _normId(String id) => id.toLowerCase().trim();

  static int _statusOrder(CourierOrderStatus s) {
    switch (s) {
      case CourierOrderStatus.assigned:
        return 0;
      case CourierOrderStatus.pickedUp:
        return 1;
      case CourierOrderStatus.inTransit:
        return 2;
      case CourierOrderStatus.delivered:
        return 3;
    }
  }

  Future<void> markPickedUp(String id) async {
    await _acceptOrder(id);
  }

  Future<void> markInTransit(String id) async {
    await _updateStatus(id, CourierOrderStatus.inTransit);
  }

  Future<void> markDelivered(String id) async {
    await _updateStatus(id, CourierOrderStatus.delivered);
  }

  /// Kabul sonrası yola çıkmadan görevi reddet (sunucu atamayı kaldırır).
  Future<void> rejectAssignment(String id, String reason) async {
    await _service.rejectAssignment(
      courierUserId: _courierUserId,
      id: id,
      rejectionReason: reason,
    );
    await loadOrders();
  }

  Future<void> _updateStatus(String id, CourierOrderStatus to) async {
    await _service.updateOrderStatus(
      courierUserId: _courierUserId,
      id: id,
      status: to,
    );
    emit(
      state
          .map(
            (o) =>
                _orderIdEquals(o.id, id) ? o.copyWith(status: to) : o,
          )
          .toList(),
    );
  }

  Future<void> _acceptOrder(String id) async {
    await _service.acceptOrder(courierUserId: _courierUserId, id: id);
    emit(
      state
          .map(
            (o) =>
                _orderIdEquals(o.id, id)
                    ? o.copyWith(
                        status: CourierOrderStatus.pickedUp,
                        assignedCourierUserId: _courierUserId,
                        resetCourierDecline: true,
                      )
                    : o,
          )
          .toList(),
    );
  }

  static bool _orderIdEquals(String a, String b) =>
      a.toLowerCase().trim() == b.toLowerCase().trim();

  List<CourierOrderModel> getByStatus(CourierOrderStatus status) {
    return state.where((o) => o.status == status).toList();
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
