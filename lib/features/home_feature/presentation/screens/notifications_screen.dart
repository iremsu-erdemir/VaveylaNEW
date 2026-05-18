import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/app_notification.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/notification_badge_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/remote_notification_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final RemoteNotificationService _service = RemoteNotificationService();
  final NotificationBadgeService _badgeService = NotificationBadgeService.instance;
  bool _isLoading = true;
  List<AppNotification> _items = const <AppNotification>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    _openAndMarkSeen();
  }

  Future<void> _openAndMarkSeen() async {
    await _badgeService.clearOnServerAndLocal();
    await _load();
  }

  Future<void> _load() async {
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      setState(() {
        _items = const <AppNotification>[];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _service.getNotifications(userId: userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = list;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(AppNotification notification) async {
    final userId = AppSession.userId;
    if (userId.isEmpty || notification.isRead) {
      return;
    }

    await _service.markAsRead(
      userId: userId,
      notificationId: notification.notificationId,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _items =
          _items
              .map(
                (item) =>
                    item.notificationId == notification.notificationId
                        ? AppNotification(
                          notificationId: item.notificationId,
                          userId: item.userId,
                          userRole: item.userRole,
                          type: item.type,
                          title: item.title,
                          message: item.message,
                          isRead: true,
                          createdAtUtc: item.createdAtUtc,
                          readAtUtc: DateTime.now().toUtc(),
                          relatedOrderId: item.relatedOrderId,
                        )
                        : item,
              )
              .toList();
    });
  }

  String _formatDate(DateTime dateTimeUtc) {
    return DateFormat('dd MMMM yyyy', 'tr_TR').format(_toTurkeyTime(dateTimeUtc));
  }

  String _formatTime(DateTime dateTimeUtc) {
    return DateFormat('HH:mm', 'tr_TR').format(_toTurkeyTime(dateTimeUtc));
  }

  DateTime _toTurkeyTime(DateTime sourceUtc) {
    // Backend timestamps are UTC; app should always display Turkiye local time.
    return sourceUtc.toUtc().add(const Duration(hours: 3));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return AppScaffold(
      appBar: const GeneralAppBar(title: 'Bildirimler'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Builder(
          builder: (context) {
            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_error != null) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text(
                      _error!,
                      style: typography.bodyMedium.copyWith(color: colors.error),
                    ),
                  ),
                ],
              );
            }

            if (_items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 52,
                    color: colors.gray4,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Henüz bildiriminiz yok.',
                      style: typography.titleMedium.copyWith(
                        color: colors.gray4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.only(top: 12, bottom: 20),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _markAsRead(item),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      decoration: BoxDecoration(
                        color: colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              item.isRead
                                  ? colors.gray.withValues(alpha: 0.18)
                                  : colors.primary.withValues(alpha: 0.28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: item.isRead ? colors.gray4 : colors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: typography.bodyLarge.copyWith(
                                    fontWeight:
                                        item.isRead
                                            ? FontWeight.w600
                                            : FontWeight.w700,
                                    color: colors.primaryTint2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.message,
                                  style: typography.bodySmall.copyWith(
                                    color: colors.gray4,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 13,
                                        color: colors.gray4,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDate(item.createdAtUtc),
                                        style: typography.labelSmall.copyWith(
                                          color: colors.gray4,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 13,
                                        color: colors.gray4,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTime(item.createdAtUtc),
                                        style: typography.labelSmall.copyWith(
                                          color: colors.gray4,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
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
              },
            );
          },
        ),
      ),
    );
  }
}
