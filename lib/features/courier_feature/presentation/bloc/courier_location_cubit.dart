import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/data/models/courier_order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/data/services/courier_service.dart';
import 'package:geolocator/geolocator.dart';

part 'courier_location_state.dart';

/// Kurye konumunu canlı takip için yönetir.
class CourierLocationCubit extends Cubit<CourierLocationState> {
  CourierLocationCubit({
    required CourierService courierService,
    required String courierUserId,
  }) : _courierService = courierService,
       _courierUserId = courierUserId,
       super(const CourierLocationState());

  StreamSubscription<Position>? _positionSubscription;
  final CourierService _courierService;
  final String _courierUserId;
  String? _activeOrderId;
  DateTime? _lastSyncAtUtc;

  /// "Takibi Durdur" sonrası otomatik yeniden başlatmayı engelle (Harita ↔ tam ekran aynı cubit).
  bool _suppressAutoRestart = false;

  bool get suppressAutoRestart => _suppressAutoRestart;

  String? get activeTrackingOrderId => _activeOrderId;

  void releaseAutoRestartSuppression() {
    _suppressAutoRestart = false;
  }

  static bool _orderIdEq(String a, String b) =>
      a.toLowerCase().trim() == b.toLowerCase().trim();

  static bool _isOnTheWay(CourierOrderModel o) {
    return o.status == CourierOrderStatus.pickedUp ||
        o.status == CourierOrderStatus.inTransit;
  }

  /// Sipariş listesi güncellenince canlı takibi sürdürür. Tam ekran harita route’u
  /// kapansa bile dashboard bu metodu dinlediği için takip kesilmez / yeniden bağlanır.
  ///
  /// [preferredOrderId]: harita odağı veya tam ekranda açılan sipariş (öncelikli hedef).
  Future<void> reconcileTrackingWithOrders(
    List<CourierOrderModel> orders, {
    String? preferredOrderId,
  }) async {
    final active = orders.where(_isOnTheWay).toList();
    if (active.isEmpty) {
      if (state.status == CourierLocationStatus.tracking) {
        await stopTracking(userInitiated: false);
      }
      return;
    }

    String wantId = active.first.id;
    final pref = preferredOrderId;
    if (pref != null) {
      for (final o in active) {
        if (_orderIdEq(o.id, pref)) {
          wantId = o.id;
          break;
        }
      }
    }

    if (_suppressAutoRestart &&
        state.status != CourierLocationStatus.tracking) {
      return;
    }

    final curId = _activeOrderId;

    if (state.status == CourierLocationStatus.tracking &&
        curId != null &&
        _orderIdEq(curId, wantId)) {
      return;
    }

    if (state.status == CourierLocationStatus.tracking &&
        curId != null &&
        !_orderIdEq(curId, wantId)) {
      await stopTracking(userInitiated: false);
    }

    await startTracking(orderId: wantId);
  }

  Future<void> startTracking({String? orderId}) async {
    _suppressAutoRestart = false;
    _activeOrderId = orderId;
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      emit(
        state.copyWith(
          status: CourierLocationStatus.error,
          message: 'Konum servisleri kapalı.',
        ),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      emit(
        state.copyWith(
          status: CourierLocationStatus.denied,
          message: 'Konum izni gerekli.',
        ),
      );
      return;
    }

    if (_activeOrderId != null && _activeOrderId!.isNotEmpty) {
      try {
        await _courierService.startTracking(
          courierUserId: _courierUserId,
          orderId: _activeOrderId!,
        );
      } catch (e) {
        emit(
          state.copyWith(
            status: CourierLocationStatus.error,
            message: e.toString().replaceFirst('Exception: ', ''),
          ),
        );
        return;
      }
    }

    emit(state.copyWith(status: CourierLocationStatus.tracking));

    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) async {
      emit(
        state.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
          heading: _headingFromPosition(position, state.heading),
          status: CourierLocationStatus.tracking,
        ),
      );
      await _syncLocationIfNeeded(position);
    });
  }

  Future<void> getCurrentPosition() async {
    emit(state.copyWith(status: CourierLocationStatus.loading));
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      emit(
        state.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
          status: CourierLocationStatus.success,
        ),
      );
    } catch (e) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        emit(
          state.copyWith(
            latitude: last.latitude,
            longitude: last.longitude,
            status: CourierLocationStatus.success,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: CourierLocationStatus.error,
            message: 'Konum alınamadı.',
          ),
        );
      }
    }
  }

  /// [userInitiated]: true → kurye durdurdu; otomatik sync ile yeniden açılmasın.
  Future<void> stopTracking({bool userInitiated = true}) async {
    final orderId = _activeOrderId;
    if (orderId != null && orderId.isNotEmpty) {
      await _courierService.stopTracking(
        courierUserId: _courierUserId,
        orderId: orderId,
      );
    }
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _activeOrderId = null;
    _lastSyncAtUtc = null;
    if (userInitiated) {
      _suppressAutoRestart = true;
    }
    emit(
      CourierLocationState(
        status: CourierLocationStatus.idle,
        latitude: state.latitude,
        longitude: state.longitude,
        message: state.message,
      ),
    );
  }

  /// GPS heading: hareket varken güncelle, yoksa son geçerli yönü koru.
  double? _headingFromPosition(Position position, double? previous) {
    if (!position.heading.isFinite) return previous;
    final h = position.heading % 360.0;
    if (position.speed >= 0.5) return h;
    return previous ?? (h > 0.1 ? h : previous);
  }

  Future<void> _syncLocationIfNeeded(Position position) async {
    final orderId = _activeOrderId;
    if (orderId == null || orderId.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
    if (_lastSyncAtUtc != null &&
        now.difference(_lastSyncAtUtc!).inSeconds < 3) {
      return;
    }

    _lastSyncAtUtc = now;
    await _courierService.updateCourierLocation(
      courierUserId: _courierUserId,
      orderId: orderId,
      lat: position.latitude,
      lng: position.longitude,
      bearing: position.heading.isNaN ? null : position.heading,
      timestampUtc: now,
    );
  }

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    return super.close();
  }
}
