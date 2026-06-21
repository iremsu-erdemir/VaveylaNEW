import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/formatters.dart';
import 'package:flutter_sweet_shop_app_ui/features/restaurant_owner_feature/widgets/product_image_widget.dart';

/// Modern, clean order card component following consistent design principles
class ModernOrderCard extends StatelessWidget {
  const ModernOrderCard({
    super.key,
    required this.productName,
    required this.price,
    required this.imageUrl,
    this.dateTime,
    this.status,
    this.statusColor,
    this.quantity,
    this.onTap,
    this.imageSize = 72.0,
    this.showShadow = true,
    this.actionButton,
    this.statusOnBottomRight = false,
    this.dateTimeTopSpacing = 6.0,
    this.detailLine,
  });

  final String productName;
  final int price; // Price in cents/kuruş
  final String imageUrl;
  /// İndirim, platform payı vb. ikinci bilgi satırı (sipariş özeti).
  final String? detailLine;
  final String? dateTime; // Formatted date string like "01.03.2026 • 11:53"
  final String? status;
  final Color? statusColor;
  final int? quantity;
  final VoidCallback? onTap;
  final double imageSize;
  final bool showShadow;
  final Widget? actionButton; // Optional action button (like "Tekrar Sipariş")
  final bool statusOnBottomRight;
  final double dateTimeTopSpacing;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.appColors;
    final typography = context.theme.appTypography;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: showShadow ? [
            BoxShadow(
              color: colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: colors.black.withValues(alpha: 0.02),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ] : null,
          border: showShadow ? null : Border.all(
            color: colors.gray.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            // Left Section - Product Image
            _ProductImage(
              imageUrl: imageUrl,
              size: imageSize,
            ),
            
            const SizedBox(width: 16), // Gap between image and content
            
            // Right Section - Order Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row - Product Name & Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          productName,
                          style: typography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatPrice(price),
                        style: typography.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),

                  if (detailLine != null && detailLine!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      detailLine!,
                      style: typography.bodySmall.copyWith(
                        color: colors.gray4,
                        fontSize: 13,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  // Middle Row - Date/Time + Quantity (if available)
                  if (dateTime != null || quantity != null) ...[
                    SizedBox(height: dateTimeTopSpacing),
                    Row(
                      children: [
                        if (dateTime != null)
                          Expanded(
                            child: Text(
                              dateTime!,
                              style: typography.bodySmall.copyWith(
                                color: colors.gray4,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (quantity != null && quantity! > 1) ...[
                          if (dateTime != null) const SizedBox(width: 8),
                          Text(
                            'Adet: $quantity',
                            style: typography.bodySmall.copyWith(
                              color: colors.gray4,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  
                  // Bottom Row - Status & Action Button
                  if (status != null || actionButton != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (status != null && !statusOnBottomRight)
                          _StatusPill(
                            status: status!,
                            color: statusColor ?? _getStatusColor(colors, status!),
                          ),
                        if (status != null && statusOnBottomRight) const Spacer(),
                        if (status != null && statusOnBottomRight)
                          _StatusPill(
                            status: status!,
                            color: statusColor ?? _getStatusColor(colors, status!),
                          ),
                        if (actionButton != null) const Spacer(),
                        if (actionButton == null &&
                            status != null &&
                            !statusOnBottomRight)
                          const Spacer(),
                        if (actionButton != null)
                          actionButton!,
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(dynamic colors, String status) {
    switch (status.toLowerCase()) {
      case 'tamamlandı':
      case 'tamamlanan':
      case 'completed':
        return colors.success;
      case 'beklemede':
      case 'bekleyen':
      case 'pending':
        return colors.warning;
      case 'hazırlanıyor':
      case 'preparing':
        return colors.primary;
      case 'iptal':
      case 'iptal edildi':
      case 'canceled':
      case 'cancelled':
        return colors.error;
      default:
        return colors.gray4;
    }
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.imageUrl,
    required this.size,
  });

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    if (imageUrl.trim().isEmpty) {
      return _buildPlaceholder();
    }
    return buildProductImage(imageUrl, size, size);
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(
        Icons.fastfood,
        color: Colors.grey,
        size: 32,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.status,
    required this.color,
  });

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.appTypography;
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: typography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Compact version for smaller spaces (like checkout)
class CompactOrderCard extends ModernOrderCard {
  const CompactOrderCard({
    super.key,
    required super.productName,
    required super.price,
    required super.imageUrl,
    super.quantity,
    super.onTap,
  }) : super(
          imageSize: 64.0,
          showShadow: false,
        );
}