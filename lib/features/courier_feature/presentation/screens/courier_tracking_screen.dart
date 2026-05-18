import 'dart:async';
import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/google_geocoding_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/route_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/delivery_chat_panel.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/data/models/courier_order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/bloc/courier_location_cubit.dart'
    show CourierLocationCubit, CourierLocationState, CourierLocationStatus;
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/bloc/courier_orders_cubit.dart';
import 'package:latlong2/latlong.dart';

class CourierTrackingScreen extends StatefulWidget {
  const CourierTrackingScreen({super.key, this.selectedOrder});

  final CourierOrderModel? selectedOrder;

  @override
  State<CourierTrackingScreen> createState() => _CourierTrackingScreenState();
}

class _CourierTrackingScreenState extends State<CourierTrackingScreen> {
  final MapController _mapController = MapController();
  final GoogleGeocodingService _geocodingService = GoogleGeocodingService();
  final RouteService _routeService = RouteService();
  late final CourierLocationCubit _locationCubit;
  RouteResult? _routeResult;

  /// Basarili son OSRM cevabi hangi uca ait (siparis + pastane/musteri koordinatlari).
  String? _routeCacheKey;

  /// Ayni anahtar icin zaten devam eden istek (OSRM spam onleme).
  String? _routeFetchInflightKey;
  CourierOrdersCubit? _ordersCubitRef;

  /// Adres metninden geocode edilen koordinatlar (order.id -> LatLng)
  final Map<String, LatLng> _geocodedAddresses = {};
  final Set<String> _geocodingInProgress = {};
  final Map<String, LatLng> _geocodedRestaurants = {};
  final Set<String> _geocodingRestaurantIds = {};

  /// Varsayılan: pastane→müşteri rotası (sürüş modu hissi); açılırsa kurye GPS takibi.
  bool _followCourier = false;
  bool _deliverInProgress = false;

  /// Müşteri + pastane özeti; yalnızca haritadaki müşteri/pastane ikonuna dokunulunca açılır.
  bool _showDeliverySummary = false;

  /// Listeden seçilen teslimat; üst kart + harita rotası buna göre güncellenir.
  String? _focusedOrderId;

  /// Hareketten rota yönü (GPS heading yoksa).
  LatLng? _lastCourierSample;
  double? _courseFromMotion;

  static const double _navigationZoom = 16.2;
  static const Color _navRouteBlue = Color(0xFF1A73E8);

  bool _orderIdEq(String a, String b) => a.toLowerCase() == b.toLowerCase();

  String _latLngRouteKey(LatLng p) =>
      '${p.latitude.toStringAsFixed(6)};${p.longitude.toStringAsFixed(6)}';

  /// Gecode veya API sonrasi uç degisince anahtar degisir; rota yeniden cekilir.
  String? _routeEndpointsCacheKey(CourierOrderModel order) {
    final from = _getRestaurantLatLng(order);
    final to = _getCustomerLatLng(order);
    if (from == null || to == null) return null;
    return '${order.id.toLowerCase()}|${_latLngRouteKey(from)}|${_latLngRouteKey(to)}';
  }

  void _clearRouteState() {
    _routeResult = null;
    _routeCacheKey = null;
    _routeFetchInflightKey = null;
  }

  void _updateCourseFromMotion(LatLng courierPoint) {
    const dist = Distance();
    if (_lastCourierSample != null) {
      if (dist(_lastCourierSample!, courierPoint) >= 4) {
        _courseFromMotion = dist.bearing(_lastCourierSample!, courierPoint);
        _lastCourierSample = courierPoint;
      }
    } else {
      _lastCourierSample = courierPoint;
    }
  }

  /// Siparişler sekmesindeki "Yolda" ile aynı (ürün alındı / yola çıktı).
  bool _isOnTheWay(CourierOrderModel o) {
    return o.status == CourierOrderStatus.pickedUp ||
        o.status == CourierOrderStatus.inTransit;
  }

