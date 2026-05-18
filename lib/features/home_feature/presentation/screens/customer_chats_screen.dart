import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/notification_badge_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_confirm_dialog.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/models/customer_order_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/data/services/customer_order_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/customer_chat_conversation_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/customer_chat_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/bottom_navigation_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/customer_delivery_chat_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/restaurant_chat_screen.dart';

class CustomerChatsScreen extends StatefulWidget {
  const CustomerChatsScreen({super.key});

  @override
  State<CustomerChatsScreen> createState() => _CustomerChatsScreenState();
}

class _CustomerChatsScreenState extends State<CustomerChatsScreen> {
  final CustomerChatService _service = CustomerChatService();
  final CustomerOrderService _orderService = CustomerOrderService();
  final NotificationBadgeService _badgeService =
      NotificationBadgeService.instance;
  bool _isLoading = true;
  List<CustomerChatConversationModel> _conversations = const [];
  Timer? _pollTimer;
  bool _initialized = false;
  final Map<String, int> _knownMessageCounts = <String, int>{};
  final Map<String, bool> _hasUnread = <String, bool>{};
  final Map<String, CustomerOrderStatus> _deliveryOrderStatusById =
      <String, CustomerOrderStatus>{};
  String? _activeConversationKey;

  bool _canOpenDeliveryChat(CustomerOrderStatus? status) {
    return status == CustomerOrderStatus.inTransit ||
        status == CustomerOrderStatus.completed;
  }

  String _inboxKey(CustomerChatConversationModel e) {
    if (e.isDelivery) {
      final id = e.orderId ?? '';
      return 'delivery:$id';
    }
    return 'restaurant:${e.restaurantId}';
  }

