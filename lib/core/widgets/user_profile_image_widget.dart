import 'package:flutter/material.dart';

import '../gen/assets.gen.dart';
import '../theme/dimens.dart';

class UserProfileImageWidget extends StatelessWidget {
  const UserProfileImageWidget({
    super.key,
    this.width,
    this.height,
    this.imageUrl,
    this.onTap,
  });

  final double? width;
  final double? height;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.largePadding),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: width ?? 50.0,
          height: height ?? 50.0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child:
                hasImage
                    ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Image.asset(
                          Assets.images.profileImage.path,
                          fit: BoxFit.cover,
                        );
                      },
                    )
                    : Image.asset(
                      Assets.images.profileImage.path,
                      fit: BoxFit.cover,
                    ),
          ),
        ),
      ),
    );
  }
}
