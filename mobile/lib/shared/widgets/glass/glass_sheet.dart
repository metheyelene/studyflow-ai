import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'glass_card.dart';

/// Show a floating translucent bottom sheet with a drag handle, spring
/// animation, and (when enabled) backdrop blur. Returns the sheet's
/// result like [showModalBottomSheet].
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final g = context.glass;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    elevation: 0,
    builder: (sheetContext) => _SheetSurface(
      builder: builder,
      g: g,
      isScrollControlled: isScrollControlled,
    ),
  );
}

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.builder, required this.g, required this.isScrollControlled});

  final WidgetBuilder builder;
  final GlassTheme g;
  final bool isScrollControlled;

  @override
  Widget build(BuildContext context) {
    final maxHeight = isScrollControlled
        ? MediaQuery.sizeOf(context).height * 0.85
        : MediaQuery.sizeOf(context).height * 0.45;
    return SafeArea(
      top: false,
      child: GlassCard(
        tone: GlassTone.surfaceStrong,
        blurred: g.blurEnabled,
        radius: 28,
        padding: EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: g.textMuted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(child: builder(context)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Show a glass modal dialog: blurred backdrop surface, scale + fade
/// entrance, centered. Returns the dialog's result like [showDialog].
Future<T?> showGlassModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final g = context.glass;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          tone: GlassTone.surfaceStrong,
          blurred: g.blurEnabled,
          radius: 24,
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: builder(ctx),
          ),
        ),
      ),
    ),
  );
}
