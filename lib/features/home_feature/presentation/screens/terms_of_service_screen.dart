import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
                      'Hizmet Şartları',
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
                      _TermsSection(
                        title: '1. Hizmetin Kapsamı',
                        text:
                            'Vaveyla, kullanıcıların pastane ürünlerini keşfetmesini, sipariş vermesini ve ödeme yapmasını sağlayan bir e-ticaret platformudur.',
                      ),
                      _TermsSection(
                        title: '2. Ödeme ve İade',
                        text:
                            'Sipariş ödemeleri güvenli ödeme sağlayıcısı üzerinden tamamlanır. İade ve iptal işlemleri ürün durumu, hazırlama süreci ve ilgili satıcı koşullarına göre değerlendirilir.',
                      ),
                      _TermsSection(
                        title: '3. Kullanıcı Yükümlülükleri',
                        text:
                            'Kullanıcı, hesap bilgilerini doğru tutmaktan, teslimat adresini eksiksiz girmekten ve ödeme araçlarını yasal şekilde kullanmaktan sorumludur.',
                      ),
                      _TermsSection(
                        title: '4. Satıcı ve Teslimat',
                        text:
                            'Ürünlerin hazırlanması ve teslimat süreleri satıcı/kurye yoğunluğuna göre değişebilir. Vaveyla, teknik altyapıyı sağlar ve süreci takip eder.',
                      ),
                      _TermsSection(
                        title: '5. Sorumluluğun Sınırı',
                        text:
                            'Vaveyla, yasal sınırlar dahilinde hizmet verir. Mücbir sebepler veya üçüncü taraf kaynaklı gecikmelerde doğabilecek dolaylı zararlardan sorumlu tutulamaz.',
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
                title: 'Hizmet Şartlarını Onayla',
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

class _TermsSection extends StatelessWidget {
  const _TermsSection({required this.title, required this.text});

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
