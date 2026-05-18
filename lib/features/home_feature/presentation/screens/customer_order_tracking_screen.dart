import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/google_geocoding_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/route_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/tracking_realtime_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/delivery_chat_panel.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/customer_order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/tracking_models.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/products_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/customer_orders_cubit.dart';
import 'package:latlong2/latlong.dart';

/// Müşteri teslimat rotası: kurye ekranıyla aynı düzen (OSRM pastane→müşteri, chip, alt panel, ETA şeridi).
class CustomerOrderTrackingScreen extends StatefulWidget {
  const CustomerOrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<CustomerOrderTrackingScreen> createState() =>
      _CustomerOrderTrackingScreenState();
}

class _CustomerOrderTrackingScreenState
    extends State<CustomerOrderTrackingScreen> {
  final TrackingRealtimeService _trackingService =
      TrackingRealtimeService.shared;
  final GoogleGeocodingService _geocodingService = GoogleGeocodingService();
  final RouteService _routeService = RouteService();
  final MapController _mapController = MapController();

  LatLng? _animatedCourierPoint;
  LatLng? _snapshotCustomerPoint;
  String? _snapshotDeliveryAddress;
  double? _snapshotRestaurantLat;
  double? _snapshotRestaurantLng;
  String? _snapshotRestaurantAddress;
  String? _snapshotRestaurantName;
  String? _snapshotCustomerName;
  String? _snapshotCustomerPhone;
  CourierDetailsModel? _courier;
  bool _trackingActive = false;

  /// Yalnızca [inTransit] iken SignalR aboneliği (canlı konum / takip bayrağı).
  bool _liveSignalRSubscribed = false;
  bool _trackingHandlersWired = false;
  bool _isReady = false;
  bool _isGeocodingAddress = false;
  bool _isGeocodingRestaurant = false;
  CustomerOrdersCubit? _ordersCubit;
  LatLng? _geocodedRestaurant;

  /// Sipariş satırında koordinat yoksa `/api/products?restaurantId=` yedeği.
  double? _catalogRestaurantLat;
  double? _catalogRestaurantLng;
  String? _catalogRestaurantAddress;
  String? _catalogRestaurantName;
  String? _catalogHydrateAttemptedForOrderId;

  RouteResult? _fullRouteResult;
  String? _routeCacheKey;
  String? _routeFetchInflightKey;

  /// Son geçerli SignalR kurye ping zamanı (sipariş API zaman damgası yoksa kullanılır).
  DateTime? _lastCourierPushUtc;

  bool _showLocationCard = false;

  static const Color _navRouteBlue = Color(0xFF1A73E8);
  static const Distance _distanceCalc = Distance();

  bool _isValidLatLng(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  LatLng? _safeLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (_isValidLatLng(lat, lng)) return LatLng(lat, lng);
    if (_isValidLatLng(lng, lat)) return LatLng(lng, lat);
    return null;
  }

  List<LatLng> _sanitizePolylinePoints(List<LatLng> points) {
    return points
        .where((p) => _isValidLatLng(p.latitude, p.longitude))
        .toList(growable: false);
  }

  bool _latLngDistinct(LatLng? a, LatLng? b) {
    if (a == null || b == null) return true;
    const eps = 1e-5;
    return (a.latitude - b.latitude).abs() > eps ||
        (a.longitude - b.longitude).abs() > eps;
  }

  String _latLngKey(LatLng p) =>
      '${p.latitude.toStringAsFixed(6)};${p.longitude.toStringAsFixed(6)}';

  bool _orderIdEquals(String a, String b) =>
      a.toLowerCase().trim() == b.toLowerCase().trim();

  /// Canlı konum + süre/mesafe yalnızca kurye yola çıktığında (sunucu: inTransit).
  /// Atanmış (assigned) aşamasında müşteri tahmini süre ve SignalR takibini görmez.
  bool _isLiveHubEligible(CustomerOrderModel? order) {
    if (order == null) return false;
    return order.status == CustomerOrderStatus.inTransit;
  }

  void _stopLiveTrackingHub() {
    if (_liveSignalRSubscribed) {
      _trackingService.unsubscribeOrder(widget.orderId);
      _liveSignalRSubscribed = false;
    }
    if (!mounted) return;
    setState(() {
      _trackingActive = false;
      _animatedCourierPoint = null;
      _lastCourierPushUtc = null;
    });
  }

  LatLng? _customerPointFromOrder(CustomerOrderModel order) {
    final orderPoint = _safeLatLng(order.customerLat, order.customerLng);
    if (orderPoint != null) return orderPoint;
    return _snapshotCustomerPoint;
  }

  LatLng? _restaurantPointFromOrder(CustomerOrderModel order) {
    final api = _safeLatLng(order.restaurantLat, order.restaurantLng);
    if (api != null) return api;
    final snap = _safeLatLng(_snapshotRestaurantLat, _snapshotRestaurantLng);
    if (snap != null) return snap;
    final cat = _safeLatLng(_catalogRestaurantLat, _catalogRestaurantLng);
    if (cat != null) return cat;
    return _geocodedRestaurant;
  }

  /// OSRM uçları: kurye ekranında olduğu gibi önce API/snapshot, sonra adres geokodu; katalog
  /// koordinatı en sonda (ürün API’si ile OSRM uçları çakışmasın).
  LatLng? _restaurantPointForRoute(CustomerOrderModel order) {
    final api = _safeLatLng(order.restaurantLat, order.restaurantLng);
    if (api != null) return api;
    final snap = _safeLatLng(_snapshotRestaurantLat, _snapshotRestaurantLng);
    if (snap != null) return snap;
    final geo = _geocodedRestaurant;
    if (geo != null) return geo;
    return _safeLatLng(_catalogRestaurantLat, _catalogRestaurantLng);
  }

  /// Kartta pastane adres satırı (isim ayrı başlıkta).
  String? _restaurantStreetOnly(CustomerOrderModel order) {
    final a = order.restaurantAddress?.trim();
    if (a != null && a.isNotEmpty) return a;
    final s = _snapshotRestaurantAddress?.trim();
    if (s != null && s.isNotEmpty) return s;
    final c = _catalogRestaurantAddress?.trim();
    if (c != null && c.isNotEmpty) return c;
    return null;
  }

  String _restaurantTitleLine(CustomerOrderModel order) {
    final n = order.restaurantName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final sn = _snapshotRestaurantName?.trim();
    if (sn != null && sn.isNotEmpty) return sn;
    final cn = _catalogRestaurantName?.trim();
    if (cn != null && cn.isNotEmpty) return cn;
    return 'Pastane';
  }

  String _customerNameLine(CustomerOrderModel order) {
    final n = order.customerName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final sn = _snapshotCustomerName?.trim();
    if (sn != null && sn.isNotEmpty) return sn;
    final fn = AppSession.fullName.trim();
    if (fn.isNotEmpty) return fn;
    return 'Müşteri';
  }

  String? _customerPhoneLine(CustomerOrderModel order) {
    final p = order.customerPhone?.trim();
    if (p != null && p.isNotEmpty) return p;
    return _snapshotCustomerPhone?.trim();
  }

  /// Teslimat satırından il/ilçe ipucu (pastane adı geocode için).
  String? _deliveryCityHint(CustomerOrderModel order) {
    final line = _resolvedDeliveryAddressLine(order)?.trim();
    if (line == null || line.isEmpty) return null;
    final parts =
        line
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    if (parts.isEmpty) return null;
    String? segment;
    final lastLower = parts.last.toLowerCase();
    if (parts.length >= 2 &&
        (lastLower == 'türkiye' || lastLower == 'turkey')) {
      segment = parts[parts.length - 2];
    }
    segment ??= parts.length >= 2 ? parts[parts.length - 1] : parts.last;
    segment = segment.replaceFirst(RegExp(r'^\d{5}\s+'), '');
    final slash = segment.indexOf('/');
    if (slash != -1) {
      final right = segment.substring(slash + 1).trim();
      if (right.isNotEmpty) return right;
      segment = segment.substring(0, slash).trim();
    }
    final words = segment.split(RegExp(r'\s+'));
    if (words.length >= 2 && segment.toLowerCase().contains('merkez')) {
      return words.last;
    }
    return segment.isEmpty ? null : segment;
  }

  /// Geocoding için: tam adres varsa o; yoksa restoran adı + ülke.
  String? _restaurantGeocodeQuery(CustomerOrderModel order) {
    final addr = order.restaurantAddress?.trim();
    if (addr != null && addr.isNotEmpty) return addr;
    final snapAddr = _snapshotRestaurantAddress?.trim();
    if (snapAddr != null && snapAddr.isNotEmpty) return snapAddr;
    final catAddr = _catalogRestaurantAddress?.trim();
    if (catAddr != null && catAddr.isNotEmpty) return catAddr;
    final name =
        order.restaurantName?.trim() ??
        _snapshotRestaurantName?.trim() ??
        _catalogRestaurantName?.trim();
    if (name == null || name.isEmpty) return null;
    final city = _deliveryCityHint(order);
    if (city != null && city.isNotEmpty) return '$name, $city, Türkiye';
    return '$name, Türkiye';
  }

  /// Pastane ile müşteri pin’i çakışınca turuncu ikon kaybolmasın (sadece harita ikonu kaydırılır; rota uçları aynı).
  LatLng? _restaurantMarkerOnMap(LatLng? rest, LatLng? customer) {
    if (rest == null) return null;
    if (customer == null) return rest;
    if (_distanceCalc(rest, customer) >= 55) return rest;
    return LatLng(rest.latitude + 0.00045, rest.longitude + 0.00045);
  }

  /// Snapshot (canlı takip API) öncelikli; yoksa sipariş listesindeki teslimat adresi.
  String? _resolvedDeliveryAddressLine(CustomerOrderModel order) {
    final line = order.deliveryAddress?.trim();
    if (line != null && line.isNotEmpty) {
      final detail = order.deliveryAddressDetail?.trim();
      if (detail != null && detail.isNotEmpty) {
        return '$line, $detail';
      }
      return line;
    }
    final onlyDetail = order.deliveryAddressDetail?.trim();
    if (onlyDetail != null && onlyDetail.isNotEmpty) return onlyDetail;
    final snap = _snapshotDeliveryAddress?.trim();
    if (snap != null && snap.isNotEmpty) return snap;
    return null;
  }

  String? _routeEndpointsKey(LatLng? from, LatLng? to) {
    if (from == null || to == null) return null;
    return '${widget.orderId}|${_latLngKey(from)}|${_latLngKey(to)}';
  }

  /// Teslimat koordinatı ile aynı noktayı, sunucunun kurye güncellemesi olmadan kurye sanma.
  bool _courierRawIsTrustworthy(
    LatLng? courier,
    LatLng? customer,
    DateTime? courierUpdatedAtUtc,
  ) {
    if (courier == null) return false;
    if (customer == null) return true;
    if (courierUpdatedAtUtc != null) return true;
    return _distanceCalc(courier, customer) >= 32;
  }

  /// Müşteri haritasında kurye ikonu yok; yalnızca metin durumu için konum bilgisi tutulur.
  bool _hasTrustworthyCourierFix(CustomerOrderModel order, LatLng? customerPt) {
    final raw =
        _animatedCourierPoint ??
        _safeLatLng(order.courierLat, order.courierLng);
    if (raw == null) return false;
    final ts = order.courierLocationUpdatedAtUtc ?? _lastCourierPushUtc;
    if (customerPt != null &&
        ts == null &&
        _distanceCalc(raw, customerPt) < 35) {
      return false;
    }
    return true;
  }

  Future<void> _fetchFullRoute(LatLng from, LatLng to) async {
    final key = _routeEndpointsKey(from, to);
    if (key == null) return;
    if (_routeCacheKey == key && _fullRouteResult != null) return;
    if (_routeFetchInflightKey == key) return;
    _routeFetchInflightKey = key;
    try {
      final result = await _routeService.getRoute(
        from: from,
        to: to,
        courierPosition: null,
      );
      if (!mounted) return;
      if (_routeEndpointsKey(from, to) != key) return;
      if (result != null) {
        setState(() {
          _fullRouteResult = result;
          _routeCacheKey = key;
        });
        _fitMapToRoute(from, to);
      }
    } finally {
      if (_routeFetchInflightKey == key) {
        _routeFetchInflightKey = null;
      }
    }
  }

  void _fitMapToRoute(LatLng from, LatLng to) {
    final pts = _sanitizePolylinePoints(
      _fullRouteResult?.polylinePoints ?? const <LatLng>[],
    );
    final list = <LatLng>[from, to];
    if (pts.length >= 2) {
      list.addAll(pts);
    }
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: list,
          padding: const EdgeInsets.fromLTRB(28, 88, 28, 280),
        ),
      );
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ordersCubit = context.read<CustomerOrdersCubit>();
      _ordersCubit?.setPollingIntervalSeconds(2);
      unawaited(_bootstrapRealtime());
    });
  }

  @override
  void dispose() {
    _ordersCubit?.setPollingIntervalSeconds(4);
    if (_liveSignalRSubscribed) {
      _trackingService.unsubscribeOrder(widget.orderId);
    }
    super.dispose();
  }

  void _wireTrackingHandlers() {
    if (_trackingHandlersWired) {
      return;
    }
    _trackingHandlersWired = true;
    _trackingService.onTrackingStatusChanged((isActive) {
      if (!mounted) return;
      final order =
          _ordersCubit == null
              ? null
              : _findOrder(_ordersCubit!.state.orders, widget.orderId);
      if (!_isLiveHubEligible(order)) {
        return;
      }
      setState(() {
        _trackingActive = isActive;
      });
    });
    _trackingService.onLocationUpdated((update) {
      if (!mounted || !_orderIdEquals(update.orderId, widget.orderId)) return;
      final order =
          _ordersCubit == null
              ? null
              : _findOrder(_ordersCubit!.state.orders, widget.orderId);
      if (!_isLiveHubEligible(order)) {
        return;
      }
      final next = _safeLatLng(update.lat, update.lng);
      if (next == null) return;
      setState(() {
        _lastCourierPushUtc = update.timestampUtc ?? DateTime.now();
        _animatedCourierPoint = next;
        if (update.courier != null) {
          _courier = update.courier;
        }
      });
    });
  }

  /// Liste yoklaması siparişi "Yolda" yaptığında hub aboneliğini başlatır.
  Future<void> _enableLiveTrackingHubIfNeeded() async {
    if (_liveSignalRSubscribed || !mounted) return;
    final cubit = _ordersCubit ?? context.read<CustomerOrdersCubit>();
    final order = _findOrder(cubit.state.orders, widget.orderId);
    if (!_isLiveHubEligible(order)) return;
    try {
      final snapshot = await _trackingService.getSnapshot(
        orderId: widget.orderId,
        customerUserId: AppSession.userId,
      );
      if (!mounted) return;
      if (snapshot != null) {
        setState(() {
          _trackingActive = snapshot.isTrackingActive;
          _courier = snapshot.courier;
          final snapCust = _safeLatLng(
            snapshot.customerLat,
            snapshot.customerLng,
          );
          final snapCourier = _safeLatLng(
            snapshot.courierLat,
            snapshot.courierLng,
          );
          if (_courierRawIsTrustworthy(
            snapCourier,
            snapCust,
            snapshot.courierLocationUpdatedAtUtc,
          )) {
            _animatedCourierPoint = snapCourier;
            _lastCourierPushUtc = snapshot.courierLocationUpdatedAtUtc;
          }
        });
      }
      await _trackingService.connect();
      await _trackingService.subscribeOrder(widget.orderId);
      _wireTrackingHandlers();
      _liveSignalRSubscribed = true;
    } catch (_) {}
  }

  Future<void> _bootstrapRealtime() async {
    try {
      final cubit = _ordersCubit;
      final order =
          cubit == null ? null : _findOrder(cubit.state.orders, widget.orderId);
      final allowLive = _isLiveHubEligible(order);

      final snapshot = await _trackingService.getSnapshot(
        orderId: widget.orderId,
        customerUserId: AppSession.userId,
      );
      if (!mounted) return;
      if (snapshot != null) {
        setState(() {
          _snapshotDeliveryAddress = snapshot.deliveryAddress;
          _snapshotCustomerPoint = _safeLatLng(
            snapshot.customerLat,
            snapshot.customerLng,
          );
          _snapshotRestaurantLat = snapshot.restaurantLat;
          _snapshotRestaurantLng = snapshot.restaurantLng;
          _snapshotRestaurantAddress = snapshot.restaurantAddress;
          _snapshotRestaurantName = snapshot.restaurantName;
          _snapshotCustomerName = snapshot.customerName;
          _snapshotCustomerPhone = snapshot.customerPhone;
          if (allowLive) {
            _trackingActive = snapshot.isTrackingActive;
            _courier = snapshot.courier;
            final snapCust = _safeLatLng(
              snapshot.customerLat,
              snapshot.customerLng,
            );
            final snapCourier = _safeLatLng(
              snapshot.courierLat,
              snapshot.courierLng,
            );
            if (_courierRawIsTrustworthy(
              snapCourier,
              snapCust,
              snapshot.courierLocationUpdatedAtUtc,
            )) {
              _animatedCourierPoint = snapCourier;
              _lastCourierPushUtc = snapshot.courierLocationUpdatedAtUtc;
            } else {
              _animatedCourierPoint = null;
            }
          } else {
            _trackingActive = false;
            _animatedCourierPoint = null;
            _lastCourierPushUtc = null;
          }
        });
      }

      if (allowLive) {
        await _trackingService.connect();
        await _trackingService.subscribeOrder(widget.orderId);
        _wireTrackingHandlers();
        _liveSignalRSubscribed = true;
      }
    } finally {
      if (mounted) {
        setState(() => _isReady = true);
      }
    }
  }

  Future<void> _geocodeCustomerAddressIfNeeded(CustomerOrderModel order) async {
    final addrLine = _resolvedDeliveryAddressLine(order);
    if (_snapshotCustomerPoint != null ||
        _isGeocodingAddress ||
        addrLine == null ||
        addrLine.isEmpty) {
      return;
    }

    _isGeocodingAddress = true;
    final result = await _geocodingService.geocodeAddress(addrLine);
    _isGeocodingAddress = false;
    if (!mounted || result == null) return;
    setState(() {
      _snapshotCustomerPoint = _safeLatLng(result.latitude, result.longitude);
    });
  }

  Future<void> _maybeHydrateRestaurantFromCatalog(
    CustomerOrderModel order,
  ) async {
    if (_catalogHydrateAttemptedForOrderId == order.id) return;
    final rid = order.restaurantId.trim();
    if (rid.isEmpty) {
      _catalogHydrateAttemptedForOrderId = order.id;
      return;
    }
    final hasCoords =
        _safeLatLng(order.restaurantLat, order.restaurantLng) != null ||
        _safeLatLng(_snapshotRestaurantLat, _snapshotRestaurantLng) != null;
    if (hasCoords) {
      _catalogHydrateAttemptedForOrderId = order.id;
      return;
    }
    _catalogHydrateAttemptedForOrderId = order.id;
    try {
      final products = await ProductsService().getProducts(restaurantId: rid);
      if (!mounted || products.isEmpty) return;
      final p = products.first;
      setState(() {
        _catalogRestaurantLat = p.restaurantLat;
        _catalogRestaurantLng = p.restaurantLng;
        final a = p.restaurantAddress?.trim();
        if (a != null && a.isNotEmpty) {
          _catalogRestaurantAddress = a;
        }
        final n = p.restaurantName?.trim();
        if (n != null && n.isNotEmpty) {
          _catalogRestaurantName = n;
        }
      });
    } catch (_) {}
  }

  Future<void> _geocodeRestaurantIfNeeded(String? address) async {
    final addr = address?.trim() ?? '';
    if (addr.isEmpty || _geocodedRestaurant != null || _isGeocodingRestaurant) {
      return;
    }
    _isGeocodingRestaurant = true;
    final result = await _geocodingService.geocodeAddress(addr);
    _isGeocodingRestaurant = false;
    if (!mounted || result == null) return;
    final p = _safeLatLng(result.latitude, result.longitude);
    if (p == null) return;
    setState(() => _geocodedRestaurant = p);
  }

  void _zoomBy(double delta) {
    final cam = _mapController.camera;
    final next = (cam.zoom + delta).clamp(4.0, 19.0);
    _mapController.move(cam.center, next);
  }

  void _openDeliveryChat(CustomerOrderModel currentOrder) {
    if (currentOrder.status != CustomerOrderStatus.inTransit) {
      final message =
          currentOrder.status == CustomerOrderStatus.assigned
              ? 'Kurye atandı. Teslimat sohbeti kurye yola çıkınca aktif olacak.'
              : 'Henüz kurye atanmadı. Kurye atanması bekleniyor.';
      context.showErrorMessage(message);
      return;
    }
    final colors = context.theme.appColors;
    final cubit = _ordersCubit ?? context.read<CustomerOrdersCubit>();
    final existingOrder = _findOrder(cubit.state.orders, widget.orderId);
    final nameFromOrder = existingOrder?.courierName?.trim();
    final title =
        _courier != null && _courier!.fullName.trim().isNotEmpty
            ? 'Kurye: ${_courier!.fullName}'
            : (nameFromOrder != null && nameFromOrder.isNotEmpty
                ? 'Kurye: $nameFromOrder'
                : 'Teslimat sohbeti');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.secondaryShade1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final h = MediaQuery.of(ctx).size.height * 0.72;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SizedBox(
            height: h,
            child: DeliveryChatPanel(
              orderId: widget.orderId,
              title: title,
            ),
          ),
        );
      },
    );
  }

  LatLng _mapCenter(LatLng? customer, LatLng? restaurant) {
    if (restaurant != null && customer != null) {
      return LatLng(
        (restaurant.latitude + customer.latitude) / 2,
        (restaurant.longitude + customer.longitude) / 2,
      );
    }
    return customer ?? restaurant ?? const LatLng(41.6757, 26.5548);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return BlocListener<CustomerOrdersCubit, CustomerOrdersState>(
      listenWhen: (prev, curr) {
        final po = _findOrder(prev.orders, widget.orderId);
        final co = _findOrder(curr.orders, widget.orderId);
        return _isLiveHubEligible(po) != _isLiveHubEligible(co);
      },
      listener: (context, state) {
        final order = _findOrder(state.orders, widget.orderId);
        if (_isLiveHubEligible(order)) {
          unawaited(_enableLiveTrackingHubIfNeeded());
        } else {
          _stopLiveTrackingHub();
        }
      },
      child: AppScaffold(
        extendBodyBehindAppBar: true,
        safeAreaTop: false,
        safeAreaLeft: false,
        safeAreaRight: false,
        safeAreaBottom: false,
        appBar: const GeneralAppBar(
          title: 'Teslimat rotası',
          showBackIcon: true,
        ),
        padding: EdgeInsets.zero,
        body: BlocBuilder<CustomerOrdersCubit, CustomerOrdersState>(
          builder: (context, state) {
            final order = _findOrder(state.orders, widget.orderId);
            if (order == null) {
              return const Center(child: Text('Sipariş bulunamadı.'));
            }

            final mq = MediaQuery.of(context);
            const footerTrackingH = 64.0;
            final scrollMaxH = mq.size.height * 0.34;
            final bottomPanelH =
                scrollMaxH + footerTrackingH + mq.padding.bottom;
            final controlsBottom = bottomPanelH + 16;

            final customerPoint = _customerPointFromOrder(order);
            final restaurantPoint = _restaurantPointFromOrder(order);
            final deliveryAddrLine = _resolvedDeliveryAddressLine(order);
            final liveHubEligible = _isLiveHubEligible(order);
            final customerLiveTracking = liveHubEligible && _trackingActive;

            _geocodeCustomerAddressIfNeeded(order);
            unawaited(_maybeHydrateRestaurantFromCatalog(order));
            final restGeoQuery = _restaurantGeocodeQuery(order);
            // Rota uçları kurye ekranıyla aynı olsun: API koordinatı yoksa adres geokodu şart;
            // yalnızca katalog pin’i varken geokod atlanmasın.
            if (_restaurantPointForRoute(order) == null &&
                restGeoQuery != null) {
              unawaited(_geocodeRestaurantIfNeeded(restGeoQuery));
            }

            final routeRestaurantPoint = _restaurantPointForRoute(order);

            final routeKey = _routeEndpointsKey(
              routeRestaurantPoint,
              customerPoint,
            );
            final routeMatchesFocus =
                _fullRouteResult != null &&
                _routeCacheKey != null &&
                routeKey != null &&
                _routeCacheKey == routeKey;

            var routePoints = <LatLng>[];
            if (routeMatchesFocus) {
              routePoints = _sanitizePolylinePoints(
                _fullRouteResult?.polylinePoints ?? const <LatLng>[],
              );
            }
            if (routePoints.isEmpty &&
                routeRestaurantPoint != null &&
                customerPoint != null &&
                _latLngDistinct(routeRestaurantPoint, customerPoint)) {
              routePoints = [routeRestaurantPoint, customerPoint];
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final from = _restaurantPointForRoute(order);
              final to = customerPoint;
              if (from != null && to != null) {
                unawaited(_fetchFullRoute(from, to));
              }
            });

            final initialCenter = _mapCenter(customerPoint, restaurantPoint);

            final restaurantMarkerPoint = _restaurantMarkerOnMap(
              restaurantPoint,
              customerPoint,
            );

            /// Kurye paneliyle aynı: rozet yalnızca canlı takip + OSRM pastane→müşteri hazırken.
            final showRouteChip =
                customerLiveTracking &&
                routeMatchesFocus &&
                _fullRouteResult?.totalDistanceKm != null &&
                _fullRouteResult?.totalDurationMinutes != null;

            final trackingSubtitle = () {
              if (!_isReady) return 'Bağlantı kuruluyor…';
              if (!liveHubEligible) {
                if (order.status == CustomerOrderStatus.assigned) {
                  return 'Tahmini süre ve canlı konum, kurye pastaneden çıkıp yola başladığında gösterilir.';
                }
                return 'Tahmini süre ve canlı konum, sipariş yola çıktığında gösterilir.';
              }
              if (!_trackingActive) {
                return 'Kurye takibi, kurye uygulamasında takip başlatılınca açılır.';
              }
              if (!_hasTrustworthyCourierFix(order, customerPoint)) {
                return 'Kurye konumu güncelleniyor…';
              }
              final u =
                  order.courierLocationUpdatedAtUtc ?? _lastCourierPushUtc;
              if (u != null) {
                final local = u.toLocal();
                return 'Son konum: ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
              }
              return 'Canlı konum alınıyor';
            }();

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: initialCenter,
                      initialZoom: 14.2,
                      interactionOptions: const InteractionOptions(
                        flags:
                            InteractiveFlag.pinchZoom |
                            InteractiveFlag.drag |
                            InteractiveFlag.doubleTapZoom |
                            InteractiveFlag.flingAnimation,
                      ),
                      onMapReady: () {
                        final from = _restaurantPointForRoute(order);
                        final to = customerPoint;
                        if (from != null && to != null) {
                          _fitMapToRoute(from, to);
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName:
                            'com.sweet.shop.flutter_sweet_shop_app_ui',
                      ),
                      if (routePoints.isNotEmpty) ...[
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: routePoints,
                              strokeWidth: 12,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ],
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: routePoints,
                              strokeWidth: 5,
                              color: _navRouteBlue,
                            ),
                          ],
                        ),
                      ],
                      MarkerLayer(
                        markers: [
                          if (customerPoint != null)
                            Marker(
                              point: customerPoint,
                              width: 44,
                              height: 44,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap:
                                    () => setState(
                                      () => _showLocationCard = true,
                                    ),
                                child: Icon(
                                  Icons.location_on,
                                  color: colors.error,
                                  size: 40,
                                ),
                              ),
                            ),
                          if (restaurantMarkerPoint != null)
                            Marker(
                              point: restaurantMarkerPoint,
                              width: 48,
                              height: 48,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap:
                                    () => setState(
                                      () => _showLocationCard = true,
                                    ),
                                child: Icon(
                                  Icons.store_mall_directory_rounded,
                                  color: Colors.deepOrange.shade700,
                                  size: 40,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_showLocationCard || showRouteChip)
                  Positioned(
                    left: 72,
                    right: 14,
                    top: mq.padding.top + 76,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_showLocationCard)
                          Material(
                            elevation: 6,
                            shadowColor: Colors.black26,
                            borderRadius: BorderRadius.circular(16),
                            color: colors.white.withValues(alpha: 0.96),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: mq.size.height * 0.42,
                                  ),
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      14,
                                      44,
                                      14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Müşteri · teslimat',
                                          style: typography.labelSmall.copyWith(
                                            color: colors.gray4,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _customerNameLine(order),
                                          style: typography.titleSmall.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: colors.black,
                                            height: 1.25,
                                          ),
                                        ),
                                        if (_customerPhoneLine(order) !=
                                            null) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Icon(
                                                  Icons.phone_rounded,
                                                  size: 16,
                                                  color: colors.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  _customerPhoneLine(order)!,
                                                  style: typography.bodySmall
                                                      .copyWith(
                                                        color: colors.gray4,
                                                        height: 1.4,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              child: Icon(
                                                Icons.location_on_rounded,
                                                size: 18,
                                                color: colors.error,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                deliveryAddrLine ??
                                                    'Adres yükleniyor…',
                                                style: typography.bodySmall
                                                    .copyWith(
                                                      color: colors.gray4,
                                                      height: 1.45,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          child: Divider(
                                            height: 1,
                                            color: colors.gray.withValues(
                                              alpha: 0.25,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Pastane · ürün alımı',
                                          style: typography.labelSmall.copyWith(
                                            color: colors.gray4,
                                            fontWeight: FontWeight.w600,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _restaurantTitleLine(order),
                                          style: typography.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w700,
                                            height: 1.35,
                                          ),
                                        ),
                                        if (_restaurantStreetOnly(order) !=
                                            null) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Icon(
                                                  Icons
                                                      .store_mall_directory_rounded,
                                                  size: 18,
                                                  color: colors.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  _restaurantStreetOnly(order)!,
                                                  style: typography.bodySmall
                                                      .copyWith(
                                                        color: colors.gray4,
                                                        height: 1.45,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 2,
                                  child: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    onPressed:
                                        () => setState(
                                          () => _showLocationCard = false,
                                        ),
                                    icon: Icon(
                                      Icons.close,
                                      color: colors.gray4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (showRouteChip) ...[
                          if (_showLocationCard) const SizedBox(height: 10),
                          Center(
                            child: Material(
                              elevation: 5,
                              shadowColor: Colors.black26,
                              borderRadius: BorderRadius.circular(10),
                              color: colors.white,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.directions_car_rounded,
                                          size: 20,
                                          color: _navRouteBlue,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_fullRouteResult!.totalDurationMinutes} dk · ${_fullRouteResult!.totalDistanceKm!.toStringAsFixed(1)} km',
                                          style: typography.labelLarge.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 28),
                                      child: Text(
                                        'Pastane → müşteri (yol)',
                                        style: typography.labelSmall.copyWith(
                                          color: colors.gray4,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                Positioned(
                  left: 14,
                  bottom: controlsBottom,
                  child: Material(
                    color: colors.white,
                    elevation: 8,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            final from = _restaurantPointFromOrder(order);
                            final to = customerPoint;
                            if (from != null && to != null) {
                              _fitMapToRoute(from, to);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.alt_route_rounded,
                              color: colors.primary,
                              size: 24,
                            ),
                          ),
                        ),
                        Container(
                          height: 1,
                          width: 40,
                          color: colors.gray.withValues(alpha: 0.2),
                        ),
                        InkWell(
                          onTap: () => _zoomBy(1),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.add,
                              color: colors.primary,
                              size: 24,
                            ),
                          ),
                        ),
                        Container(
                          height: 1,
                          width: 40,
                          color: colors.gray.withValues(alpha: 0.2),
                        ),
                        InkWell(
                          onTap: () => _zoomBy(-1),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.remove,
                              color: colors.primary,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: controlsBottom,
                  child: Material(
                    color: colors.primary.withValues(alpha: 0.14),
                    elevation: 8,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => _openDeliveryChat(order),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          color: colors.primary,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Material(
                    elevation: 16,
                    shadowColor: Colors.black26,
                    color: colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: scrollMaxH),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(
                              Dimens.largePadding,
                              Dimens.padding,
                              Dimens.largePadding,
                              8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Teslimat için önce müşteri adresi, ürün alımı için pastane. Mavi çizgi pastane → müşteri yol rotasıdır; kırmızı pin müşteri, turuncu ikon pastane.',
                                  style: typography.bodySmall.copyWith(
                                    color: colors.gray4,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Adres kartını açıp kapatmak için kırmızı pin veya pastane ikonuna dokunabilirsiniz.',
                                  style: typography.bodySmall.copyWith(
                                    color: colors.gray4,
                                    height: 1.3,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    final from = _restaurantPointFromOrder(
                                      order,
                                    );
                                    final to = customerPoint;
                                    if (from != null && to != null) {
                                      _fitMapToRoute(from, to);
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.gps_not_fixed,
                                        size: 20,
                                        color: colors.gray4,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Rotaya göre harita (önerilen)',
                                          style: typography.bodySmall.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  trackingSubtitle,
                                  style: typography.bodySmall.copyWith(
                                    color: colors.gray4,
                                    fontSize: 12,
                                    height: 1.25,
                                  ),
                                ),
                                if (routeMatchesFocus &&
                                    customerLiveTracking &&
                                    _fullRouteResult!.totalDistanceKm != null &&
                                    _fullRouteResult!.totalDurationMinutes !=
                                        null) ...[
                                  const SizedBox(height: Dimens.padding),
                                  _CustomerDeliveryRouteEtaStrip(
                                    km: _fullRouteResult!.totalDistanceKm!,
                                    minutes:
                                        _fullRouteResult!.totalDurationMinutes!,
                                  ),
                                ],
                                const SizedBox(height: Dimens.padding),
                                Text(
                                  'Teslimat Adresi',
                                  style: typography.titleSmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: Dimens.padding),
                                if (deliveryAddrLine != null)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: colors.gray.withValues(
                                        alpha: 0.06,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: colors.error.withValues(
                                          alpha: 0.55,
                                        ),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order.items,
                                          style: typography.bodyMedium,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.location_on_rounded,
                                              size: 18,
                                              color: colors.error,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                deliveryAddrLine,
                                                style: typography.bodySmall
                                                    .copyWith(
                                                      color: colors.gray4,
                                                      height: 1.35,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (order.time.isNotEmpty ||
                                            order.date.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              '${order.date} ${order.time}',
                                              style: typography.bodySmall
                                                  .copyWith(
                                                    color: colors.gray4,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                if (customerPoint == null) ...[
                                  const SizedBox(height: Dimens.padding),
                                  Text(
                                    'Teslimat konumu netleştiriliyor…',
                                    style: typography.bodySmall.copyWith(
                                      color: colors.gray4,
                                    ),
                                  ),
                                ],
                                if (_courier != null) ...[
                                  const SizedBox(height: Dimens.padding),
                                  _CourierRow(courier: _courier!),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            10,
                            16,
                            10 + mq.padding.bottom,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                customerLiveTracking
                                    ? Icons.gps_fixed
                                    : Icons.gps_not_fixed,
                                color:
                                    customerLiveTracking
                                        ? colors.success
                                        : colors.gray4,
                                size: 26,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  customerLiveTracking
                                      ? 'Canlı Konum Takibi Aktif'
                                      : (!liveHubEligible
                                          ? 'Canlı takip kurye yola çıkınca açılır'
                                          : 'Kurye takibi bekleniyor'),
                                  style: typography.titleSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  CustomerOrderModel? _findOrder(List<CustomerOrderModel> orders, String id) {
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }
}

/// Kurye [CourierTrackingScreen] içindeki `_DeliveryRouteEtaStrip` ile aynı metin ve ölçüler.
class _CustomerDeliveryRouteEtaStrip extends StatelessWidget {
  const _CustomerDeliveryRouteEtaStrip({
    required this.km,
    required this.minutes,
  });

  final double km;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.gray.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.gray.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${km.toStringAsFixed(1)} km',
                  style: typography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
                Text(
                  'Pastane → müşteri',
                  style: typography.bodySmall.copyWith(
                    color: colors.gray4,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: colors.gray.withValues(alpha: 0.25),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$minutes dk',
                  style: typography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
                Text(
                  'Tahmini sürüş (yol)',
                  style: typography.bodySmall.copyWith(
                    color: colors.gray4,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourierRow extends StatelessWidget {
  const _CourierRow({required this.courier});

  final CourierDetailsModel courier;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.gray.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.gray.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage:
                courier.photoUrl != null && courier.photoUrl!.isNotEmpty
                    ? NetworkImage(courier.photoUrl!)
                    : null,
            child:
                courier.photoUrl == null || courier.photoUrl!.isEmpty
                    ? Icon(Icons.person, color: colors.gray4)
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              courier.fullName.isEmpty ? 'Kurye' : courier.fullName,
              style: typography.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
