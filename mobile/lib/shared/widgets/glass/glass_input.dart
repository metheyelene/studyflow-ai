import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Translucent text field matching the web input style.
class GlassInput extends StatelessWidget {
  const GlassInput({
    super.key,
    this.controller,
    this.hintText,
    this.label,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label!,
              style: TextStyle(color: g.textMuted, fontSize: 13),
            ),
          ),
        ],
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: maxLines,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          enabled: enabled,
          style: TextStyle(color: g.textPrimary, fontSize: 15),
          cursorColor: g.primary,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: g.textMuted.withValues(alpha: 0.7), fontSize: 15),
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 18, color: g.textMuted),
            suffixIcon: suffix,
            filled: true,
            fillColor: g.surfaceSubtle,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: g.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: g.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: g.primary, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: g.danger),
            ),
          ),
        ),
      ],
    );
  }
}