  /// Kurye motosikleti canlı GPS’ten çizilmez; pastane çıkışını temsil eder.
  /// Pastane ikonu (48px) ile çakışmayacak şekilde rota boyuna göre mesafe seçilir.
  LatLng? _courierDepartureIconPoint(CourierOrderModel? mapOrder) {
    if (mapOrder == null) return null;
    final rest = _getRestaurantLatLng(mapOrder);
    if (rest == null) return null;
    final cust = _getCustomerLatLng(mapOrder);
    if (cust == null || !_latLngDistinct(rest, cust)) {
      return rest;
    }
    const d = Distance();
    final brg = d.bearing(rest, cust);
    final lineM = d.as(LengthUnit.Meter, rest, cust);
    if (lineM < 80) {
      // Kısa rota: müşteri yönünde ilerlemek pinleri üst üste bırakır; pastaneye dik kaydır
      return d.offset(rest, 58, (brg + 85) % 360);
    }
    final alongM = min(120.0, max(70.0, lineM * 0.16));
    final clamped = min(alongM, lineM * 0.44);
    return d.offset(rest, clamped, brg);
  }

  /// Pastane ile müşteri GPS’i çok yakınsa kırmızı pin turuncu ile üst üste binmesin.
  LatLng? _customerPinForMap(LatLng? cust, LatLng? rest) {
    if (cust == null) return null;
    if (rest == null) return cust;
    const d = Distance();
    final m = d.as(LengthUnit.Meter, rest, cust);
    if (m >= 55) return cust;
    if (m < 1) {
      return d.offset(cust, 56, 90);
    }
    final brg = d.bearing(rest, cust);
    return d.offset(cust, 52, (brg + 90) % 360);
  }

  String? _primaryOrderIdForMap(CourierLocationCubit loc) {
    final sel = widget.selectedOrder;
    if (sel != null && _isOnTheWay(sel)) return sel.id;
    if (_focusedOrderId != null) return _focusedOrderId;
    return loc.activeTrackingOrderId;
  }

  String _wantTrackingOrderId(
    List<CourierOrderModel> active,
    CourierLocationCubit loc,
  ) {
    final pref = _primaryOrderIdForMap(loc);
    if (pref != null) {
      for (final o in active) {
        if (_orderIdEq(o.id, pref)) return o.id;
      }
    }
    return active.first.id;
  }

  void _sortOrdersByMapPrime(
    List<CourierOrderModel> list,
    CourierLocationCubit loc,
  ) {
    final prime = _primaryOrderIdForMap(loc);
    if (prime == null) return;
    final p = prime;
    list.sort((a, b) {
      final aP = _orderIdEq(a.id, p);
      final bP = _orderIdEq(b.id, p);
      if (aP == bP) return 0;
      return aP ? -1 : 1;
    });
  }

  /// Harita: yalnızca Siparişler sekmesindeki "Yolda" (pickedUp / inTransit).
  List<CourierOrderModel> _trackableOrdersForMap(
    List<CourierOrderModel> orders,
    CourierLocationCubit loc,
  ) {
    final list = orders.where(_isOnTheWay).toList();
    _sortOrdersByMapPrime(list, loc);
    return list;
  }

  /// Teslimat Adresi listesi — sadece Yolda (Bekleyen burada görünmez).
  List<CourierOrderModel> _deliveryAddressListOrders(
    List<CourierOrderModel> orders,
    CourierLocationCubit loc,
  ) {
    final list = orders.where(_isOnTheWay).toList();
    _sortOrdersByMapPrime(list, loc);
    return list;
  }

  CourierOrderModel? _focusedOrder(List<CourierOrderModel> active) {
    if (active.isEmpty) return null;
    if (_focusedOrderId != null) {
      for (final o in active) {
        if (_orderIdEq(o.id, _focusedOrderId!)) return o;
      }
    }
    return active.first;
  }

  void _onDeliveryRowTapped(CourierOrderModel order) {
    setState(() {
      _focusedOrderId = order.id;
      _showDeliverySummary = false;
      _clearRouteState();
      _followCourier = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final orders = context.read<CourierOrdersCubit>().state;
      await _syncTrackingWithOrdersList(orders);
      if (!mounted) return;
      _fitFocusedDelivery(order, context.read<CourierLocationCubit>().state);
    });
  }