  @override
  void initState() {
    super.initState();
    _load(showLoading: true);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _load(showLoading: false),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({required bool showLoading}) async {
    final customerUserId = AppSession.userId;
    if (customerUserId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final fromApi = await _service.getChatConversations(
        customerUserId: customerUserId,
      );
      final hidden = await _service.getHiddenInboxIds(
        customerUserId: customerUserId,
      );
      List<CustomerOrderModel> orders = const [];
      try {
        orders = await _orderService.getOrders(customerUserId: customerUserId);
      } catch (_) {}
      _deliveryOrderStatusById
        ..clear()
        ..addEntries(
          orders.where((o) => o.id.isNotEmpty).map((o) => MapEntry(o.id, o.status)),
        );
      final data = _mergeOrdersIntoConversations(
        fromApi,
        orders,
        hiddenOrderIds: hidden.orderIds,
      );
      if (!mounted) return;

      var shouldRefreshBadge = false;
      setState(() {
        _conversations = data;

        // First load just initializes local "seen" counters.
        if (!_initialized) {
          _knownMessageCounts
            ..clear()
            ..addEntries(
              data.map((e) => MapEntry(_inboxKey(e), e.messageCount)),
            );
          _hasUnread
            ..clear()
            ..addEntries(data.map((e) => MapEntry(_inboxKey(e), false)));
          _initialized = true;
          _isLoading = false;
          return;
        }

        final fetchedKeys = data.map(_inboxKey).toSet();
        _knownMessageCounts.removeWhere((key, _) => !fetchedKeys.contains(key));
        _hasUnread.removeWhere((key, _) => !fetchedKeys.contains(key));

        for (final item in data) {
          final key = _inboxKey(item);
          final prevCount = _knownMessageCounts[key] ?? item.messageCount;

          if (key == _activeConversationKey) {
            _hasUnread[key] = false;
            _knownMessageCounts[key] = item.messageCount;
            continue;
          }

          final hasNew = item.messageCount > prevCount;
          if (hasNew) {
            _hasUnread[key] = true;
            shouldRefreshBadge = true;
          }
          _knownMessageCounts[key] = item.messageCount;
        }

        _isLoading = false;
      });

      if (shouldRefreshBadge) {
        _badgeService.refresh();
      }
    } catch (error) {
      if (!mounted) return;
      context.showErrorMessage(error.toString());
    } finally {
      if (mounted && showLoading) setState(() => _isLoading = false);
    }
  }

  /// Siparişler sekmesiyle aynı kaynak: API sohbet listesi boş gelse bile teslimat satırları oluşur.
  /// [hiddenOrderIds]: sunucuda listeden kaldırılan teslimat satırları (sipariş birleştirmesinde tekrar eklenmesin).
  List<CustomerChatConversationModel> _mergeOrdersIntoConversations(
    List<CustomerChatConversationModel> fromApi,
    List<CustomerOrderModel> orders, {
    required Set<String> hiddenOrderIds,
  }) {
    final apiRows = fromApi.where((c) {
      if (!c.isDelivery) {
        return true;
      }
      final oid = c.orderId;
      if (oid == null || oid.isEmpty) {
        return true;
      }
      return !hiddenOrderIds.contains(oid);
    }).toList();

    final byOrderId = <String, CustomerChatConversationModel>{};
    for (final c in apiRows) {
      if (c.isDelivery) {
        final id = c.orderId;
        if (id != null && id.isNotEmpty) {
          byOrderId[id] = c;
        }
      }
    }

    final merged = List<CustomerChatConversationModel>.from(apiRows);
    for (final o in orders) {
      if (o.id.isEmpty) {
        continue;
      }
      if (hiddenOrderIds.contains(o.id)) {
        continue;
      }
      if (byOrderId.containsKey(o.id)) {
        continue;
      }
      merged.add(
        CustomerChatConversationModel(
          restaurantId: '00000000-0000-0000-0000-000000000000',
          restaurantName: _combinedDeliveryTitle(o),
          lastMessage: _deliveryPlaceholderSubtitle(o),
          lastMessageSenderType: 'courier',
          lastMessageAtUtc: _orderSortUtc(o),
          messageCount: 0,
          kind: 'delivery',
          orderId: o.id,
          courierName: o.courierName,
          orderItemsPreview: _orderPreviewLine(o),
        ),
      );
    }
    merged.sort((a, b) => b.lastMessageAtUtc.compareTo(a.lastMessageAtUtc));
    return merged;
  }

  static String _orderPreviewLine(CustomerOrderModel o) {
    var preview = o.items.trim();
    if (preview.isEmpty) {
      return 'Sipariş';
    }
    if (preview.length > 48) {
      preview = '${preview.substring(0, 45)}…';
    }
    return preview;
  }

  static String _combinedDeliveryTitle(CustomerOrderModel o) {
    final preview = _orderPreviewLine(o);
    final c = o.courierName?.trim();
    final label = (c != null && c.isNotEmpty) ? c : 'Teslimat';
    return '$label — $preview';
  }

  String _listSubtitle(CustomerChatConversationModel item) {
    if (!item.isDelivery) {
      return item.lastMessage.trim().isEmpty
          ? 'Henüz mesaj yok · Dokunarak yazın'
          : item.lastMessage;
    }
    final product = item.deliveryOrderPreview;
    final msg = item.lastMessage.trim();
    if (msg.isEmpty) {
      if (product.isEmpty) {
        return 'Henüz mesaj yok · Dokunarak yazın';
      }
      return '$product · Henüz mesaj yok · Dokunarak yazın';
    }
    if (product.isEmpty) {
      return msg;
    }
    return '$product · $msg';
  }

  static String _deliveryPlaceholderSubtitle(CustomerOrderModel o) {
    switch (o.status) {
      case CustomerOrderStatus.canceled:
        return 'Bu sipariş iptal edildi.';
      case CustomerOrderStatus.completed:
        return 'Henüz mesaj yok · Dokunarak yazın';
      case CustomerOrderStatus.awaitingCourier:
      case CustomerOrderStatus.pending:
      case CustomerOrderStatus.preparing:
        return 'Kurye atanana kadar bekleyin veya mesaj bırakın.';
      case CustomerOrderStatus.assigned:
      case CustomerOrderStatus.inTransit:
        return 'Henüz mesaj yok.';
    }
  }

  static DateTime _orderSortUtc(CustomerOrderModel o) {
    final loc = o.courierLocationUpdatedAtUtc;
    if (loc != null) {
      return loc.toUtc();
    }
    try {
      final dp = o.date.split('.');
      if (dp.length == 3) {
        final day = int.parse(dp[0]);
        final month = int.parse(dp[1]);
        final year = int.parse(dp[2]);
        final tp = o.time.split(':');
        final h = int.parse(tp[0]);
        final min = tp.length > 1 ? int.parse(tp[1]) : 0;
        return DateTime(year, month, day, h, min).toUtc();
      }
    } catch (_) {}
    return DateTime.now().toUtc();
  }

  List<CustomerChatConversationModel> get _restaurantConversations =>
      _conversations.where((e) => !e.isDelivery).toList();

  List<CustomerChatConversationModel> get _deliveryConversations =>
      _conversations.where((e) => e.isDelivery).toList();

  Future<void> _confirmRemoveFromInbox(CustomerChatConversationModel item) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: 'Sohbet listeden kaldırılsın mı?',
      message:
          'Bu satır sunucuda gizlenir ve Sohbetler listesinde görünmez. Mesaj '
          'geçmişiniz silinmez.',
      confirmText: 'Kaldır',
      cancelText: 'Vazgeç',
      isDestructive: true,
    );
    if (ok != true || !mounted) return;
    try {
      if (item.isDelivery) {
        final oid = item.orderId;
        if (oid == null || oid.isEmpty) return;
        await _service.hideInboxRow(
          customerUserId: AppSession.userId,
          orderId: oid,
        );
      } else {
        final rid = item.restaurantId.trim();
        if (rid.isEmpty) return;
        await _service.hideInboxRow(
          customerUserId: AppSession.userId,
          restaurantId: rid,
        );
      }
      if (!mounted) return;
      await _load(showLoading: false);
    } catch (e) {
      if (mounted) {
        context.showErrorMessage(e.toString());
      }
    }
  }

  Future<void> _openConversation(CustomerChatConversationModel item) async {
    final key = _inboxKey(item);
    if (item.isDelivery) {
      final oid = item.orderId;
      if (oid == null || oid.isEmpty) return;
      final status = _deliveryOrderStatusById[oid];
      if (!_canOpenDeliveryChat(status)) {
        final msg =
            status == CustomerOrderStatus.assigned
                ? 'Kurye atandı. Teslimat sohbeti kurye yola çıkınca aktif olacak.'
                : 'Henüz kurye atanmadı. Kurye atanması bekleniyor.';
        if (mounted) {
          context.showErrorMessage(msg);
        }
        return;
      }
      setState(() {
        _activeConversationKey = key;
        _hasUnread[key] = false;
        _knownMessageCounts[key] = item.messageCount;
      });
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => CustomerDeliveryChatScreen(
                orderId: oid,
                title: item.deliveryChatAppBarTitle,
              ),
        ),
      );
    } else {
      if (item.restaurantId.isEmpty) return;
      setState(() {
        _activeConversationKey = key;
        _hasUnread[key] = false;
        _knownMessageCounts[key] = item.messageCount;
      });
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => RestaurantChatScreen(
                restaurantId: item.restaurantId,
                restaurantName: item.restaurantName,
              ),
        ),
      );
    }
    if (mounted) {
      _activeConversationKey = null;
      _load(showLoading: false);
    }
  }

  Widget _conversationTile(CustomerChatConversationModel item) {
    final typography = context.theme.appTypography;
    final colors = context.theme.appColors;
    return ListTile(
      isThreeLine: item.isDelivery,
      tileColor: colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.corners),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Dimens.largePadding,
        vertical: 8,
      ),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: item.isDelivery
                ? (item.hasAssignedCourier
                    ? colors.primary.withValues(alpha: 0.14)
                    : colors.gray.withValues(alpha: 0.12))
                : Colors.deepOrange.withValues(alpha: 0.14),
            child: Icon(
              item.isDelivery
                  ? (item.hasAssignedCourier
                      ? Icons.delivery_dining_rounded
                      : Icons.hourglass_empty_rounded)
                  : Icons.store_mall_directory_rounded,
              color: item.isDelivery
                  ? (item.hasAssignedCourier ? colors.primary : colors.gray4)
                  : Colors.deepOrange.shade700,
            ),
          ),
          if (_hasUnread[_inboxKey(item)] == true)
            const Positioned(
              top: -2,
              right: -2,
              child: _UnreadDot(),
            ),
        ],
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.isDelivery ? 'Kurye teslimat' : 'Pastane',
            style: typography.labelSmall.copyWith(
              color: item.isDelivery
                  ? colors.primary
                  : Colors.deepOrange.shade700,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.isDelivery
                ? item.deliveryListTitle
                : item.restaurantName,
            style: typography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      subtitle: Text(
        _listSubtitle(item),
        maxLines: item.isDelivery ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style:
            item.isDelivery && item.messageCount == 0
                ? typography.bodySmall.copyWith(
                  color: colors.gray4,
                  fontStyle: FontStyle.italic,
                )
                : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _formatTime(item.lastMessageAtUtc),
            style: typography.labelSmall.copyWith(
              color: colors.gray4,
              fontSize: 11,
            ),
          ),
          IconButton(
            tooltip: 'Listeden kaldır',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            iconSize: 21,
            onPressed: () => _confirmRemoveFromInbox(item),
            icon: Icon(
              Icons.delete_outline_rounded,
              color: colors.error.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
      onTap: () => _openConversation(item),
    );
  }

  Widget _chatTabBody({
    required List<CustomerChatConversationModel> items,
    required bool isRestaurantTab,
  }) {
    final typography = context.theme.appTypography;
    final colors = context.theme.appColors;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            isRestaurantTab
                ? 'Henüz restoran sohbetiniz yok.\n'
                    'Pastane ile yazışmak için ilgili pastanenin sayfasından sohbeti açın.'
                : 'Henüz kurye / teslimat sohbetiniz yok.\n'
                    'Sipariş verdikten sonra teslimat mesajlarınız burada listelenir.',
            textAlign: TextAlign.center,
            style: typography.bodySmall.copyWith(color: colors.gray4),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(showLoading: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Dimens.largePadding),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: Dimens.padding),
        itemBuilder: (context, index) => _conversationTile(items[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.appTypography;
    final colors = context.theme.appColors;
    final customerUserId = AppSession.userId;

    if (_isLoading) {
      return AppScaffold(
        appBar: GeneralAppBar(
          title: 'Sohbetler',
          onLeadingPressed: () {
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop();
            } else {
              context.read<BottomNavigationCubit>().onItemTap(index: 0);
            }
          },
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (customerUserId.isEmpty) {
      return AppScaffold(
        appBar: GeneralAppBar(
          title: 'Sohbetler',
          onLeadingPressed: () {
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop();
            } else {
              context.read<BottomNavigationCubit>().onItemTap(index: 0);
            }
          },
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Sohbetleri görmek için giriş yapın.',
              textAlign: TextAlign.center,
              style: typography.bodyMedium.copyWith(color: colors.gray4),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        padding: EdgeInsets.zero,
        appBar: GeneralAppBar(
          title: 'Sohbetler',
          onLeadingPressed: () {
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop();
            } else {
              context.read<BottomNavigationCubit>().onItemTap(index: 0);
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
                  Tab(text: 'Restoran'),
                  Tab(text: 'Kurye'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _chatTabBody(
              items: _restaurantConversations,
              isRestaurantTab: true,
            ),
            _chatTabBody(
              items: _deliveryConversations,
              isRestaurantTab: false,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }
}
