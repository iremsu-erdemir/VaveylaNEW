import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/services/restaurant_owner_service.dart';

class RestaurantOrdersCubit extends Cubit<List<RestaurantOrderModel>> {
  RestaurantOrdersCubit(this._service, this._ownerUserId) : super(const []);

  final RestaurantOwnerService _service;
  final String _ownerUserId;
  Timer? _pollTimer;

  Future<void> loadOrders() async {
    try {
      final orders = await _service.getOrders(ownerUserId: _ownerUserId);
      emit(orders);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[RestaurantOrdersCubit] loadOrders failed: $e\n$st');
      }
      emit(state);
    }
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      loadOrders();
    });
  }

  Future<void> acceptOrder(String id) async {
    await _updateOrderStatusRemote(id, RestaurantOrderStatus.preparing);
  }

  Future<void> rejectOrder(String id) async {
    throw UnimplementedError(
      'rejectOrder signature changed. Use rejectOrderWithReason instead.',
    );
  }

  Future<void> rejectOrderWithReason(
    String id, {
    required String rejectionReason,
  }) async {
    final updated = await _service.updateOrderStatus(
      ownerUserId: _ownerUserId,
      id: id,
      status: RestaurantOrderStatus.rejected,
      rejectionReason: rejectionReason,
    );
    emit(
      state
          .map((order) => order.id == id ? updated : order)
          .toList(),
    );
  }

  Future<void> markReady(String id) async {
    await _updateOrderStatusRemote(id, RestaurantOrderStatus.completed);
  }

  Future<void> assignCourier({
    required String orderId,
    required String courierUserId,
  }) async {
    final updated = await _service.assignCourierToOrder(
      ownerUserId: _ownerUserId,
      orderId: orderId,
      courierUserId: courierUserId,
    );
    emit(
      state.map((order) => order.id == orderId ? updated : order).toList(),
    );
  }

  Future<void> _updateOrderStatusRemote(
    String id,
    RestaurantOrderStatus to,
    {
      String? rejectionReason,
    }
  ) async {
    final updated = await _service.updateOrderStatus(
      ownerUserId: _ownerUserId,
      id: id,
      status: to,
      rejectionReason: rejectionReason,
    );
    emit(state.map((order) {
      if (order.id == id) {
        return updated;
      }
      return order;
    }).toList());
  }

  Future<void> addOrder(
    String items,
    int total, {
    String? imagePath,
    int? preparationMinutes,
    RestaurantOrderStatus? status,
    DateTime? createdAt,
  }) async {
    final created = await _service.createOrder(
      ownerUserId: _ownerUserId,
      items: items,
      total: total,
      imagePath: imagePath,
      preparationMinutes: preparationMinutes,
      status: status?.name,
      createdAt: createdAt,
    );
    final refreshedOrders = await _loadOrdersWithConfirmation(created.id);
    emit(refreshedOrders);
  }

  Future<List<RestaurantOrderModel>> _loadOrdersWithConfirmation(
    String createdOrderId,
  ) async {
    const maxAttempts = 4;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final orders = await _service.getOrders(ownerUserId: _ownerUserId);
      final shouldValidateId = createdOrderId.trim().isNotEmpty;
      final isPersisted =
          !shouldValidateId || orders.any((order) => order.id == createdOrderId);
      if (isPersisted) {
        return orders;
      }
      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }

    throw Exception(
      'Sipariş backend tarafında doğrulanamadı. Lütfen tekrar deneyin.',
    );
  }

  List<RestaurantOrderModel> getByStatus(RestaurantOrderStatus status) {
    return state.where((o) => o.status == status).toList();
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
