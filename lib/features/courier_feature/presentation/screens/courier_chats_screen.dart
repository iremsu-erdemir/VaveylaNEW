import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/delivery_chat_message_model.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/delivery_chat_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/tracking_realtime_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_confirm_dialog.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/data/models/courier_order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/data/services/courier_chat_inbox_local_store.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/bloc/courier_nav_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/courier_feature/presentation/bloc/courier_orders_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/customer_delivery_chat_screen.dart';

class _DeliveryPreview {
  const _DeliveryPreview({required this.text, required this.activityUtc});

  final String text;
  final DateTime activityUtc;
}

enum _ChatListFilter {
  last10,
  lastWeek,
  lastMonth,
  all,
}

/// Kurye Sohbetler — ürün satırı üstte (kalın), gri altta son mesaj (veya durum · müşteri).
/// Son mesaj zamanına göre sıralı; SignalR ile yeni mesajda kart üste çıkar.
class CourierChatsScreen extends StatefulWidget {
  const CourierChatsScreen({super.key});

  @override
  State<CourierChatsScreen> createState() => _CourierChatsScreenState();
}

class _CourierChatsScreenState extends State<CourierChatsScreen> {
  Set<String> _hiddenOrderIds = {};
  final Map<String, _DeliveryPreview> _previewByOrderId = {};
  Set<String> _subscribedOrderIds = {};
  StreamSubscription<Map<String, dynamic>>? _deliveryChatSub;
  Timer? _previewPollTimer;
  String _lastVisibleIdsSig = '';
  final DeliveryChatService _chatService = DeliveryChatService();
  _ChatListFilter _selectedFilter = _ChatListFilter.last10;

