import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/sized_context.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_rating_summary.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_choice_chip.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_read_more_text.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/widgets/product_image_widget.dart';

import '../../../../core/gen/assets.gen.dart';
import '../../../../core/theme/dimens.dart';
import '../../../cart_feature/data/models/product_model.dart'
    show ProductModel, ProductSaleUnit;
import '../../../cart_feature/presentation/bloc/cart_cubit.dart';
import '../../../../core/utils/product_description_helper.dart';
import '../../../../core/utils/profanity_validator.dart';
import '../../data/data_source/local/sample_data.dart';
import '../../data/models/customer_review_model.dart';
import '../../data/services/customer_favorites_service.dart';
import '../../data/services/customer_review_service.dart';
import '../widgets/product_details_app_bar.dart';
import '../../data/services/feedback_service.dart';
import 'feedback_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, this.product});

  final ProductModel? product;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  String _selectedWeight = weights.contains('1 kg') ? '1 kg' : weights.first;
  int _sliceCount = 1;
  final CustomerReviewService _reviewService = CustomerReviewService();
  final CustomerFavoritesService _favoritesService = CustomerFavoritesService();
  List<CustomerReviewModel> _reviews = const [];
  bool _isLoadingReviews = false;
  bool _isFavorite = false;
  int _reviewPage = 1;
  bool _hasMoreReviews = false;
  int _totalReviewCount = 0;

  double get _selectedWeightKg {
    final normalized = _selectedWeight
        .toLowerCase()
        .replaceAll('kg', '')
        .trim();
    return double.tryParse(normalized) ?? 1.0;
  }

  bool get _isSliceProduct =>
      widget.product?.saleUnit == ProductSaleUnit.perSlice;

  int get _calculatedPrice {
    final p = widget.product;
    if (p == null) return 50;
    if (p.saleUnit == ProductSaleUnit.perSlice) {
      return (p.price * _sliceCount).round();
    }
    // API fiyatı kg başına (restoran "kilo" birimi).
    return (p.price * _selectedWeightKg).round();
  }

  double get _calculatedRating {
    if (_reviews.isNotEmpty) {
      final total = _reviews.fold<int>(0, (sum, review) => sum + review.rating);
      return total / _reviews.length;
    }
    return widget.product?.rate ?? 0;
  }

  int get _calculatedReviewCount {
    if (_totalReviewCount > 0) {
      return _totalReviewCount;
    }
    if (_reviews.isNotEmpty) {
      return _reviews.length;
    }
    return widget.product?.reviewCount ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    final userId = AppSession.userId;
    final productId = widget.product?.id ?? '';
    if (userId.isEmpty || productId.isEmpty) {
      return;
    }
    try {
      final favorites = await _favoritesService.getFavorites(customerUserId: userId);
      if (!mounted) return;
      setState(() {
        _isFavorite = favorites.products.any((x) => x.id == productId);
      });
    } catch (_) {}
  }

  Future<void> _loadReviews({bool reset = true}) async {
    final restaurantId = widget.product?.restaurantId;
    final productId = widget.product?.id;
    if (restaurantId == null ||
        restaurantId.isEmpty ||
        productId == null ||
        productId.isEmpty) {
      return;
    }
    if (reset) {
      _reviewPage = 1;
      _hasMoreReviews = false;
      _totalReviewCount = 0;
    }
    setState(() => _isLoadingReviews = true);
    try {
      final loaded = await _reviewService.getReviews(
        targetType: 'menu',
        targetId: productId,
        restaurantId: restaurantId,
        page: _reviewPage,
        pageSize: 10,
      );
      if (!mounted) return;
      setState(() {
        _totalReviewCount = loaded.totalCount;
        if (reset) {
          _reviews = loaded.items;
        } else {
          _reviews = [..._reviews, ...loaded.items];
        }
        final shown = _reviews.length;
        _hasMoreReviews = shown < _totalReviewCount;
      });
    } catch (_) {
      // Keep UI silent for now.
    } finally {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColor = context.theme.appColors;
    final appTypography = context.theme.appTypography;
    return AppScaffold(
      safeAreaTop: false,
      safeAreaBottom: false,
      padding: EdgeInsets.zero,
      body: SizedBox(
        height: context.heightPx,
        child: Stack(
          children: [
            _buildProductImage(context),
            ProductDetailsAppBar(
              isFavorite: _isFavorite,
              onFavoriteTap: _toggleFavorite,
              onFeedbackTap: widget.product != null && widget.product!.id.isNotEmpty
                  ? () => appPush(
                      context,
                      FeedbackScreen(
                        prefilledMenuItemId: widget.product!.id,
                        initialTarget: CustomerFeedbackTargetType.bakeryProduct,
                      ),
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              child: Stack(
                children: [
                  Positioned(
                    bottom: 0,
                    child: Container(
                      height: 140,
                      color: appColor.primary,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimens.largePadding,
                            vertical: Dimens.padding,
                          ),
                          child: SizedBox(
                            width:
                                (context.widthPx < Dimens.largeDeviceBreakPoint
                                    ? context.widthPx
                                    : Dimens.mediumDeviceBreakPoint) -
                                32,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      formatPrice(_calculatedPrice),
                                      style: appTypography.bodyLarge.copyWith(
                                        color: appColor.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      _isSliceProduct
                                          ? '$_sliceCount dilim'
                                          : _selectedWeight,
                                      style: appTypography.labelSmall.copyWith(
                                        color: appColor.white.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  width: 222,
                                  child: AppButton(
                                    margin: EdgeInsets.zero,
                                    title: 'Sepete ekle',
                                    onPressed: _addToCart,
                                    borderRadius: Dimens.corners,
                                    color: appColor.white,
                                    textStyle: appTypography.bodyLarge.copyWith(
                                      color: appColor.primary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    iconColor: appColor.primary,
                                    iconPath: Assets.icons.shoppingCart,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: context.heightPx * 0.4,
                    margin: EdgeInsets.only(bottom: 112),
                    width:
                        context.widthPx < Dimens.largeDeviceBreakPoint
                            ? context.widthPx
                            : Dimens.mediumDeviceBreakPoint,
                    decoration: BoxDecoration(
                      color: context.theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(Dimens.corners * 2),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(Dimens.largePadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.product?.name ?? 'Çikolatalı Pasta',
                                style: appTypography.bodyLarge.copyWith(
                                  fontSize: 18,
                                ),
                              ),
                              AppRatingSummary(
                                rating: _calculatedRating,
                                reviewCount: _calculatedReviewCount,
                              ),
                            ],
                          ),
                          SizedBox(height: Dimens.largePadding),
                          AppReadMoreText(
                            productDescriptionFor(
                              ProductDescriptionInput(
                                name: widget.product?.name ?? 'Ürün',
                                categoryName: widget.product?.categoryName,
                              ),
                            ),
                          ),
                          SizedBox(height: Dimens.padding),
                          Divider(height: Dimens.largePadding),
                          Text(
                            'Satıcı',
                            style: appTypography.bodyLarge.copyWith(
                              fontSize: 18,
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: SizedBox(
                              width: 44,
                              height: 44,
                              child: ClipOval(
                                child: buildProductImage(
                                  widget.product?.restaurantPhotoPath ?? '',
                                  44,
                                  44,
                                ),
                              ),
                            ),
                            title: Text(
                              widget.product?.restaurantName ?? 'Satıcı',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(
                                top: Dimens.padding,
                              ),
                              child: Text(
                                widget.product?.restaurantType ??
                                    widget.product?.categoryName ??
                                    'Tatlı & Pasta',
                              ),
                            ),
                          ),
                          Divider(height: 0),
                          SizedBox(height: Dimens.padding),
                          if (widget.product != null) ...[
                            Text(
                              'Birim fiyat: ${formatPrice(widget.product!.price)} / ${_isSliceProduct ? 'dilim' : 'kg'}',
                              style: appTypography.bodySmall.copyWith(
                                color: appColor.gray4,
                              ),
                            ),
                            const SizedBox(height: Dimens.padding),
                          ],
                          if (_isSliceProduct) ...[
                            Text(
                              'Dilim sayısı',
                              style: appTypography.bodyLarge.copyWith(
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: Dimens.padding),
                            Row(
                              children: [
                                IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: appColor.primary,
                                    foregroundColor: appColor.white,
                                  ),
                                  onPressed:
                                      _sliceCount > 1
                                          ? () => setState(
                                            () => _sliceCount -= 1,
                                          )
                                          : null,
                                  icon: const Icon(Icons.remove),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Dimens.largePadding,
                                  ),
                                  child: Text(
                                    '$_sliceCount',
                                    style: appTypography.titleLarge.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: appColor.primary,
                                    foregroundColor: appColor.white,
                                  ),
                                  onPressed:
                                      () => setState(() => _sliceCount += 1),
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              'Ağırlık seç',
                              style: appTypography.bodyLarge.copyWith(
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: Dimens.padding),
                            Wrap(
                              spacing: Dimens.largePadding,
                              children:
                                  weights.map((weight) {
                                    final isSelected = _selectedWeight == weight;
                                    return AppChoiceChip(
                                      label: weight,
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedWeight = weight;
                                        });
                                      },
                                    );
                                  }).toList(),
                            ),
                          ],
                          const SizedBox(height: Dimens.largePadding),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Yorumlar ($_calculatedReviewCount)',
                                style: appTypography.bodyLarge.copyWith(
                                  fontSize: 18,
                                ),
                              ),
                              TextButton(
                                onPressed: _openReviewSheet,
                                child: const Text('Yorum yap'),
                              ),
                            ],
                          ),
                          if (_isLoadingReviews)
                            const Center(child: CircularProgressIndicator())
                          else if (_reviews.isEmpty)
                            Text(
                              'Bu ürün için henüz yorum yok.',
                              style: appTypography.bodySmall.copyWith(
                                color: appColor.gray4,
                              ),
                            )
                          else
                            Column(
                              children: [
                                ..._reviews
                                    .map((review) => _buildReviewTile(review))
                                    .toList(),
                                if (_hasMoreReviews)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: () {
                                        _reviewPage += 1;
                                        _loadReviews(reset: false);
                                      },
                                      child: const Text('Daha fazla yorum yükle'),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(BuildContext context) {
    final imageUrl = widget.product?.imageUrl;
    final width = context.widthPx;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http') || imageUrl.startsWith('blob:')) {
        return Image.network(
          imageUrl,
          width: width,
          fit: BoxFit.fitWidth,
          errorBuilder: (_, __, ___) => _defaultProductImage(width),
        );
      }
      if (imageUrl.startsWith('assets/')) {
        return Image.asset(
          imageUrl,
          width: width,
          fit: BoxFit.fitWidth,
          errorBuilder: (_, __, ___) => _defaultProductImage(width),
        );
      }
      return buildProductImage(imageUrl, width, 300);
    }
    return _defaultProductImage(width);
  }

  Widget _defaultProductImage(double width) {
    return Assets.images.bigCake.image(
      width: width,
      fit: BoxFit.fitWidth,
    );
  }

  // ignore: unused_element
  Future<void> _openRestaurantWhatsApp(BuildContext context) async {
    final phone = widget.product?.restaurantPhone;
    if (phone == null || phone.trim().isEmpty) {
      context.showErrorMessage('Telefon numarası bulunamadı.');
      return;
    }

    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      context.showErrorMessage('Geçersiz telefon numarası: $phone');
      return;
    }

    final message =
        'Merhaba, ${widget.product?.name ?? 'ürün'} hakkında bilgi alabilir miyim?';
    final uri = Uri.parse(
      'https://wa.me/$digitsOnly?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        context.showErrorMessage('WhatsApp açılamadı: $phone');
      }
    }
  }

  Future<void> _addToCart() async {
    final product = widget.product;
    if (product == null) return;
    final isSlice = product.saleUnit == ProductSaleUnit.perSlice;
    final selectedProduct = isSlice
        ? product.copyWith(
            price: _calculatedPrice.toDouble(),
            weight: _sliceCount.toDouble(),
          )
        : product.copyWith(
            price: _calculatedPrice.toDouble(),
            weight: _selectedWeightKg,
          );
    final cartCubit = context.read<CartCubit>();
    final errorMessage = await cartCubit.addItem(selectedProduct);
    if (!mounted) return;
    if (errorMessage == null) {
      context.showSuccessMessage('${product.name} sepete eklendi!');
      return;
    }
    context.showErrorMessage(errorMessage);
  }

  Future<void> _toggleFavorite() async {
    final userId = AppSession.userId;
    final productId = widget.product?.id ?? '';
    if (userId.isEmpty || productId.isEmpty) {
      context.showErrorMessage('Favori için giriş yapmalısınız.');
      return;
    }
    try {
      if (_isFavorite) {
        await _favoritesService.removeProductFavorite(
          customerUserId: userId,
          productId: productId,
        );
      } else {
        await _favoritesService.addProductFavorite(
          customerUserId: userId,
          productId: productId,
        );
      }
      if (!mounted) return;
      setState(() => _isFavorite = !_isFavorite);
      context.showSuccessMessage(
        _isFavorite ? 'Favorilere eklendi.' : 'Favorilerden çıkarıldı.',
      );
    } catch (error) {
      if (!mounted) return;
      context.showErrorMessage(error.toString());
    }
  }

  Widget _buildReviewTile(CustomerReviewModel review) {
    final appColor = context.theme.appColors;
    final isMine = review.customerUserId == AppSession.userId;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: Dimens.padding),
      padding: const EdgeInsets.all(Dimens.padding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimens.corners),
        border: Border.all(color: appColor.gray.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.customerName,
                  style: context.theme.appTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ...List.generate(
                5,
                (i) => Icon(
                  i < review.rating ? Icons.star : Icons.star_border,
                  size: 16,
                  color: appColor.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(review.comment),
          const SizedBox(height: 4),
          Text(
            review.date,
            style: context.theme.appTypography.bodySmall.copyWith(
              color: appColor.gray4,
            ),
          ),
          if (review.ownerReply != null && review.ownerReply!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Pastane yanıtı: ${review.ownerReply!}',
                style: context.theme.appTypography.bodySmall.copyWith(
                  color: appColor.primary,
                ),
              ),
            ),
          if (isMine)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _openReviewSheet(existing: review),
                  child: const Text('Güncelle'),
                ),
                TextButton(
                  onPressed: () => _deleteReview(review),
                  child: const Text('Sil'),
                ),
              ],
            ),
          if (!isMine)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _reportReview(review),
                child: const Text('Raporla'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _reportReview(CustomerReviewModel review) async {
    final userId = AppSession.userId;
    if (userId.isEmpty) return;
    final controller = TextEditingController(text: 'Uygunsuz içerik');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yorumu raporla'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Rapor nedeni'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _reviewService.reportReview(
                  customerUserId: userId,
                  reviewId: review.id,
                  reason: controller.text.trim(),
                );
                if (!mounted) return;
                Navigator.pop(dialogContext);
                context.showSuccessMessage('Yorum raporlandı.');
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(dialogContext);
                context.showErrorMessage('Rapor gönderilemedi: $e');
              }
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReview(CustomerReviewModel review) async {
    final userId = AppSession.userId;
    if (userId.isEmpty) return;
    try {
      await _reviewService.deleteReview(customerUserId: userId, reviewId: review.id);
      await _loadReviews();
    } catch (e) {
      if (!mounted) return;
      context.showErrorMessage('Yorum silinemedi: $e');
    }
  }

  Future<void> _openReviewSheet({CustomerReviewModel? existing}) async {
    final userId = AppSession.userId;
    final product = widget.product;
    if (userId.isEmpty || product == null) {
      context.showErrorMessage('Yorum için giriş yapmalısınız.');
      return;
    }
    int selectedRating = existing?.rating ?? 5;
    final controller = TextEditingController(text: existing?.comment ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: Dimens.largePadding,
                right: Dimens.largePadding,
                top: Dimens.largePadding,
                bottom:
                    MediaQuery.of(sheetContext).viewInsets.bottom +
                    Dimens.largePadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existing == null ? 'Yorum yap' : 'Yorumu güncelle',
                    style: context.theme.appTypography.titleMedium,
                  ),
                  const SizedBox(height: Dimens.padding),
                  Wrap(
                    spacing: 4,
                    children: List.generate(
                      5,
                      (i) => IconButton(
                        onPressed: () => setModalState(() => selectedRating = i + 1),
                        icon: Icon(
                          i < selectedRating ? Icons.star : Icons.star_border,
                          color: context.theme.appColors.primary,
                        ),
                      ),
                    ),
                  ),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Yorumunuzu yazın'),
                  ),
                  const SizedBox(height: Dimens.largePadding),
                  AppButton(
                    title: existing == null ? 'Gönder' : 'Kaydet',
                    onPressed: () async {
                      final comment = controller.text.trim();
                      if (comment.isEmpty) return;
                      final profanityError =
                          ProfanityValidator.validateOrNull(comment);
                      if (profanityError != null) {
                        if (!context.mounted) return;
                        context.showErrorMessage(profanityError);
                        return;
                      }
                      try {
                        if (existing == null) {
                          await _reviewService.createReview(
                            customerUserId: userId,
                            restaurantId: product.restaurantId ?? '',
                            targetType: 'menu',
                            targetId: product.id,
                            rating: selectedRating,
                            comment: comment,
                            customerName: AppSession.fullName,
                          );
                        } else {
                          await _reviewService.updateReview(
                            customerUserId: userId,
                            reviewId: existing.id,
                            rating: selectedRating,
                            comment: comment,
                          );
                        }
                        if (!mounted) return;
                        Navigator.pop(sheetContext);
                        await _loadReviews();
                      } catch (e) {
                        if (!mounted) return;
                        context.showErrorMessage('Yorum kaydedilemedi: $e');
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
