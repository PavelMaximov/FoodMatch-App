import 'package:flutter/material.dart';

import '../theme/notification_theme.dart';
import '../widgets/food_match_notification_toast.dart';

class FoodMatchNotifications {
  const FoodMatchNotifications._();

  static void show(
    BuildContext context, {
    required FoodMatchNotificationType type,
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    IconData? icon,
    bool showTrailingDot = false,
  }) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    bool actionHandled = false;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: EdgeInsets.zero,
        duration: _durationFor(type, hasAction: onAction != null),
        content: FoodMatchNotificationToast(
          type: type,
          title: title,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction == null
              ? null
              : () {
                  if (actionHandled) return;
                  actionHandled = true;
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
          icon: icon,
          showTrailingDot: showTrailingDot,
        ),
      ),
    );
  }

  static Duration _durationFor(
    FoodMatchNotificationType type, {
    required bool hasAction,
  }) {
    if (hasAction) return const Duration(seconds: 6);
    return switch (type) {
      FoodMatchNotificationType.success ||
      FoodMatchNotificationType.info => const Duration(seconds: 3),
      FoodMatchNotificationType.warning => const Duration(seconds: 4),
      FoodMatchNotificationType.error => const Duration(seconds: 4),
      FoodMatchNotificationType.destructive => const Duration(seconds: 4),
    };
  }
}