  @override
  void initState() {
    super.initState();
    unawaited(_reloadHidden());
    _deliveryChatSub = TrackingRealtimeService.shared.deliveryChatMessages.listen(
      _onDeliveryChatPayload,
    );
    _previewPollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _pollPreviewsIfVisible(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final orders = context.read<CourierOrdersCubit>().state;
      final visible = _applyListFilter(
        orders.where(_eligible).where((o) => !_hiddenOrderIds.contains(o.id)).toList(),
      );
      _onVisibleOrdersChanged(visible);
    });
  }

  @override
  void dispose() {
    _previewPollTimer?.cancel();
    _deliveryChatSub?.cancel();
    for (final id in _subscribedOrderIds) {
      unawaited(TrackingRealtimeService.shared.unsubscribeOrder(id));
    }
    super.dispose();
  }

  Future<void> _reloadHidden() async {
    final uid = AppSession.userId;
    final s = await CourierChatInboxLocalStore.loadHiddenOrderIds(uid);
    if (!mounted) return;
    setState(() => _hiddenOrderIds = s);
    final orders = context.read<CourierOrdersCubit>().state;
    final visible = _applyListFilter(
      orders.where(_eligible).where((o) => !_hiddenOrderIds.contains(o.id)).toList(),
    );
    _onVisibleOrdersChanged(visible);
  }

  String? _resolveOrderIdForPayload(String rawOrderId) {
    final needle = rawOrderId.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final o in context.read<CourierOrdersCubit>().state) {
      if (o.id.toLowerCase() != needle) continue;
      if (_eligible(o) && !_hiddenOrderIds.contains(o.id)) {
        return o.id;
      }
    }
    return null;
  }

  void _onDeliveryChatPayload(Map<String, dynamic> map) {
    if (!mounted) return;
    final rawOid = map['orderId']?.toString() ?? '';
    final oid = _resolveOrderIdForPayload(rawOid);
    if (oid == null) return;
    try {
      final json = Map<String, dynamic>.from(
        map.map((k, v) => MapEntry(k.toString(), v)),
      );
      final m = DeliveryChatMessageModel.fromJson(json);
      final activity = m.editedAtUtc ?? m.createdAtUtc;
      setState(() {
        _previewByOrderId[oid] = _DeliveryPreview(text: m.message, activityUtc: activity);
      });
    } catch (_) {
      unawaited(_loadPreviewForOrderId(oid));
    }
  }

  void _pollPreviewsIfVisible() {
    if (!mounted) return;
    final orders = _applyListFilter(
      context.read<CourierOrdersCubit>().state.where(_eligible).where(
            (o) => !_hiddenOrderIds.contains(o.id),
          ).toList(),
    );
    if (orders.isEmpty) return;
    unawaited(_loadAllPreviews(orders));
  }

  Future<void> _syncSubscriptions(Set<String> needed) async {
    final prev = _subscribedOrderIds;
    for (final id in prev.difference(needed)) {
      try {
        await TrackingRealtimeService.shared.unsubscribeOrder(id);
      } catch (_) {}
    }
    for (final id in needed.difference(prev)) {
      try {
        await TrackingRealtimeService.shared.subscribeOrder(id);
      } catch (_) {}
    }
    _subscribedOrderIds = needed;
  }

  void _onVisibleOrdersChanged(List<CourierOrderModel> visible) {
    final sig = (visible.map((e) => e.id).toList()..sort()).join(',');
    if (sig != _lastVisibleIdsSig) {
      _lastVisibleIdsSig = sig;
      unawaited(_syncSubscriptions(visible.map((e) => e.id).toSet()));
    }
    unawaited(_loadAllPreviews(visible));
  }

  Future<void> _loadPreviewForOrderId(String orderId) async {
    final uid = AppSession.userId;
    if (uid.isEmpty || orderId.isEmpty || !mounted) return;
    try {
      final msgs = await _chatService.fetchMessages(orderId: orderId, userId: uid);
      if (!mounted) return;
      if (msgs.isEmpty) {
        setState(() => _previewByOrderId.remove(orderId));
        return;
      }
      final last = msgs.last;
      final activity = last.editedAtUtc ?? last.createdAtUtc;
      setState(() {
        _previewByOrderId[orderId] = _DeliveryPreview(
          text: last.message,
          activityUtc: activity,
        );
      });
    } catch (_) {}
  }

  Future<void> _loadAllPreviews(List<CourierOrderModel> orders) async {
    final uid = AppSession.userId;
    if (uid.isEmpty || !mounted || orders.isEmpty) return;

    const chunk = 6;
    final built = <String, _DeliveryPreview>{};

    for (var i = 0; i < orders.length; i += chunk) {
      if (!mounted) return;
      final slice = orders.sublist(i, min(i + chunk, orders.length));
      final chunkResults = await Future.wait(
        slice.map((o) async {
          try {
            final msgs = await _chatService.fetchMessages(orderId: o.id, userId: uid);
            if (msgs.isEmpty) {
              return MapEntry<String, _DeliveryPreview?>(o.id, null);
            }
            final last = msgs.last;
            final activity = last.editedAtUtc ?? last.createdAtUtc;
            return MapEntry(
              o.id,
              _DeliveryPreview(text: last.message, activityUtc: activity),
            );
          } catch (_) {
            return MapEntry<String, _DeliveryPreview?>(o.id, null);
          }
        }),
      );
      for (final e in chunkResults) {
        if (e.value != null) {
          built[e.key] = e.value!;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      for (final o in orders) {
        final p = built[o.id];
        if (p != null) {
          _previewByOrderId[o.id] = p;
        } else {
          _previewByOrderId.remove(o.id);
        }
      }
    });
  }

  static DateTime? _orderFallbackLocal(CourierOrderModel o) {
    try {
      final dp = o.date.split('.');
      if (dp.length == 3) {
        final day = int.parse(dp[0]);
        final month = int.parse(dp[1]);
        final year = int.parse(dp[2]);
        final tp = o.time.split(':');
        final h = int.parse(tp[0]);
        final min = tp.length > 1 ? int.parse(tp[1]) : 0;
        return DateTime(year, month, day, h, min);
      }
    } catch (_) {}
    return null;
  }

  static DateTime _activitySortKey(
    CourierOrderModel o,
    Map<String, _DeliveryPreview> previews,
  ) {
    final p = previews[o.id];
    if (p != null) return p.activityUtc;
    return _orderFallbackLocal(o)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime _createdAtSortKey(CourierOrderModel o) {
    return o.createdAtUtc ?? _orderFallbackLocal(o)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _filterThresholdUtc(_ChatListFilter filter) {
    final now = DateTime.now().toUtc();
    switch (filter) {
      case _ChatListFilter.lastWeek:
        return now.subtract(const Duration(days: 7));
      case _ChatListFilter.lastMonth:
        return now.subtract(const Duration(days: 30));
      case _ChatListFilter.last10:
      case _ChatListFilter.all:
        return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  List<CourierOrderModel> _applyListFilter(List<CourierOrderModel> source) {
    final sorted = [...source]
      ..sort((a, b) => _compareByRecentActivity(a, b, _previewByOrderId));
    switch (_selectedFilter) {
      case _ChatListFilter.last10:
        return sorted.take(10).toList();
      case _ChatListFilter.lastWeek:
      case _ChatListFilter.lastMonth:
        final threshold = _filterThresholdUtc(_selectedFilter);
        return sorted.where((o) => _createdAtSortKey(o).isAfter(threshold)).toList();
      case _ChatListFilter.all:
        return sorted;
    }
  }

  String _filterLabel(_ChatListFilter filter) {
    switch (filter) {
      case _ChatListFilter.last10:
        return 'Son 10 kayıt';
      case _ChatListFilter.lastWeek:
        return 'Son 1 hafta';
      case _ChatListFilter.lastMonth:
        return 'Son 1 ay';
      case _ChatListFilter.all:
        return 'Tüm kayıtlar';
    }
  }

  Widget _buildFilterMenu() {
    final colors = context.theme.appColors;
    return PopupMenuButton<_ChatListFilter>(
      tooltip: 'Kayıt filtresi',
      initialValue: _selectedFilter,
      onSelected: (value) {
        if (_selectedFilter == value) return;
        setState(() => _selectedFilter = value);
        final orders = context.read<CourierOrdersCubit>().state;
        final visible = _applyListFilter(
          orders.where(_eligible).where((o) => !_hiddenOrderIds.contains(o.id)).toList(),
        );
        _onVisibleOrdersChanged(visible);
      },
      itemBuilder: (context) {
        return _ChatListFilter.values
            .map(
              (f) => PopupMenuItem<_ChatListFilter>(
                value: f,
                child: Text(_filterLabel(f)),
              ),
            )
            .toList();
      },
      icon: Icon(Icons.more_vert_rounded, color: colors.primary),
    );
  }

  static int _compareByRecentActivity(
    CourierOrderModel a,
    CourierOrderModel b,
    Map<String, _DeliveryPreview> previews,
  ) {
    final c = _activitySortKey(b, previews).compareTo(_activitySortKey(a, previews));
    if (c != 0) return c;
    return b.id.compareTo(a.id);
  }

  static bool _eligible(CourierOrderModel o) {
    if (o.courierDeclined) return false;
    return true;
  }

  static String _statusLabel(CourierOrderStatus s) {
    switch (s) {
      case CourierOrderStatus.assigned:
        return 'Atanmış';
      case CourierOrderStatus.pickedUp:
        return 'Teslim alındı';
      case CourierOrderStatus.inTransit:
        return 'Yolda';
      case CourierOrderStatus.delivered:
        return 'Teslim';
    }
  }

  static String _chatTitle(CourierOrderModel order) {
    return 'kurye · ${order.items}';
  }

  String _statusCustomerLine(CourierOrderModel order) {
    final customer = order.customerName?.trim();
    final status = _statusLabel(order.status);
    if (customer != null && customer.isNotEmpty) {
      return '$status · Müşteri: $customer';
    }
    return '$status · Dokunarak yazın';
  }

  /// Görünüm: altta son mesaj; yoksa ekran görüntüsündeki gibi durum · müşteri.
  String _subtitleLine(CourierOrderModel order) {
    final text = _previewByOrderId[order.id]?.text.trim() ?? '';
    if (text.isNotEmpty) {
      if (text.length > 140) {
        return '${text.substring(0, 137)}…';
      }
      return text;
    }
    return _statusCustomerLine(order);
  }

  String _trailingTime(CourierOrderModel order) {
    final p = _previewByOrderId[order.id];
    if (p != null) {
      final local = p.activityUtc.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    return order.time;
  }

  void _openChat(CourierOrderModel order) {
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder:
            (_) => CustomerDeliveryChatScreen(
              orderId: order.id,
              title: _chatTitle(order),
            ),
      ),
    )
        .then((_) {
      if (mounted) unawaited(_loadPreviewForOrderId(order.id));
    });
  }

  Future<void> _confirmRemoveFromList(CourierOrderModel order) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: 'Sohbet listeden kaldırılsın mı?',
      message:
          'Bu satır bu cihazda gizlenir ve listede görünmez. Sohbet geçmişiniz '
          'sunucuda silinmez; isterseniz yine sipariş detayından açabilirsiniz.',
      confirmText: 'Kaldır',
      cancelText: 'Vazgeç',
      isDestructive: true,
    );
    if (ok != true || !mounted) return;
    try {
      await CourierChatInboxLocalStore.hideOrderRow(
        courierUserId: AppSession.userId,
        orderId: order.id,
      );
      if (!mounted) return;
      setState(() {
        _hiddenOrderIds = {..._hiddenOrderIds, order.id};
        _previewByOrderId.remove(order.id);
      });
      try {
        await TrackingRealtimeService.shared.unsubscribeOrder(order.id);
      } catch (_) {}
      _subscribedOrderIds = {..._subscribedOrderIds}..remove(order.id);
    } catch (e) {
      if (mounted) context.showErrorMessage(e.toString());
    }
  }

  Widget _orderCard(CourierOrderModel order) {
    final typography = context.theme.appTypography;
    final colors = context.theme.appColors;

    return Material(
      color: colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.corners),
        side: BorderSide(color: colors.gray.withValues(alpha: 0.14)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimens.corners),
        onTap: () => _openChat(order),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.largePadding,
            vertical: 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colors.primary.withValues(alpha: 0.14),
                child: Icon(Icons.person_rounded, color: colors.primary, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Müşteri',
                      style: typography.labelSmall.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.items,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _subtitleLine(order),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.bodySmall.copyWith(
                        color: colors.gray4,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 44,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _trailingTime(order),
                        style: typography.labelSmall.copyWith(
                          color: colors.gray4,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 36,
                      width: 36,
                      child: IconButton(
                        tooltip: 'Listeden kaldır',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        iconSize: 21,
                        onPressed: () => _confirmRemoveFromList(order),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: colors.error.withValues(alpha: 0.9),
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
    );
  }

  Widget _chatTabBody(List<CourierOrderModel> list) {
    final typography = context.theme.appTypography;
    final colors = context.theme.appColors;

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Henüz teslimat sohbetiniz yok.\n'
            'Size atanan siparişler burada listelenir.',
            textAlign: TextAlign.center,
            style: typography.bodySmall.copyWith(color: colors.gray4),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () async {
        await _reloadHidden();
        if (!mounted) return;
        await context.read<CourierOrdersCubit>().loadOrders();
        if (!mounted) return;
        final fresh =
            _applyListFilter(
              context.read<CourierOrdersCubit>().state.where(_eligible).where(
                    (o) => !_hiddenOrderIds.contains(o.id),
                  ).toList(),
            );
        _onVisibleOrdersChanged(fresh);
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Dimens.largePadding),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: Dimens.padding),
        itemBuilder: (context, index) => _orderCard(list[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.appTypography;
    final colors = context.theme.appColors;

    return DefaultTabController(
      length: 1,
      child: AppScaffold(
        padding: EdgeInsets.zero,
        backgroundColor: colors.white,
        appBar: GeneralAppBar(
          title: 'Sohbetler',
          actions: [
            _buildFilterMenu(),
            const SizedBox(width: 8),
          ],
          showBackIcon: true,
          onLeadingPressed: () {
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop();
            } else {
              context.read<CourierNavCubit>().onItemTap(0);
            }
          },
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.white.withValues(alpha: 0.92),
                border: Border(
                  top: BorderSide(
                    color: colors.primary.withValues(alpha: 0.08),
                  ),
                  bottom: BorderSide(
                    color: colors.gray.withValues(alpha: 0.18),
                  ),
                ),
              ),
              child: TabBar(
                indicatorColor: colors.primary,
                indicatorWeight: 3,
                labelColor: colors.primary,
                unselectedLabelColor: colors.gray4,
                labelStyle: typography.labelLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: typography.labelLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Teslimat'),
                ],
              ),
            ),
          ),
        ),
        body: BlocConsumer<CourierOrdersCubit, List<CourierOrderModel>>(
          listenWhen: (prev, next) {
            final a =
                prev.where(_eligible).where((o) => !_hiddenOrderIds.contains(o.id)).toList();
            final b =
                next.where(_eligible).where((o) => !_hiddenOrderIds.contains(o.id)).toList();
            if (a.length != b.length) return true;
            final sa = a.map((e) => e.id).toList()..sort();
            final sb = b.map((e) => e.id).toList()..sort();
            if (sa.length != sb.length) return true;
            for (var i = 0; i < sa.length; i++) {
              if (sa[i] != sb[i]) return true;
            }
            return false;
          },
          listener: (context, orders) {
            final visible = _applyListFilter(
              orders.where(_eligible).where((o) => !_hiddenOrderIds.contains(o.id)).toList(),
            );
            _onVisibleOrdersChanged(visible);
          },
          builder: (context, orders) {
            final base =
                orders
                    .where(_eligible)
                    .where((o) => !_hiddenOrderIds.contains(o.id))
                    .toList();
            final list = _applyListFilter(base);
            return TabBarView(
              children: [
                _chatTabBody(list),
              ],
            );
          },
        ),
      ),
    );
  }
}
