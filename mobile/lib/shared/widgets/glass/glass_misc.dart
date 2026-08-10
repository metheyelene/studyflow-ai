import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'glass_card.dart';

/// Translucent list row with optional leading icon, trailing, and tap.
class GlassListTile extends StatelessWidget {
  const GlassListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: g.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(color: g.textMuted, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmering placeholder used while content loads.
class GlassSkeleton extends StatelessWidget {
  const GlassSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: g.textPrimary.withValues(alpha: 0.08),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Tiny toast overlay (SnackBar wrapper styled to the glass system).
void showGlassToast(BuildContext context, String message, {bool error = false}) {
  final g = context.glass;
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (ctx) => SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 96, left: 24, right: 24),
          child: Material(
            color: Colors.transparent,
            child: GlassCard(
              tone: GlassTone.surfaceStrong,
              blurred: g.blurEnabled,
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: error ? g.danger : g.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 2200), () {
    entry.remove();
  });
}

/// Floating translucent toolbar (used by editors: bold/italic/lists/AI).
class GlassToolbar extends StatelessWidget {
  const GlassToolbar({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tone: GlassTone.surfaceSubtle,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            actions[i],
          ],
        ],
      ),
    );
  }
}
