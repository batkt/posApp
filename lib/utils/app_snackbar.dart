import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Toast-style notification banner pinned at the top of the screen ABOVE all
/// modal dialogs, bottom sheets, and barriers.
enum AppSnackVariant {
  neutral,
  error,
  success,
  warning,
}

OverlayEntry? _currentOverlayEntry;
Timer? _currentOverlayTimer;

void showAppSnackBar(
  BuildContext context,
  String message, {
  AppSnackVariant variant = AppSnackVariant.neutral,
  Duration duration = const Duration(seconds: 4),
}) {
  // Hide current active toast if present
  _currentOverlayTimer?.cancel();
  if (_currentOverlayEntry != null && _currentOverlayEntry!.mounted) {
    _currentOverlayEntry!.remove();
  }
  _currentOverlayEntry = null;

  // Use rootOverlay: true so the toast renders above any open modal sheet or dialog.
  final overlay = Overlay.maybeOf(context, rootOverlay: true) ??
      Overlay.maybeOf(context);
  if (overlay == null) return;

  final theme = Theme.of(context);
  final mq = MediaQuery.of(context);
  final brightness = theme.brightness;

  final (Color bg, Color fg, IconData icon) = switch (variant) {
    AppSnackVariant.error => (
        brightness == Brightness.dark
            ? const Color(0xFFB91C1C)
            : AppColors.error,
        AppColors.onError,
        Icons.error_outline_rounded,
      ),
    AppSnackVariant.success => (
        brightness == Brightness.dark
            ? const Color(0xFF3F6212)
            : AppColors.success,
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

  final topInset = mq.padding.top + 10;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _TopToastWidget(
      topInset: topInset,
      bg: bg,
      fg: fg,
      icon: icon,
      message: message,
      onDismiss: () {
        if (_currentOverlayEntry == entry) {
          _currentOverlayTimer?.cancel();
          if (entry.mounted) entry.remove();
          _currentOverlayEntry = null;
        }
      },
    ),
  );

  _currentOverlayEntry = entry;
  overlay.insert(entry);

  _currentOverlayTimer = Timer(duration, () {
    if (_currentOverlayEntry == entry) {
      if (entry.mounted) entry.remove();
      _currentOverlayEntry = null;
    }
  });
}

class _TopToastWidget extends StatefulWidget {
  const _TopToastWidget({
    required this.topInset,
    required this.bg,
    required this.fg,
    required this.icon,
    required this.message,
    required this.onDismiss,
  });

  final double topInset;
  final Color bg;
  final Color fg;
  final IconData icon;
  final String message;
  final VoidCallback onDismiss;

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      top: widget.topInset,
      left: 16,
      right: 16,
      child: SafeArea(
        top: false,
        bottom: false,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismiss(),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: widget.bg,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(widget.icon, color: widget.fg, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: widget.fg,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _dismiss,
                        child: Icon(
                          Icons.close_rounded,
                          color: widget.fg.withValues(alpha: 0.75),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
