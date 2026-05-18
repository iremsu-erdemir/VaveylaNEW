import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/models/home_marketing_banner_model.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/home_marketing_banners_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/colors.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/typography.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/sized_context.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../core/utils/check_device_size.dart';
import '../../data/data_source/local/sample_data.dart';
import '../bloc/banner_slider_cubit.dart';
import '../utils/marketing_banner_navigation.dart';

class BannerSliderWidget extends StatelessWidget {
  const BannerSliderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BannerSliderCubit>(
      create: (context) => BannerSliderCubit(),
      child: const _BannerSliderWidget(),
    );
  }
}

class _BannerSliderWidget extends StatefulWidget {
  const _BannerSliderWidget();

  @override
  State<_BannerSliderWidget> createState() => _BannerSliderWidgetState();
}

class _BannerSliderWidgetState extends State<_BannerSliderWidget> {
  final HomeMarketingBannersService _service = HomeMarketingBannersService();
  List<HomeMarketingBannerModel> _apiBanners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _service.fetchActive();
    if (!mounted) return;
    setState(() {
      _apiBanners = list;
      _loading = false;
    });
    if (list.isNotEmpty) {
      context.read<BannerSliderCubit>().onPageChanged(index: 0);
    }
  }

  List<Widget> _buildSlides(AppColors colors, AppTypography typography) {
    if (_apiBanners.isNotEmpty) {
      return _apiBanners
          .map(
            (b) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimens.largePadding),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Dimens.largePadding),
                  onTap: () => navigateFromMarketingBanner(context, b),
                  child: _MarketingBannerCard(banner: b, typography: typography),
                ),
              ),
            ),
          )
          .toList();
    }
    return banners
        .map(
          (path) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimens.largePadding),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Dimens.largePadding),
              child: AspectRatio(
                aspectRatio: 2.3,
                child: Image.asset(path, fit: BoxFit.cover),
              ),
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final watch = context.watch<BannerSliderCubit>();
    final read = context.read<BannerSliderCubit>();
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    if (_loading) {
      return Center(
        child: SizedBox(
          width: checkDesktopSize(context)
              ? Dimens.largeDeviceBreakPoint
              : context.widthPx,
          height: (checkDesktopSize(context)
                  ? Dimens.largeDeviceBreakPoint
                  : context.widthPx) /
              2.3,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final slides = _buildSlides(colors, typography);
    final count = slides.length;
    if (count == 0) {
      return const SizedBox.shrink();
    }

    final safeIndex = watch.state.currentIndex >= count ? 0 : watch.state.currentIndex;

    return Center(
      child: SizedBox(
        width: checkDesktopSize(context)
            ? Dimens.largeDeviceBreakPoint
            : context.widthPx,
        child: Column(
          spacing: Dimens.padding,
          children: [
            CarouselSlider(
              key: ValueKey<int>(count),
              carouselController: watch.state.controller,
              items: slides,
              options: CarouselOptions(
                autoPlay: count > 1,
                autoPlayInterval: const Duration(seconds: 6),
                enlargeCenterPage: true,
                enlargeFactor: 0.5,
                aspectRatio: 2.3,
                viewportFraction: 1,
                initialPage: safeIndex,
                onPageChanged: (final index, final reason) {
                  read.onPageChanged(index: index);
                },
              ),
            ),
            AnimatedSmoothIndicator(
              activeIndex: safeIndex.clamp(0, count - 1),
              count: count,
              effect: WormEffect(
                activeDotColor: colors.primary,
                dotColor: colors.gray,
                dotHeight: 8,
                dotWidth: 8,
                spacing: 4,
                type: WormType.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketingBannerCard extends StatelessWidget {
  const _MarketingBannerCard({
    required this.banner,
    required this.typography,
  });

  final HomeMarketingBannerModel banner;
  final AppTypography typography;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final url = banner.imageUrl.trim();
    final showOverlay = banner.hasTextOverlay;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Dimens.largePadding),
      child: AspectRatio(
        aspectRatio: 2.3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: colors.gray.withValues(alpha: 0.25),
                child: Icon(Icons.broken_image_outlined, color: colors.gray4, size: 48),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return ColoredBox(
                  color: colors.gray.withValues(alpha: 0.15),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (showOverlay)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.82),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (banner.badgeText != null && banner.badgeText!.trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              banner.badgeText!.trim(),
                              style: typography.labelSmall.copyWith(
                                color: colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (banner.subtitle != null && banner.subtitle!.trim().isNotEmpty)
                          Text(
                            banner.subtitle!.trim().toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.labelSmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              letterSpacing: 0.6,
                            ),
                          ),
                        if (banner.title != null && banner.title!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            banner.title!.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: typography.titleLarge.copyWith(
                              color: colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        if (banner.bodyText != null && banner.bodyText!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            banner.bodyText!.trim(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: typography.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
