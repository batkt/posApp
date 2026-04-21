import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Toast-style snack bar pinned below the status bar (not at the bottom).
enum AppSnackVariant {
  neutral,
  error,
  success,
  warning,
}

void showAppSnackBar(
  BuildContext context,
  String message, {
  AppSnackVariant variant = AppSnackVariant.neutral,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final theme = Theme.of(context);
  final mq = MediaQuery.of(context);
  final brightness = theme.brightness;

  final (Color bg, Color fg, IconData icon) = switch (variant) {
    AppSnackVariant.error => (
        brightness == Brightness.dark ? const Color(0xFFB91C1C) : AppColors.error,
        AppColors.onError,
        Icons.error_outline_rounded,
      ),
    AppSnackVariant.success => (
        brightness == Brightness.dark ? const Color(0xFF3F6212) : AppColors.success,
        brightness == Brightness.dark ? Colors.white : AppColors.onSuccess,
        Icons.check_circle_rounded,
      ),
    AppSnackVariant.warning => (
        AppColors.warningContainer,
        AppColors.onWarningContainer,
        Icons.warning_amber_rounded,
      ),
    AppSnackVariant.neutral => (
        theme.colorScheme.inverseSurface,
        theme.colorScheme.onInverseSurface,
        Icons.info_outline_rounded,
      ),
  };

  final screenH = mq.size.height;
  final topInset = mq.viewPadding.top + 8;
  const estimatedSnackHeight = 80.0;
  final bottomMargin = (screenH - topInset - estimatedSnackHeight)
      .clamp(24.0, screenH);

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      elevation: 8,
      behavior: SnackBarBehavior.floating,
      backgroundColor: bg,
      dismissDirection: DismissDirection.up,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: EdgeInsets.only(left: 16, right: 16, bottom: bottomMargin),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: duration,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: fg,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
