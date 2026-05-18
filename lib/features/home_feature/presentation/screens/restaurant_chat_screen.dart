import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/chat_bubble_tokens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_confirm_dialog.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/restaurant_chat_message_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/services/restaurant_chat_service.dart';

class RestaurantChatScreen extends StatefulWidget {
  const RestaurantChatScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  final String restaurantId;
  final String restaurantName;

  @override
  State<RestaurantChatScreen> createState() => _RestaurantChatScreenState();
}

class _RestaurantChatScreenState extends State<RestaurantChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final RestaurantChatService _chatService = RestaurantChatService();
  final List<RestaurantChatMessageModel> _messages = [];
  final Set<String> _deletingMessageIds = <String>{};
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final customerUserId = AppSession.userId;
    if (customerUserId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final loaded = await _chatService.getMessages(
        customerUserId: customerUserId,
        restaurantId: widget.restaurantId,
      );
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(loaded);
      });
    } catch (error) {
      if (!mounted) return;
      context.showErrorMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) {
      return;
    }
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }
    final customerUserId = AppSession.userId;
    if (customerUserId.isEmpty) {
      context.showErrorMessage('Mesaj göndermek için giriş yapmalısınız.');
      return;
    }

    setState(() => _isSending = true);
    try {
      final created = await _chatService.sendMessage(
        customerUserId: customerUserId,
        restaurantId: widget.restaurantId,
        message: message,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(created);
        _messageController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      context.showErrorMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _deleteMessage(RestaurantChatMessageModel message) async {
    final customerUserId = AppSession.userId;
    if (customerUserId.isEmpty || _deletingMessageIds.contains(message.id)) {
      return;
    }

    final approved = await AppConfirmDialog.show(
      context,
      title: 'Mesaj silinsin mi?',
      message: 'Bu mesaji silmek istediginizden emin misiniz?',
      confirmText: 'Sil',
      cancelText: 'Vazgec',
      isDestructive: true,
    );
    if (approved != true || !mounted) {
      return;
    }

    setState(() => _deletingMessageIds.add(message.id));
    try {
      await _chatService.deleteCustomerMessage(
        customerUserId: customerUserId,
        messageId: message.id,
      );
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((x) => x.id == message.id);
      });
      context.showSuccessMessage('Mesaj silindi.');
    } catch (error) {
      if (!mounted) return;
      context.showErrorMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _deletingMessageIds.remove(message.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return Scaffold(
      backgroundColor: ChatBubbleTokens.threadBackground,
      appBar: AppBar(
        backgroundColor: colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Text(
          widget.restaurantName,
          style: typography.bodyLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.primaryTint2,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? Center(
                      child: Text(
                        'Henüz mesaj yok. İlk mesajı siz gönderin.',
                        style: typography.bodySmall.copyWith(
                          color: colors.gray4,
                        ),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimens.largePadding,
                        vertical: 10,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMine =
                            message.senderType.toLowerCase() == 'customer' &&
                            message.senderUserId == AppSession.userId;
                        final isDeleting = _deletingMessageIds.contains(
                          message.id,
                        );
                        final timeStyle = typography.bodySmall.copyWith(
                          color: colors.gray4,
                          fontSize: 10,
                          height: 1.2,
                        );
                        final bubble = Container(
                          constraints: BoxConstraints(
                            maxWidth: ChatBubbleTokens.maxWidth(context),
                          ),
                          padding: ChatBubbleTokens.padding,
                          decoration: BoxDecoration(
                            color:
                                isMine
                                    ? ChatBubbleTokens.outgoingFill
                                    : ChatBubbleTokens.incomingFill,
                            borderRadius: BorderRadius.circular(
                              ChatBubbleTokens.radius,
                            ),
                          ),
                          child: IntrinsicWidth(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  message.message,
                                  style: typography.bodySmall.copyWith(
                                    color: colors.black,
                                    fontWeight: FontWeight.w500,
                                    height: 1.2,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatTime(message.createdAtUtc),
                                      style: timeStyle,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                        return Align(
                          alignment:
                              isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Opacity(
                            opacity: isDeleting ? 0.55 : 1,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child:
                                  isMine
                                      ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          bubble,
                                          const SizedBox(width: 6),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                              minHeight: 32,
                                            ),
                                            splashRadius: 18,
                                            onPressed:
                                                isDeleting
                                                    ? null
                                                    : () =>
                                                        _deleteMessage(message),
                                            icon: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 17,
                                              color: colors.error,
                                            ),
                                          ),
                                        ],
                                      )
                                      : bubble,
                            ),
                          ),
                        );
                      },
                    ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                Dimens.largePadding,
                Dimens.padding,
                Dimens.largePadding,
                Dimens.largePadding,
              ),
              decoration: BoxDecoration(
                color: colors.white,
                boxShadow: [
                  BoxShadow(
                    color: colors.gray.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Mesaj yaz...',
                        filled: true,
                        fillColor: colors.secondaryShade1,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: Dimens.largePadding,
                          vertical: Dimens.padding,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Dimens.padding),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: IconButton(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: Icon(Icons.send_rounded, color: colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
