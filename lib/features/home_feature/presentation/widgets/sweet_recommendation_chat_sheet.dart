import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/data/models/recommendation_models.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/recommendation_chat_controller.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/bloc/recommendation_chat_state.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/product_details_screen.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/widgets/product_image_widget.dart';

Future<void> showSweetRecommendationChatSheet({
  required BuildContext parentContext,
}) async {
  if (AppSession.userId.isEmpty) {
    parentContext.showInfoMessage('Öneriler için giriş yapmalısınız.');
    return;
  }
  await showModalBottomSheet<void>(
    context: parentContext,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (final BuildContext context) {
      return BlocProvider(
        create: (_) => RecommendationChatController(),
        child: SweetRecommendationChatSheet(parentContext: parentContext),
      );
    },
  );
}

class SweetRecommendationChatSheet extends StatefulWidget {
  const SweetRecommendationChatSheet({super.key, required this.parentContext});

  final BuildContext parentContext;

  @override
  State<SweetRecommendationChatSheet> createState() =>
      _SweetRecommendationChatSheetState();
}

class _SweetRecommendationChatSheetState
    extends State<SweetRecommendationChatSheet> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) {
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!_scroll.hasClients) {
        return;
      }
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.theme.appColors;
    final height = MediaQuery.sizeOf(context).height * 0.9;

    return BlocListener<RecommendationChatController, RecommendationChatState>(
      listenWhen: (final RecommendationChatState p, final RecommendationChatState c) =>
          c.pendingSnackError != null && p.pendingSnackError != c.pendingSnackError,
      listener: (final BuildContext context, final RecommendationChatState state) {
        final err = state.pendingSnackError;
        if (err != null) {
          context.showErrorMessage(err);
          context.read<RecommendationChatController>().clearSnackError();
        }
      },
      child: BlocConsumer<RecommendationChatController, RecommendationChatState>(
        listener: (final BuildContext context, final RecommendationChatState state) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
        },
        builder: (final BuildContext context, final RecommendationChatState state) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: height,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.gray2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, color: colors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Tatlı asistanı',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: colors.gray2.withValues(alpha: 0.5),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        itemCount: state.messages.length,
                        itemBuilder: (final BuildContext context, final int i) {
                          return _AnimatedChatMessage(
                            key: ValueKey<String>(state.messages[i].id),
                            index: i,
                            child: _MessageBlock(
                              message: state.messages[i],
                              sheetParentContext: widget.parentContext,
                            ),
                          );
                        },
                      ),
                    ),
                    if (state.showQuickReplies)
                      _QuickRepliesBar(
                        isDisabled: state.awaitingResponse,
                        isLoading: state.phase == RecommendationChatPhase.thinking,
                        selectedPreference: state.selectedPreference,
                        options: state.availableFilters,
                        onSelect: (final String label, final String apiPreference) {
                          context.read<RecommendationChatController>().selectPreference(
                                label,
                                apiPreference,
                              );
                        },
                      ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickRepliesBar extends StatelessWidget {
  const _QuickRepliesBar({
    required this.onSelect,
    required this.isDisabled,
    required this.isLoading,
    required this.selectedPreference,
    required this.options,
  });

  final void Function(String label, String apiPreference) onSelect;
  final bool isDisabled;
  final bool isLoading;
  final String selectedPreference;
  final List<RecommendationFilterOption> options;

  @override
  Widget build(final BuildContext context) {
    final colors = context.theme.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Hızlı seçim',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.black.withValues(alpha: 0.55),
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _resolveOptions().map((option) {
              final selected = selectedPreference == option.apiPreference;
              return _QuickChip(
                label: option.label,
                isDisabled: isDisabled,
                isLoading: isLoading && selected,
                isSelected: selected,
                shouldFade: selectedPreference.isNotEmpty && !selected,
                onTap: () => onSelect(option.label, option.apiPreference),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<RecommendationFilterOption> _resolveOptions() {
    if (options.isNotEmpty) {
      return options
          .map(
            (option) => RecommendationFilterOption(
              id: option.id,
              label: _localizedFilterLabel(option),
              apiPreference: option.apiPreference,
            ),
          )
          .toList();
    }
    return const <RecommendationFilterOption>[
      RecommendationFilterOption(id: 'chocolate', label: 'Çikolatalı', apiPreference: 'chocolate'),
      RecommendationFilterOption(id: 'fruit', label: 'Meyveli', apiPreference: 'fruit'),
      RecommendationFilterOption(id: 'any', label: 'Tatlı', apiPreference: 'any'),
      RecommendationFilterOption(id: 'bakery', label: 'Kahvaltılık', apiPreference: 'bakery'),
      RecommendationFilterOption(id: 'drink', label: 'İçecek', apiPreference: 'drink'),
    ];
  }

  String _localizedFilterLabel(RecommendationFilterOption option) {
    final key = option.apiPreference.trim().toLowerCase();
    return switch (key) {
      'chocolate' => 'Çikolatalı',
      'fruit' => 'Meyveli',
      'any' => 'Tatlı',
      'bakery' => 'Kahvaltılık',
      'drink' => 'İçecek',
      _ => option.label,
    };
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.onTap,
    required this.isDisabled,
    required this.isLoading,
    required this.isSelected,
    required this.shouldFade,
  });

  final String label;
  final VoidCallback onTap;
  final bool isDisabled;
  final bool isLoading;
  final bool isSelected;
  final bool shouldFade;

  @override
  Widget build(final BuildContext context) {
    final colors = context.theme.appColors;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: shouldFade ? 0.45 : (isDisabled ? 0.65 : 1),
      child: Material(
        color: isSelected
            ? colors.primary.withValues(alpha: 0.18)
            : colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          splashFactory: InkSparkle.splashFactory,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isLoading && isDisabled
                  ? SizedBox(
                      key: ValueKey<String>('loading_$label'),
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : Text(
                      key: ValueKey<String>('label_$label'),
                      label,
                      style: TextStyle(
                        color: isSelected ? colors.primary : colors.primary.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBlock extends StatelessWidget {
  const _MessageBlock({
    required this.message,
    required this.sheetParentContext,
  });

  final RecommendationChatMessage message;
  final BuildContext sheetParentContext;

  @override
  Widget build(final BuildContext context) {
    final colors = context.theme.appColors;
    if (message.loading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            children: const [
              _SkeletonRecommendationCard(),
              SizedBox(height: 10),
              _SkeletonRecommendationCard(),
            ],
          ),
        ),
      );
    }

    if (message.fromUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
              ),
            ),
            child: Text(
              message.text ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ),
      );
    }

    final children = <Widget>[];

    if (message.text != null && message.text!.isNotEmpty) {
      children.add(
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.85,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.gray2.withValues(alpha: 0.35),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
            ),
          ),
          child: Text(
            message.text!,
            style: TextStyle(
              color: colors.black.withValues(alpha: 0.88),
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    if (message.recommendations != null && message.recommendations!.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 10));
      }
      final grouped = _groupByCategoryAndSubcategory(message.recommendations!);
      grouped.forEach((sectionTitle, items) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              sectionTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        );
        for (final RecommendationItem item in items) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecommendationProductCard(
                item: item,
                parentContext: sheetParentContext,
              ),
            ),
          );
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Map<String, List<RecommendationItem>> _groupByCategoryAndSubcategory(
    List<RecommendationItem> items,
  ) {
    final grouped = <String, List<RecommendationItem>>{};
    for (final item in items) {
      final title = _groupLabel(item);
      grouped.putIfAbsent(title, () => <RecommendationItem>[]).add(item);
    }
    return grouped;
  }

  String _groupLabel(RecommendationItem item) {
    if (item.subcategory.toLowerCase().contains('fruit')) {
      return '🍓 Meyveli Tatlılar';
    }
    return switch (item.category) {
      ProductCategory.sweet => '🍫 Tatlılar',
      ProductCategory.savory => '🥐 Tuzlu Atıştırmalıklar',
      ProductCategory.bakery => '🥪 Kahvaltılıklar',
      ProductCategory.drink => '🥤 İçecekler',
      ProductCategory.snack => '🍪 Atıştırmalıklar',
      ProductCategory.unknown => '⭐ Öneriler',
    };
  }
}

class _SkeletonRecommendationCard extends StatelessWidget {
  const _SkeletonRecommendationCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    return Container(
      width: MediaQuery.sizeOf(context).width * 0.85,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.gray2.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 14,
            width: 120,
            decoration: BoxDecoration(
              color: colors.gray2.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: 180,
            decoration: BoxDecoration(
              color: colors.gray2.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: 90,
            decoration: BoxDecoration(
              color: colors.gray2.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationProductCard extends StatelessWidget {
  const _RecommendationProductCard({
    required this.item,
    required this.parentContext,
  });

  final RecommendationItem item;
  final BuildContext parentContext;

  String _categoryBadgeText() {
    return switch (item.category) {
      ProductCategory.sweet => 'Tatlı',
      ProductCategory.savory => 'Tuzlu',
      ProductCategory.drink => 'İçecek',
      ProductCategory.snack => 'Atıştırmalık',
      ProductCategory.bakery => 'Kahvaltılık',
      ProductCategory.unknown => 'Diğer',
    };
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.theme.appColors;
    final product = item.toProductModel();

    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 76,
                height: 76,
                child: buildProductImage(item.imagePath, 76, 76),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Badge(
                        text: _categoryBadgeText(),
                        icon: Icons.label_rounded,
                        color: Colors.orange,
                      ),
                      _Badge(
                        text: 'Sana özel seçildi',
                        icon: Icons.favorite_rounded,
                        color: colors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.reason.isNotEmpty ? item.reason : item.shortDescription,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.black.withValues(alpha: 0.55),
                          height: 1.25,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '${item.price} TL',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),
                      ),
                      const Spacer(),
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.of(context).pop();
                          appPush(
                            parentContext,
                            ProductDetailsScreen(product: product),
                          );
                        },
                        child: const Text('Sipariş Ver'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedChatMessage extends StatelessWidget {
  const _AnimatedChatMessage({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 220 + (index * 24)),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final dots = ((_controller.value * 3).floor() % 3) + 1;
        return Text(
          'Öneriler hazırlanıyor${'.' * dots}',
          style: TextStyle(
            color: colors.black.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
