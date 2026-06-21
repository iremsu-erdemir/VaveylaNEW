import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/data/services/admin_service.dart';

class AdminOrderRefundsScreen extends StatefulWidget {
  const AdminOrderRefundsScreen({super.key});

  @override
  State<AdminOrderRefundsScreen> createState() => _AdminOrderRefundsScreenState();
}

class _AdminOrderRefundsScreenState extends State<AdminOrderRefundsScreen> {
  final AdminService _admin = AdminService();
  List<Map<String, dynamic>> _refunds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _admin.getRefundRequests();
      if (!mounted) return;
      setState(() {
        _refunds = list.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        context.showErrorMessage(e);
      }
    }
  }

  Future<void> _resolve(Map<String, dynamic> item, bool approve) async {
    final id = item['refundRequestId']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await _admin.resolveRefund(id, approve);
      if (mounted) {
        context.showSuccessMessage(approve ? 'İade onaylandı' : 'İade reddedildi');
        _load();
      }
    } catch (e) {
      if (mounted) context.showErrorMessage(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(title: 'İptal / İade Yönetimi'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _refunds.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: const Center(child: Text('Bekleyen iade talebi yok')),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(Dimens.largePadding),
                      itemCount: _refunds.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _refunds[index];
                        final status = item['status']?.toString() ?? '';
                        return Container(
                          padding: const EdgeInsets.all(Dimens.largePadding),
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.gray),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sipariş ${item['orderId']}',
                                style: typography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text('Durum: $status'),
                              if (item['reasonNote'] != null)
                                Text(item['reasonNote'].toString()),
                              if (status.toLowerCase() == 'pending') ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppButton(
                                        title: 'Onayla',
                                        margin: EdgeInsets.zero,
                                        onPressed: () => _resolve(item, true),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: AppButton(
                                        title: 'Reddet',
                                        color: colors.error,
                                        margin: EdgeInsets.zero,
                                        onPressed: () => _resolve(item, false),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
