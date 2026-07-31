import 'package:flutter/material.dart';

import '../theme/notification_theme.dart';

class FoodMatchNotificationToast extends StatelessWidget {
  const FoodMatchNotificationToast({
    super.key,
    required this.type,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.showTrailingDot = false,
  });

  final FoodMatchNotificationType type;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final bool showTrailingDot;

  @override
  Widget build(BuildContext context) {
    final FoodMatchNotificationColors colors = Theme.of(
      context,
    ).extension<FoodMatchNotificationTheme>()!.colorsFor(type);
    final bool hasMessage = message?.trim().isNotEmpty ?? false;
    final bool hasAction =
        actionLabel?.trim().isNotEmpty == true && onAction != null;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        constraints: BoxConstraints(minHeight: hasMessage ? 84 : 72),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon ?? _defaultIcon, color: colors.icon, size: 25),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.titleColor,
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (hasMessage) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      message!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.subtitleColor,
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasAction) ...<Widget>[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: colors.actionColor,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  actionLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ] else if (showTrailingDot) ...<Widget>[
              const SizedBox(width: 12),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: colors.trailingDotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData get _defaultIcon => switch (type) {
    FoodMatchNotificationType.success => Icons.check_rounded,
    FoodMatchNotificationType.destructive => Icons.delete_outline_rounded,
    FoodMatchNotificationType.warning => Icons.warning_amber_rounded,
    FoodMatchNotificationType.info => Icons.info_outline_rounded,
    FoodMatchNotificationType.error => Icons.error_outline_rounded,
  };
}
