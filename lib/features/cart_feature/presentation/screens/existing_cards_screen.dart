import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/bordered_container.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/models/payment_saved_card.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/screens/add_card_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/screens/payment_completion_success_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/cart_feature/presentation/services/payment_card_service.dart';

class ExistingCardsScreen extends StatefulWidget {
  const ExistingCardsScreen({super.key, this.selectionMode = false});

  final bool selectionMode;

  @override
  State<ExistingCardsScreen> createState() => _ExistingCardsScreenState();
}

class _ExistingCardsScreenState extends State<ExistingCardsScreen> {
  final PaymentCardService _paymentCardService = PaymentCardService();
  List<PaymentSavedCard> _cards = <PaymentSavedCard>[];
  int _selectedIndex = 0;
  late final PageController _pageController;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.95);
    _loadCards();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCards({bool selectLast = false}) async {
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cards = <PaymentSavedCard>[];
        _selectedIndex = 0;
        _isLoading = false;
        _loadError = null;
      });
      return;
    }

    try {
      final cards = await _paymentCardService.getCards(userId: userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _cards = cards;
        if (_cards.isEmpty) {
          _selectedIndex = 0;
        } else if (selectLast) {
          _selectedIndex = _cards.length - 1;
        } else if (_selectedIndex >= _cards.length) {
          _selectedIndex = _cards.length - 1;
        }
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = localizeFeedbackMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AppScaffold(
        appBar: GeneralAppBar(title: context.tr('existing_cards_title')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return AppScaffold(
        appBar: GeneralAppBar(title: context.tr('existing_cards_title')),
        body: Center(child: Text(_loadError!)),
      );
    }

    if (_cards.isEmpty) {
      return AppScaffold(
        appBar: GeneralAppBar(title: context.tr('existing_cards_title')),
        body: Center(child: Text(context.tr('no_saved_cards'))),
      );
    }

    final appColors = context.theme.appColors;
    final typography = context.theme.appTypography;
    final selectedCard = _cards[_selectedIndex];

    return AppScaffold(
      appBar: GeneralAppBar(title: context.tr('existing_cards_title')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: Dimens.padding),
            SizedBox(
              height: 150,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _cards.length,
                onPageChanged: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final card = _cards[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: Dimens.padding),
                    child: _SavedCardPreview(
                      card: card,
                      isSelected: index == _selectedIndex,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Dimens.largePadding),
            _ReadOnlyField(
              label: context.tr('cardholder_name_full'),
              value: selectedCard.cardholderName,
            ),
            const SizedBox(height: Dimens.padding),
            _ReadOnlyField(
              label: context.tr('card_number'),
              value: _maskCardNumber(selectedCard.cardNumber),
            ),
            const SizedBox(height: Dimens.padding),
            _ReadOnlyField(
              label: context.tr('expiration'),
              value: selectedCard.expiration,
            ),
            const SizedBox(height: Dimens.padding),
            _ReadOnlyField(label: context.tr('CVC'), value: selectedCard.cvc),
            const SizedBox(height: Dimens.largePadding),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final created = await appPush(
                        context,
                        const AddCardScreen(),
                      );
                      if (created == true && mounted) {
                        await _loadCards(selectLast: true);
                        if (_cards.isNotEmpty) {
                          _pageController.jumpToPage(_selectedIndex);
                        }
                      }
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      context.tr('add_card'),
                      style: typography.bodyMedium.copyWith(
                        color: appColors.white,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: appColors.primary,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Dimens.corners),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Dimens.padding),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final updated = await appPush(
                        context,
                        AddCardScreen(
                          initialCard: selectedCard,
                          cardIndex: _selectedIndex,
                        ),
                      );
                      if (updated == true && mounted) {
                        await _loadCards();
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: appColors.primary,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Dimens.corners),
                      ),
                    ),
                    child: Text(
                      context.tr('edit'),
                      style: typography.bodyMedium.copyWith(
                        color: appColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.selectionMode) ...[
              const SizedBox(height: Dimens.largePadding),
              AppButton(
                onPressed:
                    _cards.isNotEmpty
                        ? () {
                          appPush(context, const PaymentCompletionSuccessScreen());
                        }
                        : null,
                title: context.tr('complete_payment'),
                textStyle: typography.bodyLarge.copyWith(
                  color: appColors.white,
                ),
                borderRadius: Dimens.corners,
                margin: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SavedCardPreview extends StatelessWidget {
  const _SavedCardPreview({required this.card, required this.isSelected});

  final PaymentSavedCard card;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.appTypography;
    final darkGradient = const <Color>[Color(0xFFA63AB8), Color(0xFF5E4CE6)];
    final fadedGradient = const <Color>[Color(0xFFD8A3DD), Color(0xFFC5B5F0)];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSelected ? darkGradient : fadedGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _CardWavePainter())),
          Padding(
            padding: const EdgeInsets.all(Dimens.largePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.sim_card_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '•••• ${card.cardNumber.substring(card.cardNumber.length - 4)}',
                    style: typography.bodyLarge.copyWith(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: Dimens.smallPadding),
                Row(
                  children: [
                    Text(
                      card.cardholderName,
                      style: typography.bodyMedium.copyWith(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      Container(
                        width: 28,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: 14,
                            height: 14,
                            margin: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    final path =
        Path()
          ..moveTo(0, size.height * 0.55)
          ..quadraticBezierTo(
            size.width * 0.35,
            size.height * 0.3,
            size.width * 0.7,
            size.height * 0.58,
          )
          ..quadraticBezierTo(
            size.width * 0.85,
            size.height * 0.7,
            size.width,
            size.height * 0.5,
          )
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.appTypography;
    final appColors = context.theme.appColors;
    return SizedBox(
      width: double.infinity,
      child: BorderedContainer(
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(
          horizontal: Dimens.padding,
          vertical: Dimens.padding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: typography.labelSmall.copyWith(
                color: appColors.gray2,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(value, style: typography.bodyMedium),
          ],
        ),
      ),
    );
  }
}

String _maskCardNumber(String cardNumber) {
  if (cardNumber.length < 8) {
    return cardNumber;
  }
  final prefix = cardNumber.substring(0, 4);
  final last4 = cardNumber.substring(cardNumber.length - 4);
  return '$prefix •••• •••• $last4';
}
