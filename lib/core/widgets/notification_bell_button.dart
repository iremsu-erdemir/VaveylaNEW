import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/gen/assets.gen.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/notification_badge_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_icon_buttons.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/notifications_screen.dart';

class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  final NotificationBadgeService _badgeService = NotificationBadgeService.instance;

  @override
  void initState() {
    super.initState();
    _badgeService.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _badgeService.unreadCount,
      builder: (context, unreadCount, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            AppIconButton(
              iconPath: Assets.icons.notification,
              onPressed: () {
                _badgeService.clearOnServerAndLocal();
                appPush(context, const NotificationsScreen());
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
