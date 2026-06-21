import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/home_marketing_banner_model.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/admin_feature/data/services/admin_marketing_banners_service.dart';

class AdminMarketingBannersScreen extends StatefulWidget {
  const AdminMarketingBannersScreen({super.key});

  @override
  State<AdminMarketingBannersScreen> createState() =>
      _AdminMarketingBannersScreenState();
}

class _AdminMarketingBannersScreenState extends State<AdminMarketingBannersScreen> {
  final AdminMarketingBannersService _service = AdminMarketingBannersService();
  List<HomeMarketingBannerModel> _items = [];
  bool _loading = true;

  static const _actionChoices = <String, String>{
    'none': 'Yok (sadece görsel)',
    'category': 'Kategori',
    'restaurant': 'Restoran',
    'product': 'Ürün',
    'externalUrl': 'Dış bağlantı',
    'specialOffers': 'Özel teklifler sayfası',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.listAll();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _openForm({HomeMarketingBannerModel? existing}) async {
    final imageCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final subtitleCtrl = TextEditingController(text: existing?.subtitle ?? '');
    final badgeCtrl = TextEditingController(text: existing?.badgeText ?? '');
    final bodyCtrl = TextEditingController(text: existing?.bodyText ?? '');
    final sortCtrl = TextEditingController(
      text: (existing?.sortOrder ?? _items.length).toString(),
    );
    final targetCtrl = TextEditingController(text: existing?.actionTarget ?? '');
    final startCtrl = TextEditingController(
      text: existing?.startsAtUtc?.toUtc().toIso8601String() ?? '',
    );
    final endCtrl = TextEditingController(
      text: existing?.endsAtUtc?.toUtc().toIso8601String() ?? '',
    );
    var action = existing?.actionType ?? 'none';
    var active = existing?.isActive ?? true;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Yeni banner' : 'Banner düzenle'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: imageCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Görsel URL *',
                          hintText: 'https://...',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Başlık'),
                      ),
                      TextField(
                        controller: subtitleCtrl,
                        decoration: const InputDecoration(labelText: 'Üst etiket'),
                      ),
                      TextField(
                        controller: badgeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Rozet (örn. %50)',
                        ),
                      ),
                      TextField(
                        controller: bodyCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Açıklama'),
                      ),
                      TextField(
                        controller: sortCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Sıra (küçük önce)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _actionChoices.containsKey(action) ? action : 'none',
                        decoration: const InputDecoration(labelText: 'Tıklanınca'),
                        items: _actionChoices.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setDialogState(() => action = v ?? 'none'),
                      ),
                      TextField(
                        controller: targetCtrl,
                        decoration: InputDecoration(
                          labelText: action == 'category'
                              ? 'Kategori adı'
                              : action == 'restaurant'
                                  ? 'Restoran ID (GUID)'
                                  : action == 'product'
                                      ? 'Ürün ID (GUID)'
                                      : action == 'externalUrl'
                                          ? 'https://...'
                                          : 'Hedef (gerekirse)',
                        ),
                      ),
                      TextField(
                        controller: startCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Başlangıç UTC (opsiyonel)',
                          hintText: '2026-04-01T00:00:00.000Z',
                        ),
                      ),
                      TextField(
                        controller: endCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Bitiş UTC (opsiyonel)',
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Aktif'),
                        value: active,
                        onChanged: (v) => setDialogState(() => active = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) return;

    final sort = int.tryParse(sortCtrl.text.trim()) ?? 0;
    DateTime? start;
    DateTime? end;
    if (startCtrl.text.trim().isNotEmpty) {
      start = DateTime.tryParse(startCtrl.text.trim());
    }
    if (endCtrl.text.trim().isNotEmpty) {
      end = DateTime.tryParse(endCtrl.text.trim());
    }

    final draft = HomeMarketingBannerModel(
      id: existing?.id ?? '',
      imageUrl: imageCtrl.text.trim(),
      title: titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(),
      subtitle: subtitleCtrl.text.trim().isEmpty ? null : subtitleCtrl.text.trim(),
      badgeText: badgeCtrl.text.trim().isEmpty ? null : badgeCtrl.text.trim(),
      bodyText: bodyCtrl.text.trim().isEmpty ? null : bodyCtrl.text.trim(),
      sortOrder: sort,
      actionType: action,
      actionTarget: targetCtrl.text.trim().isEmpty ? null : targetCtrl.text.trim(),
      isActive: active,
      startsAtUtc: start,
      endsAtUtc: end,
    );

    if (draft.imageUrl.isEmpty) {
      context.showInfoMessage('Görsel URL zorunludur.');
      return;
    }

    if (existing == null) {
      final created = await _service.create(draft);
      if (!mounted) return;
      if (created != null) {
        context.showSuccessMessage('Banner oluşturuldu.');
        await _load();
      } else {
        context.showErrorMessage('Kayıt başarısız.');
      }
    } else {
      final updated = await _service.update(existing.id, draft);
      if (!mounted) return;
      if (updated != null) {
        context.showSuccessMessage('Güncellendi.');
        await _load();
      } else {
        context.showErrorMessage('Güncelleme başarısız.');
      }
    }
  }

  Future<void> _confirmDelete(HomeMarketingBannerModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: const Text('Bu banner kalıcı olarak silinir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await _service.delete(item.id);
    if (!mounted) return;
    if (done) {
      context.showSuccessMessage('Silindi.');
      await _load();
    } else {
      context.showErrorMessage('Silinemedi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(title: 'Ana sayfa özel teklif bannerları'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Yeni'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(Dimens.largePadding),
                itemCount: _items.isEmpty ? 1 : _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: Dimens.padding),
                itemBuilder: (context, i) {
                  if (_items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Center(
                        child: Text(
                          'Henüz banner yok. Sağ alttan yeni ekleyin.',
                          style: typography.bodyMedium.copyWith(color: colors.gray4),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final b = _items[i];
                  return Material(
                    color: colors.white,
                    borderRadius: BorderRadius.circular(Dimens.corners),
                    child: InkWell(
                      onTap: () => _openForm(existing: b),
                      borderRadius: BorderRadius.circular(Dimens.corners),
                      child: Container(
                        padding: const EdgeInsets.all(Dimens.padding),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Dimens.corners),
                          border: Border.all(color: colors.gray.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 88,
                                height: 56,
                                child: Image.network(
                                  b.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      ColoredBox(color: colors.gray.withValues(alpha: 0.2)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.title?.isNotEmpty == true ? b.title! : '(Başlıksız)',
                                    style: typography.titleSmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sıra: ${b.sortOrder} · ${_actionChoices[b.actionType] ?? b.actionType}',
                                    style: typography.bodySmall.copyWith(color: colors.gray4),
                                  ),
                                  Text(
                                    b.isActive == false ? 'Pasif' : 'Aktif',
                                    style: typography.labelSmall.copyWith(
                                      color: b.isActive == false ? colors.gray4 : colors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmDelete(b),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
