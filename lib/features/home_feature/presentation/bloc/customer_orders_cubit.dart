import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/customer_order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/services/customer_order_service.dart';

class CustomerOrdersState {
  const CustomerOrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
  });

  final List<CustomerOrderModel> orders;
  final bool isLoading;
  final String? error;

  CustomerOrdersState copyWith({
    List<CustomerOrderModel>? orders,
    bool? isLoading,
    String? error,
  }) {
    return CustomerOrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CustomerOrdersCubit extends Cubit<CustomerOrdersState> {
  CustomerOrdersCubit(this._service)
    : super(const CustomerOrdersState(isLoading: true));

  final CustomerOrderService _service;
  Timer? _pollTimer;
  static const int _defaultPollSeconds = 4;
  int _pollIntervalSeconds = _defaultPollSeconds;

  Future<void> loadOrders({bool showLoading = true}) async {
    final customerUserId = AppSession.userId;
    if (customerUserId.isEmpty) {
      emit(state.copyWith(orders: const [], isLoading: false, error: null));
      return;
    }
    if (showLoading) {
      emit(state.copyWith(isLoading: true, error: null));
    }
    try {
      final orders =
          await _service.getOrders(customerUserId: customerUserId);
      emit(state.copyWith(orders: orders, isLoading: false, error: null));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void startPolling() {
    _pollIntervalSeconds = _defaultPollSeconds;
    _restartPollingTimer();
  }

  /// Canlı takip ekranında müşteri–kurye senkronu için daha sık yenileme.
  void setPollingIntervalSeconds(int seconds) {
    if (seconds < 1) return;
    if (_pollIntervalSeconds == seconds) return;
    _pollIntervalSeconds = seconds;
    _restartPollingTimer();
  }

  void _restartPollingTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: _pollIntervalSeconds), (_) {
      loadOrders(showLoading: false);
    });
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
