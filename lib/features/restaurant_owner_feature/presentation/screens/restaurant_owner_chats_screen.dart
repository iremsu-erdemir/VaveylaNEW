import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/notification_badge_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_confirm_dialog.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/models/owner_chat_models.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/data/services/restaurant_owner_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/bloc/restaurant_owner_nav_cubit.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/presentation/screens/restaurant_owner_chat_detail_screen.dart';

class RestaurantOwnerChatsScreen extends StatefulWidget {
  const RestaurantOwnerChatsScreen({super.key});

  @override
  State<RestaurantOwnerChatsScreen> createState() =>
      _RestaurantOwnerChatsScreenState();
}

class _RestaurantOwnerChatsScreenState
    extends State<RestaurantOwnerChatsScreen> {
  final RestaurantOwnerService _service = RestaurantOwnerService(
    authService: AuthService(),
  );
  final NotificationBadgeService _badgeService = NotificationBadgeService.instance;
  bool _isLoading = true;
  List<OwnerChatConversationModel> _conversations = const [];
  final Set<String> _deletingConversationIds = <String>{};
  Timer? _pollTimer;
  bool _initialized = false;
  final Map<String, int> _knownMessageCounts = <String, int>{};
  final Set<String> _hasUnread = <String>{};
  String? _activeCustomerUserId;

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
    final ownerUserId = AppSession.userId;
    if (ownerUserId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final data = await _service.getChatConversations(
        ownerUserId: ownerUserId,
      );
      if (!mounted) return;

      var shouldRefreshBadge = false;
      setState(() {
        _conversations = data;

        if (!_initialized) {
          _knownMessageCounts
            ..clear()
            ..addEntries(
              data.map((e) => MapEntry(e.customerUserId, e.messageCount)),
            );
          _hasUnread.clear();
          _initialized = true;
          _isLoading = false;
          return;
        }

        final fetchedIds = data.map((e) => e.customerUserId).toSet();
        _knownMessageCounts.removeWhere((key, _) => !fetchedIds.contains(key));
        _hasUnread.removeWhere((id) => !fetchedIds.contains(id));

        for (final item in data) {
          final id = item.customerUserId;
          final prevCount = _knownMessageCounts[id] ?? item.messageCount;

          if (id == _activeCustomerUserId) {
            _hasUnread.remove(id);
            _knownMessageCounts[id] = item.messageCount;
            continue;
          }

          final hasNew = item.messageCount > prevCount;
          if (hasNew) {
            _hasUnread.add(id);
            shouldRefreshBadge = true;
          }
          _knownMessageCounts[id] = item.messageCount;
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

  Future<void> _deleteConversation(OwnerChatConversationModel item) async {
    final ownerUserId = AppSession.userId;
    if (ownerUserId.isEmpty ||
        _deletingConversationIds.contains(item.customerUserId)) {
      return;
    }

    final approved = await AppConfirmDialog.show(
      context,
      title: 'Sohbet silinsin mi?',
      message: 'Bu sohbeti silmek istediginizden emin misiniz?',
      confirmText: 'Sil',
      cancelText: 'Vazgec',
      isDestructive: true,
    );
    if (approved != true || !mounted) {
      return;
    }

    setState(() => _deletingConversationIds.add(item.customerUserId));
    try {
      await _service.deleteChatConversation(
        ownerUserId: ownerUserId,
        customerUserId: item.customerUserId,
      );
      if (!mounted) return;
      setState(() {
        _conversations =
            _conversations
                .where((x) => x.customerUserId != item.customerUserId)
                .toList();
      });
      context.showSuccessMessage('Sohbet silindi.');
    } catch (error) {
      if (!mounted) return;
      context.showErrorMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _deletingConversationIds.remove(item.customerUserId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.appTypography;
    final colors = context.theme.appColors;
    return AppScaffold(
      appBar: GeneralAppBar(
        title: 'Sohbetler',
        onLeadingPressed: () {
          context.read<RestaurantOwnerNavCubit>().onItemTap(0);
        },
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _conversations.isEmpty
              ? Center(
                child: Text(
                  'Henüz müşteri mesajı yok.',
                  style: typography.bodySmall.copyWith(color: colors.gray4),
                ),
              )
              : RefreshIndicator(
                onRefresh: () => _load(showLoading: true),
                child: ListView.separated(
                  padding: const EdgeInsets.all(Dimens.largePadding),
                  itemCount: _conversations.length,
                  separatorBuilder:
                      (_, __) => const SizedBox(height: Dimens.padding),
                  itemBuilder: (context, index) {
                    final item = _conversations[index];
                    final isDeleting = _deletingConversationIds.contains(
                      item.customerUserId,
                    );
                    return SizedBox(
                      height: 88,
                      child: ListTile(
                        tileColor: colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Dimens.corners),
                        ),
                        enabled: !isDeleting,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: Dimens.largePadding,
                          vertical: 0,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: colors.primary.withValues(
                            alpha: 0.16,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Center(
                                child: Icon(Icons.person, color: colors.primary),
                              ),
                              if (_hasUnread.contains(item.customerUserId))
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: const _UnreadDot(),
                                ),
                            ],
                          ),
                        ),
                        title: Text(
                          item.customerName,
                          style: typography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          item.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: SizedBox(
                          width: 44,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTime(item.lastMessageAtUtc),
                                style: typography.labelSmall.copyWith(
                                  color: colors.gray4,
                                  fontSize: 11,
                                ),
                              ),
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  splashRadius: 14,
                                  onPressed:
                                      isDeleting
                                          ? null
                                          : () => _deleteConversation(item),
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: colors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        onTap: () async {
                          if (isDeleting) return;
                          setState(() {
                            _activeCustomerUserId = item.customerUserId;
                            _hasUnread.remove(item.customerUserId);
                            _knownMessageCounts[item.customerUserId] =
                                item.messageCount;
                          });
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => RestaurantOwnerChatDetailScreen(
                                    customerUserId: item.customerUserId,
                                    customerName: item.customerName,
                                  ),
                            ),
                          );
                          if (mounted) {
                            _activeCustomerUserId = null;
                          }
                          if (mounted) {
                            _load(showLoading: false);
                          }
                        },
                      ),
                    );
                  },
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
