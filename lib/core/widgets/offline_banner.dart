import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/connectivity_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService.instance.onlineStream,
      initialData: ConnectivityService.instance.isOnline,
      builder: (context, snapshot) {
        final online = snapshot.data ?? true;
        return Column(
          children: [
            if (!online)
              Material(
                color: context.theme.appColors.error,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          color: context.theme.appColors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'İnternet bağlantısı yok. Bağlantı gelince otomatik senkronize edilecek.',
                            style: context.theme.appTypography.labelMedium
                                .copyWith(color: context.theme.appColors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
