import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/delivery_chat_message_model.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/auth_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/delivery_chat_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/tracking_realtime_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/chat_bubble_tokens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_confirm_dialog.dart';

/// Teslimat sırasında müşteri ↔ kurye mesajları (API ile senkron, kısa aralıkla yenileme).
class DeliveryChatPanel extends StatefulWidget {
  const DeliveryChatPanel({
    super.key,
    required this.orderId,
    required this.title,
    this.subtitle,
    this.deliveryChatService,
    this.isEmbeddedPage = false,
  });

  final String orderId;
  final String title;

  /// Alt sayfa başlığı altındaki ikinci satır. Boşsa sipariş numarası gösterilir.
  final String? subtitle;
  final DeliveryChatService? deliveryChatService;

  /// Tam sayfa (müşteri Sohbetler) için alt sayfa kromu (sürükle çubuğu vb.) gizlenir.
  final bool isEmbeddedPage;

  @override
  State<DeliveryChatPanel> createState() => _DeliveryChatPanelState();
}

class _DeliveryChatPanelState extends State<DeliveryChatPanel> {
  late final DeliveryChatService _service;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<DeliveryChatMessageModel> _messages = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _deliveryChatSub;
  bool _sending = false;
  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    _service =
        widget.deliveryChatService ??
        DeliveryChatService(authService: AuthService());
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _load(silent: true);
    });
    unawaited(_attachDeliveryChatStream());
  }

  Future<void> _attachDeliveryChatStream() async {
    final oid = widget.orderId.trim();
    if (oid.isEmpty) return;
    final tracking = TrackingRealtimeService.shared;
    try {
      await tracking.subscribeOrder(oid);
    } catch (_) {}
    _deliveryChatSub = tracking.deliveryChatMessages.listen((map) {
      final id = map['orderId']?.toString() ?? '';
      if (!mounted || id.toLowerCase() != oid.toLowerCase()) return;
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _deliveryChatSub?.cancel();
    final oid = widget.orderId.trim();
    if (oid.isNotEmpty) {
      unawaited(TrackingRealtimeService.shared.unsubscribeOrder(oid));
    }
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _textController.clear();
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    try {
      final uid = AppSession.userId;
      if (uid.isEmpty) {
        if (mounted) {
          setState(() {
            _error = 'Oturum bulunamadı. Lütfen yeniden giriş yapın.';
            _loading = false;
          });
        }
        return;
      }
      final list = await _service.fetchMessages(
        orderId: widget.orderId,
        userId: uid,
      );
      if (!mounted) return;
      setState(() {
        _messages = list;
        _error = null;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) {
          _error = e.toString();
        }
        _loading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  String _formatError(Object e) {
    final s = e.toString();
    if (s.contains('Invalid column name') ||
        s.contains('SqlException') ||
        s.contains('Invalid object name')) {
      return 'Sunucu veritabanı şeması güncellenemedi. API\'yi yeniden başlatın '
          '(migration otomatik uygulanır). Sorun sürerse: backend klasöründe '
          '"dotnet ef database update" çalıştırın.';
    }
    if (s.length > 480) {
      return '${s.substring(0, 480)}…';
    }
    return s;
  }

  void _startEdit(DeliveryChatMessageModel m) {
    setState(() {
      _editingMessageId = m.id;
      _textController.text = m.message;
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: m.message.length,
      );
    });
  }

  void _onMessageLongPress(BuildContext context, DeliveryChatMessageModel m) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: colors.primary),
                  title: Text('Düzenle', style: typography.titleSmall),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startEdit(m);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: colors.error),
                  title: Text(
                    'Sil',
                    style: typography.titleSmall.copyWith(color: colors.error),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(m);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  Future<void> _confirmDelete(DeliveryChatMessageModel m) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: 'Mesajı sil',
      message: 'Bu mesaj kalıcı olarak kaldırılır (karşı tarafta da görünmez).',
      confirmText: 'Sil',
      isDestructive: true,
    );
    if (ok != true || !mounted) return;
    final uid = AppSession.userId;
    if (uid.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.deleteMessage(
        orderId: widget.orderId,
        userId: uid,
        messageId: m.id,
      );
      if (_editingMessageId == m.id) {
        _cancelEdit();
      }
      if (mounted) await _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    final uid = AppSession.userId;
    if (uid.isEmpty) return;
    setState(() => _sending = true);
    try {
      if (_editingMessageId != null) {
        await _service.updateMessage(
          orderId: widget.orderId,
          userId: uid,
          messageId: _editingMessageId!,
          text: text,
        );
        _cancelEdit();
      } else {
        await _service.sendMessage(
          orderId: widget.orderId,
          userId: uid,
          text: text,
        );
        _textController.clear();
      }
      await _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final myId = AppSession.userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.isEmbeddedPage) ...[
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colors.gray.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: typography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.primaryTint2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle?.trim().isNotEmpty == true
                      ? widget.subtitle!.trim()
                      : 'Sipariş no: ${widget.orderId}',
                  style: typography.bodySmall.copyWith(color: colors.gray4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 4),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: SingleChildScrollView(
                child: Text(
                  _formatError(_error!),
                  style: typography.bodySmall.copyWith(color: colors.error),
                ),
              ),
            ),
          ),
        if (_editingMessageId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mesajı düzenliyorsunuz',
                        style: typography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _sending ? null : _cancelEdit,
                      child: const Text('İptal'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ChatBubbleTokens.threadBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child:
                  _loading && _messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final m = _messages[index];
                          final mine =
                              myId.isNotEmpty &&
                              m.senderUserId.toLowerCase() ==
                                  myId.toLowerCase();
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
                                  mine
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
                                    m.message,
                                    style: typography.bodySmall.copyWith(
                                      height: 1.2,
                                      color: colors.black,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (m.editedAtUtc != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'düzenlendi',
                                      style: typography.bodySmall.copyWith(
                                        color: colors.gray4,
                                        fontSize: 9,
                                        fontStyle: FontStyle.italic,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        _formatTime(m.createdAtUtc),
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
                                mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child:
                                  mine
                                      ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          GestureDetector(
                                            onLongPress:
                                                () => _onMessageLongPress(
                                                  context,
                                                  m,
                                                ),
                                            child: bubble,
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                              minHeight: 32,
                                            ),
                                            splashRadius: 18,
                                            onPressed:
                                                _sending
                                                    ? null
                                                    : () => _confirmDelete(m),
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
                          );
                        },
                      ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText:
                        _editingMessageId != null
                            ? 'Mesajı güncelleyin…'
                            : 'Mesaj yaz...',
                    hintStyle: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: colors.gray4),
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
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
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
                  onPressed: _sending ? null : _send,
                  icon:
                      _sending
                          ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.white,
                            ),
                          )
                          : Icon(
                            _editingMessageId != null
                                ? Icons.check_rounded
                                : Icons.send_rounded,
                            color: colors.white,
                          ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