  void _fitFocusedDelivery(CourierOrderModel order, CourierLocationState loc) {
    final rest = _getRestaurantLatLng(order);
    final cust = _getCustomerLatLng(order);
    final cou = _safeLatLng(loc.latitude, loc.longitude);
    final pts = <LatLng>[];
    if (rest != null) {
      pts.add(rest);
    }
    if (cust != null) {
      pts.add(cust);
    }
    final routePts = _sanitizePolylinePoints(
      _routeResult?.polylinePoints ?? const <LatLng>[],
    );
    if (routePts.length >= 2) {
      pts.addAll(routePts);
    }
    if (_followCourier &&
        loc.status == CourierLocationStatus.tracking &&
        cou != null) {
      pts.add(cou);
    }
    if (pts.isEmpty) {
      return;
    }
    final lat = pts.map((e) => e.latitude).reduce((a, b) => a + b) / pts.length;
    final lng =
        pts.map((e) => e.longitude).reduce((a, b) => a + b) / pts.length;
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: pts,
          padding: const EdgeInsets.fromLTRB(28, 96, 28, 268),
        ),
      );
    } catch (_) {
      _mapController.moveAndRotate(LatLng(lat, lng), 14, 0);
    }
  }

  Future<void> _syncTrackingWithOrdersList(
    List<CourierOrderModel> orders,
  ) async {
    if (!mounted) return;
    final loc = context.read<CourierLocationCubit>();
    final active = _trackableOrdersForMap(orders, loc);
    await loc.reconcileTrackingWithOrders(
      orders,
      preferredOrderId: _primaryOrderIdForMap(loc),
    );
    if (!mounted) return;
    if (active.isEmpty) {
      setState(() {
        _clearRouteState();
        _focusedOrderId = null;
      });
    }
  }

  bool _isValidLatLng(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  LatLng? _safeLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (_isValidLatLng(lat, lng)) return LatLng(lat, lng);
    // Bazı veri kaynaklarında lat/lng alanları yer değiştirmiş gelebilir.
    if (_isValidLatLng(lng, lat)) return LatLng(lng, lat);
    return null;
  }

  /// Aynı konumdaysa müşteri + pastane üst üste binmesin (tek pin yeter).
  bool _latLngDistinct(LatLng? a, LatLng? b) {
    if (a == null || b == null) return true;
    const eps = 1e-5;
    return (a.latitude - b.latitude).abs() > eps ||
        (a.longitude - b.longitude).abs() > eps;
  }

  List<LatLng> _sanitizePolylinePoints(List<LatLng> points) {
    return points
        .where((p) => _isValidLatLng(p.latitude, p.longitude))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _focusedOrderId = widget.selectedOrder?.id;
    _locationCubit = context.read<CourierLocationCubit>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _ordersCubitRef = context.read<CourierOrdersCubit>();
      _ordersCubitRef?.setPollingIntervalSeconds(2);
      final orders = context.read<CourierOrdersCubit>().state;
      await _syncTrackingWithOrdersList(orders);
    });
  }

  @override
  void dispose() {
    _ordersCubitRef?.setPollingIntervalSeconds(4);
    super.dispose();
  }

  Future<void> _geocodeRestaurantIfNeeded(CourierOrderModel order) async {
    if (_safeLatLng(order.restaurantLat, order.restaurantLng) != null) {
      return;
    }
    final addr = order.restaurantAddress?.trim() ?? '';
    if (addr.isEmpty ||
        _geocodedRestaurants.containsKey(order.id) ||
        _geocodingRestaurantIds.contains(order.id)) {
      return;
    }
    _geocodingRestaurantIds.add(order.id);
    final result = await _geocodingService.geocodeAddress(addr);
    _geocodingRestaurantIds.remove(order.id);
    if (result != null && mounted) {
      final point = _safeLatLng(result.latitude, result.longitude);
      if (point == null) {
        return;
      }
      setState(() => _geocodedRestaurants[order.id] = point);
    }
  }

  Future<void> _geocodeOrderAddress(CourierOrderModel order) async {
    if (order.customerAddress.trim().isEmpty ||
        order.customerLat != null ||
        _geocodedAddresses.containsKey(order.id) ||
        _geocodingInProgress.contains(order.id)) {
      return;
    }
    _geocodingInProgress.add(order.id);
    final result = await _geocodingService.geocodeAddress(
      order.customerAddress,
    );
    _geocodingInProgress.remove(order.id);
    if (result != null && mounted) {
      final point = _safeLatLng(result.latitude, result.longitude);
      if (point == null) return;
      setState(() {
        _geocodedAddresses[order.id] = point;
      });
    }
  }

  LatLng? _getCustomerLatLng(CourierOrderModel order) {
    return _safeLatLng(order.customerLat, order.customerLng) ??
        _geocodedAddresses[order.id];
  }

  LatLng? _getRestaurantLatLng(CourierOrderModel order) {
    return _safeLatLng(order.restaurantLat, order.restaurantLng) ??
        _geocodedRestaurants[order.id];
  }

  Future<void> _fetchRouteIfNeeded(CourierOrderModel? order) async {
    if (order == null) return;
    final from = _getRestaurantLatLng(order);
    final to = _getCustomerLatLng(order);
    if (from == null || to == null) return;

    final key = _routeEndpointsCacheKey(order);
    if (key == null) return;
    if (_routeCacheKey == key && _routeResult != null) return;
    if (_routeFetchInflightKey == key) return;

    _routeFetchInflightKey = key;
    try {
      final result = await _routeService.getRoute(
        from: from,
        to: to,
        courierPosition: null,
      );
      if (!mounted) return;
      if (_routeEndpointsCacheKey(order) != key) {
        return;
      }
      if (result != null) {
        final oid = order.id;
        setState(() {
          _routeResult = result;
          _routeCacheKey = key;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _followCourier) {
            return;
          }
          final orders = context.read<CourierOrdersCubit>().state;
          final loc = context.read<CourierLocationCubit>();
          final fo = _focusedOrder(_trackableOrdersForMap(orders, loc));
          if (fo != null && _orderIdEq(fo.id, oid)) {
            _fitFocusedDelivery(fo, context.read<CourierLocationCubit>().state);
          }
        });
      }
    } finally {
      if (_routeFetchInflightKey == key) {
        _routeFetchInflightKey = null;
      }
    }
  }

  void _zoomBy(double delta) {
    final cam = _mapController.camera;
    final next = (cam.zoom + delta).clamp(4.0, 19.0);
    _mapController.move(cam.center, next);
  }

  void _openDeliveryChat(CourierOrderModel order) {
    final colors = context.theme.appColors;
    final peer =
        order.customerName != null && order.customerName!.trim().isNotEmpty
            ? 'Müşteri: ${order.customerName!.trim()}'
            : 'Teslimat sohbeti';
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
              orderId: order.id,
              title: peer,
            ),
          ),
        );
      },
    );
  }

  Future<void> _markOrderDelivered(CourierOrderModel order) async {
    if (_deliverInProgress) return;
    if (order.status == CourierOrderStatus.delivered) return;
    setState(() => _deliverInProgress = true);
    final cubit = context.read<CourierOrdersCubit>();
    try {
      if (order.status != CourierOrderStatus.inTransit) {
        await cubit.markInTransit(order.id);
      }
      await cubit.markDelivered(order.id);
      await cubit.loadOrders();
      if (!mounted) return;
      await _locationCubit.stopTracking(userInitiated: false);
      _locationCubit.releaseAutoRestartSuppression();
      if (mounted) {
        setState(_clearRouteState);
      }
      if (!mounted) return;
      final remaining = context.read<CourierOrdersCubit>().state;
      unawaited(_syncTrackingWithOrdersList(remaining));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sipariş teslim edildi.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Teslim işlemi başarısız: $e')));
    } finally {
      if (mounted) setState(() => _deliverInProgress = false);
    }
  }

  LatLng _mapCenter(CourierLocationState loc, CourierOrderModel? mapOrder) {
    final rest = mapOrder != null ? _getRestaurantLatLng(mapOrder) : null;
    final dest = mapOrder != null ? _getCustomerLatLng(mapOrder) : null;
    final courierPoint = _safeLatLng(loc.latitude, loc.longitude);
    if (rest != null && dest != null) {
      return LatLng(
        (rest.latitude + dest.latitude) / 2,
        (rest.longitude + dest.longitude) / 2,
      );
    }
    if (dest != null) {
      return dest;
    }
    if (rest != null) {
      return rest;
    }
    if (courierPoint != null) {
      return courierPoint;
    }
    return const LatLng(41.6757, 26.5548);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    // Tam ekran haritadan geri çıkmak takibi durdurmaz; cubit dashboard ile paylaşılır.
    // Durdurma yalnızca "Takibi Durdur" / AppBar aksiyonlarında yapılır.
    return BlocListener<CourierOrdersCubit, List<CourierOrderModel>>(
      listener: (context, orders) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final loc = context.read<CourierLocationCubit>();
          final active = _trackableOrdersForMap(orders, loc);
          if (_focusedOrderId != null &&
              !active.any((o) => _orderIdEq(o.id, _focusedOrderId!))) {
            setState(() {
              _focusedOrderId = null;
              _clearRouteState();
            });
          }
          unawaited(_syncTrackingWithOrdersList(orders));
        });
      },
      child: BlocConsumer<CourierLocationCubit, CourierLocationState>(
        listener: (context, locState) {
          final courierPoint = _safeLatLng(
            locState.latitude,
            locState.longitude,
          );
          if (locState.status != CourierLocationStatus.tracking) {
            _lastCourierSample = null;
            _courseFromMotion = null;
          } else if (courierPoint != null) {
            _updateCourseFromMotion(courierPoint);
          }
          if (!_followCourier || courierPoint == null) {
            return;
          }
          final orders = context.read<CourierOrdersCubit>().state;
          final locCubit = context.read<CourierLocationCubit>();
          final mapOrder = _focusedOrder(
            _trackableOrdersForMap(orders, locCubit),
          );
          final dest = mapOrder != null ? _getCustomerLatLng(mapOrder) : null;
          if (locState.status == CourierLocationStatus.tracking) {
            var rotation = 0.0;
            final h = locState.heading;
            if (h != null && h.isFinite) {
              rotation = h % 360.0;
            } else if (dest != null) {
              rotation = const Distance().bearing(courierPoint, dest);
            } else if (_courseFromMotion != null) {
              rotation = _courseFromMotion!;
            }
            _mapController.moveAndRotate(
              courierPoint,
              _navigationZoom,
              rotation,
            );
          } else {
            _mapController.moveAndRotate(courierPoint, 14.5, 0);
          }
        },
        buildWhen:
            (prev, curr) =>
                prev.latitude != curr.latitude ||
                prev.longitude != curr.longitude ||
                prev.status != curr.status ||
                prev.heading != curr.heading,
        builder: (context, locState) {
          return BlocBuilder<CourierOrdersCubit, List<CourierOrderModel>>(
            builder: (context, orders) {
              final locCubit = context.read<CourierLocationCubit>();
              final mapOrders = _trackableOrdersForMap(orders, locCubit);
              final deliveryAddressOrders = _deliveryAddressListOrders(
                orders,
                locCubit,
              );
              final mapOrder = _focusedOrder(mapOrders);
              final primaryCustomerLL =
                  mapOrder != null ? _getCustomerLatLng(mapOrder) : null;
              final primaryRestaurantLL =
                  mapOrder != null ? _getRestaurantLatLng(mapOrder) : null;

              for (final order in mapOrders) {
                _geocodeOrderAddress(order);
                _geocodeRestaurantIfNeeded(order);
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _fetchRouteIfNeeded(mapOrder);
              });

              final routeMatchesFocus =
                  mapOrder != null &&
                  _routeResult != null &&
                  _routeCacheKey != null &&
                  _routeEndpointsCacheKey(mapOrder) == _routeCacheKey;

              var routePoints = <LatLng>[];
              if (routeMatchesFocus) {
                routePoints = _sanitizePolylinePoints(
                  _routeResult?.polylinePoints ?? const <LatLng>[],
                );
              }
              if (routePoints.isEmpty &&
                  primaryRestaurantLL != null &&
                  primaryCustomerLL != null &&
                  _latLngDistinct(primaryCustomerLL, primaryRestaurantLL)) {
                routePoints = [primaryRestaurantLL, primaryCustomerLL];
              }
              final courierDepartIconPt =
                  locState.status == CourierLocationStatus.tracking &&
                          mapOrder != null
                      ? _courierDepartureIconPoint(mapOrder)
                      : null;
              final customerPinLL = _customerPinForMap(
                primaryCustomerLL,
                primaryRestaurantLL,
              );

              final mq = MediaQuery.of(context);
              const footerTrackingH = 64.0;
              final scrollMaxH = mq.size.height * 0.34;
              final bottomPanelH =
                  scrollMaxH + footerTrackingH + mq.padding.bottom;
              final controlsBottom = bottomPanelH + 16;

              return AppScaffold(
                extendBodyBehindAppBar: true,
                safeAreaTop: false,
                safeAreaLeft: false,
                safeAreaRight: false,
                safeAreaBottom: false,
                appBar: GeneralAppBar(
                  title: 'Teslimat rotası',
                  showBackIcon: widget.selectedOrder != null,
                ),
                padding: EdgeInsets.zero,
                body: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _mapCenter(locState, mapOrder),
                          initialZoom:
                              _followCourier &&
                                      locState.status ==
                                          CourierLocationStatus.tracking
                                  ? _navigationZoom
                                  : 14.2,
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.pinchZoom |
                                InteractiveFlag.drag |
                                InteractiveFlag.doubleTapZoom |
                                InteractiveFlag.flingAnimation,
                          ),
                          onMapReady: () {
                            if (mapOrder != null && !_followCourier) {
                              _fitFocusedDelivery(mapOrder, locState);
                            }
                          },
                          onPositionChanged: (camera, hasGesture) {
                            if (hasGesture) {
                              setState(() => _followCourier = false);
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
                              if (primaryRestaurantLL != null &&
                                  _latLngDistinct(
                                    primaryCustomerLL,
                                    primaryRestaurantLL,
                                  ))
                                Marker(
                                  key: const ValueKey('rest_marker'),
                                  point: primaryRestaurantLL,
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap:
                                        () => setState(
                                          () => _showDeliverySummary = true,
                                        ),
                                    child: Icon(
                                      Icons.store_mall_directory_rounded,
                                      color: Colors.deepOrange.shade700,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              if (courierDepartIconPt != null)
                                Marker(
                                  key: const ValueKey('courier_marker'),
                                  point: courierDepartIconPt,
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.delivery_dining,
                                    color: colors.primary,
                                    size: 44,
                                  ),
                                ),
                              if (customerPinLL != null)
                                Marker(
                                  key: const ValueKey('cust_marker'),
                                  point: customerPinLL,
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap:
                                        () => setState(
                                          () => _showDeliverySummary = true,
                                        ),
                                    child: Icon(
                                      Icons.location_on,
                                      color: colors.error,
                                      size: 40,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (mapOrder != null &&
                        (_showDeliverySummary ||
                            (routeMatchesFocus &&
                                locState.status ==
                                    CourierLocationStatus.tracking &&
                                _routeResult?.totalDistanceKm != null &&
                                _routeResult?.totalDurationMinutes != null)))
                      Positioned(
                        left: 72,
                        right: 14,
                        top: mq.padding.top + 76,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_showDeliverySummary)
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
                                              style: typography.labelSmall
                                                  .copyWith(
                                                    color: colors.gray4,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              mapOrder.customerName
                                                          ?.trim()
                                                          .isNotEmpty ==
                                                      true
                                                  ? mapOrder.customerName!
                                                      .trim()
                                                  : 'Müşteri',
                                              style: typography.titleSmall
                                                  .copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    color: colors.black,
                                                    height: 1.2,
                                                  ),
                                            ),
                                            if (mapOrder.customerPhone !=
                                                    null &&
                                                mapOrder.customerPhone!
                                                    .trim()
                                                    .isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
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
                                                      mapOrder.customerPhone!
                                                          .trim(),
                                                      style: typography
                                                          .bodySmall
                                                          .copyWith(
                                                            color: colors.gray4,
                                                            height: 1.35,
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
                                                  padding:
                                                      const EdgeInsets.only(
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
                                                    mapOrder.customerAddress,
                                                    style: typography.bodySmall
                                                        .copyWith(
                                                          color: colors.gray4,
                                                          height: 1.35,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                              style: typography.labelSmall
                                                  .copyWith(
                                                    color: colors.gray4,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.2,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              mapOrder.restaurantName
                                                          ?.trim()
                                                          .isNotEmpty ==
                                                      true
                                                  ? mapOrder.restaurantName!
                                                      .trim()
                                                  : 'Pastane',
                                              style: typography.bodyMedium
                                                  .copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    height: 1.25,
                                                  ),
                                            ),
                                            if (mapOrder.restaurantAddress !=
                                                    null &&
                                                mapOrder.restaurantAddress!
                                                    .trim()
                                                    .isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
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
                                                      mapOrder
                                                          .restaurantAddress!
                                                          .trim(),
                                                      style: typography
                                                          .bodySmall
                                                          .copyWith(
                                                            color: colors.gray4,
                                                            height: 1.35,
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
                                              () =>
                                                  _showDeliverySummary = false,
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
                            if (routeMatchesFocus &&
                                locState.status ==
                                    CourierLocationStatus.tracking &&
                                _routeResult?.totalDistanceKm != null &&
                                _routeResult?.totalDurationMinutes != null) ...[
                              if (_showDeliverySummary)
                                const SizedBox(height: 10),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                              '${_routeResult!.totalDurationMinutes} dk · ${_routeResult!.totalDistanceKm!.toStringAsFixed(1)} km',
                                              style: typography.labelLarge
                                                  .copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: colors.black,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 28,
                                          ),
                                          child: Text(
                                            'Pastane → müşteri (yol)',
                                            style: typography.labelSmall
                                                .copyWith(
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
                                final fo = mapOrder;
                                if (fo == null) {
                                  return;
                                }
                                setState(() => _followCourier = false);
                                _fitFocusedDelivery(
                                  fo,
                                  context.read<CourierLocationCubit>().state,
                                );
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
                    if (mapOrder != null)
                      Positioned(
                        right: 14,
                        bottom: controlsBottom,
                        child: Material(
                          color: colors.primary.withValues(alpha: 0.14),
                          elevation: 8,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () => _openDeliveryChat(mapOrder),
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
                              constraints: BoxConstraints(
                                maxHeight: scrollMaxH,
                              ),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  Dimens.largePadding,
                                  Dimens.padding,
                                  Dimens.largePadding,
                                  8,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (locState.message != null &&
                                        locState.message!
                                            .trim()
                                            .isNotEmpty) ...[
                                      Text(
                                        locState.message!,
                                        style: typography.bodySmall.copyWith(
                                          color: colors.error,
                                        ),
                                      ),
                                      const SizedBox(height: Dimens.padding),
                                    ],
                                    Text(
                                      'Teslimat için önce müşteri adresi, ürün alımı için pastane. Mavi çizgi pastane → müşteri yol rotasıdır; kırmızı pin müşteri, turuncu ikon pastane. Kırmızı motosiklet pastane çıkışını gösterir (canlı GPS konumunuzdan bağımsızdır).',
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
                                      onTap:
                                          () => setState(
                                            () =>
                                                _followCourier =
                                                    !_followCourier,
                                          ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _followCourier
                                                ? Icons.gps_fixed
                                                : Icons.gps_not_fixed,
                                            size: 20,
                                            color:
                                                _followCourier
                                                    ? colors.primary
                                                    : colors.gray4,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _followCourier
                                                  ? 'Harita kurye konumunu takip ediyor'
                                                  : 'Rotaya göre harita (önerilen)',
                                              style: typography.bodySmall
                                                  .copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: colors.black,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (routeMatchesFocus &&
                                        locState.status ==
                                            CourierLocationStatus.tracking &&
                                        _routeResult!.totalDistanceKm != null &&
                                        _routeResult!.totalDurationMinutes !=
                                            null) ...[
                                      const SizedBox(height: Dimens.padding),
                                      _DeliveryRouteEtaStrip(
                                        km: _routeResult!.totalDistanceKm!,
                                        minutes:
                                            _routeResult!.totalDurationMinutes!,
                                      ),
                                    ],
                                    if (deliveryAddressOrders.isNotEmpty) ...[
                                      const SizedBox(height: Dimens.padding),
                                      Text(
                                        'Teslimat Adresi',
                                        style: typography.titleSmall.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: Dimens.padding),
                                      ...deliveryAddressOrders.map((order) {
                                        final isSelected =
                                            mapOrder != null &&
                                            _orderIdEq(order.id, mapOrder.id);
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: Dimens.padding,
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap:
                                                  () => _onDeliveryRowTapped(
                                                    order,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: colors.gray.withValues(
                                                    alpha: 0.06,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        isSelected
                                                            ? colors.primary
                                                            : colors.gray
                                                                .withValues(
                                                                  alpha: 0.22,
                                                                ),
                                                    width: isSelected ? 2 : 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      order.items,
                                                      style:
                                                          typography.bodyMedium,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.location_on,
                                                          size: 16,
                                                          color: colors.primary,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            order
                                                                .customerAddress,
                                                            style: typography
                                                                .bodySmall
                                                                .copyWith(
                                                                  color:
                                                                      colors
                                                                          .gray4,
                                                                ),
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (order.customerPhone !=
                                                            null &&
                                                        order
                                                            .customerPhone!
                                                            .isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.phone,
                                                            size: 16,
                                                            color:
                                                                colors.primary,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            order
                                                                .customerPhone!,
                                                            style: typography
                                                                .bodySmall
                                                                .copyWith(
                                                                  color:
                                                                      colors
                                                                          .gray4,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                    if (mapOrder != null &&
                                        mapOrder.status !=
                                            CourierOrderStatus.delivered) ...[
                                      const SizedBox(height: Dimens.padding),
                                      FilledButton.icon(
                                        onPressed:
                                            _deliverInProgress
                                                ? null
                                                : () => _markOrderDelivered(
                                                  mapOrder,
                                                ),
                                        icon:
                                            _deliverInProgress
                                                ? SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: colors.white,
                                                      ),
                                                )
                                                : const Icon(
                                                  Icons.check_circle_outline,
                                                ),
                                        label: Text(
                                          _deliverInProgress
                                              ? 'İşleniyor…'
                                              : 'Siparişi teslim ettim',
                                        ),
                                      ),
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
                                4,
                                10 + mq.padding.bottom,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    locState.status ==
                                            CourierLocationStatus.tracking
                                        ? Icons.gps_fixed
                                        : Icons.gps_not_fixed,
                                    color:
                                        locState.status ==
                                                CourierLocationStatus.tracking
                                            ? colors.success
                                            : colors.gray4,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      locState.status ==
                                              CourierLocationStatus.tracking
                                          ? 'Canlı Konum Takibi Aktif'
                                          : _statusText(locState),
                                      style: typography.titleSmall.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (locState.status !=
                                          CourierLocationStatus.tracking &&
                                      mapOrders.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: () {
                                        context
                                            .read<CourierLocationCubit>()
                                            .startTracking(
                                              orderId: _wantTrackingOrderId(
                                                mapOrders,
                                                locCubit,
                                              ),
                                            );
                                      },
                                      icon: Icon(
                                        Icons.play_arrow,
                                        color: colors.primary,
                                        size: 22,
                                      ),
                                      label: Text(
                                        'Takibi Başlat',
                                        style: TextStyle(
                                          color: colors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  if (locState.status ==
                                      CourierLocationStatus.tracking)
                                    TextButton.icon(
                                      onPressed: () {
                                        context
                                            .read<CourierLocationCubit>()
                                            .stopTracking();
                                      },
                                      icon: Icon(
                                        Icons.stop,
                                        color: colors.error,
                                        size: 20,
                                      ),
                                      label: Text(
                                        'Takibi Durdur',
                                        style: TextStyle(
                                          color: colors.error,
                                          fontWeight: FontWeight.w600,
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
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _statusText(CourierLocationState state) {
    switch (state.status) {
      case CourierLocationStatus.tracking:
        return 'Canlı konum takibi aktif';
      case CourierLocationStatus.loading:
        return 'Konum alınıyor...';
      case CourierLocationStatus.denied:
        return 'Konum izni gerekli';
      case CourierLocationStatus.error:
        return 'Konum alınamadı';
      case CourierLocationStatus.success:
      case CourierLocationStatus.idle:
        return 'Takip beklemede';
    }
  }
}

/// Pastane → müşteri OSRM toplamı (üstteki chip ile aynı kaynak).
class _DeliveryRouteEtaStrip extends StatelessWidget {
  const _DeliveryRouteEtaStrip({required this.km, required this.minutes});

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
