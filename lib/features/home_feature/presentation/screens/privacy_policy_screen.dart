import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    return AppScaffold(
      backgroundColor: colors.secondaryShade1,
      padding: EdgeInsets.zero,
      safeAreaTop: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.secondaryShade2, colors.secondaryShade1],
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: MediaQuery.paddingOf(context).top + 8),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimens.largePadding,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: Icon(Icons.arrow_back, color: colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'Gizlilik Politikası',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: Dimens.largePadding),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: Dimens.largePadding,
                  vertical: Dimens.padding,
                ),
                padding: const EdgeInsets.all(Dimens.largePadding),
                decoration: BoxDecoration(
                  color: colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PolicySection(
                        title: '1. Toplanan Veriler',
                        text:
                            'Vaveyla uygulamasında sipariş ve teslimat sürecini yürütmek için ad-soyad, e-posta, telefon, teslimat adresi ve cihaz bilgileri toplanabilir.',
                      ),
                      _PolicySection(
                        title: '2. Ödeme ve Sipariş Verileri',
                        text:
                            'Pastane ürünleri ödemelerinde kullanılan kart bilgileri Vaveyla sunucularında açık olarak tutulmaz; ödeme işlemleri güvenli ödeme altyapısı üzerinden işlenir.',
                      ),
                      _PolicySection(
                        title: '3. Veri Kullanımı',
                        text:
                            'Verileriniz sipariş oluşturma, ödeme doğrulama, teslimat takibi, iade süreci ve müşteri desteği için kullanılır. Açık rızanız olmadan pazarlama amaçlı paylaşım yapılmaz.',
                      ),
                      _PolicySection(
                        title: '4. Veri Güvenliği',
                        text:
                            'Vaveyla, verilerinizi sektör standartlarına uygun teknik ve idari önlemlerle korur. Bununla birlikte internet üzerinden iletimde sıfır risk garanti edilemez.',
                      ),
                      _PolicySection(
                        title: '5. İletişim',
                        text:
                            'Gizlilik politikası ile ilgili talepleriniz için bizimle iletişime geçebilirsiniz: support@vaveyla.app',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimens.largePadding,
                0,
                Dimens.largePadding,
                Dimens.extraLargePadding,
              ),
              child: AppButton(
                title: 'Okudum, Devam Et',
                onPressed: () => Navigator.of(context).pop(true),
                margin: EdgeInsets.zero,
                borderRadius: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.largePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.primaryTint3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.gray4,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
