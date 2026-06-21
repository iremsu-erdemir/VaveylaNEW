import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/data/services/admin_feedback_service.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/presentation/widgets/feedback_card.dart';
import 'package:intl/intl.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  final AdminFeedbackService _service = AdminFeedbackService();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _busyFeedbackId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.listFeedbacks();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _onAction(
    String feedbackId,
    String action, {
    int? points,
    int? suspendDays,
  }) async {
    if (_busyFeedbackId != null) return;
    setState(() => _busyFeedbackId = feedbackId);
    try {
      await _service.applyAction(
        feedbackId: feedbackId,
        action: action,
        points: points,
        suspendDays: suspendDays,
      );
      if (!mounted) return;
      context.showSuccessMessage('İşlem kaydedildi.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      context.showErrorMessage(e);
    } finally {
      if (mounted) setState(() => _busyFeedbackId = null);
    }
  }

  String _formatDate(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '');
    if (dt == null) return raw?.toString() ?? '';
    return DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(title: 'Müşteri Geri Bildirimleri'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.25,
                  ),
                  Center(
                    child: Text(
                      'Kayıtlı geri bildirim yok.',
                      style: typography.bodyLarge.copyWith(color: colors.gray4),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(Dimens.largePadding),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final m = _items[index];
                  final id = m['feedbackId']?.toString() ?? '';
                  return FeedbackCard(
                    feedbackId: id,
                    complainant: m['complainantName']?.toString() ?? '—',
                    targetDisplay: m['targetDisplay']?.toString() ?? '—',
                    orderNumberLabel: m['orderNumberLabel']?.toString(),
                    orderTitle: m['orderTitle']?.toString(),
                    createdAtText: _formatDate(m['createdAtUtc']),
                    message: m['message']?.toString() ?? '—',
                    statusLabel: m['statusLabel']?.toString() ?? '—',
                    busy: _busyFeedbackId == id,
                    onAction: (a, {int? points, int? suspendDays}) =>
                        _onAction(id, a, points: points, suspendDays: suspendDays),
                  );
                },
              ),
      ),
    );
  }
}
