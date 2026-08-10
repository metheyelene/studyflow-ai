import 'package:flutter/material.dart';

/// Breakpoint helpers (docs/mobile-flutter-plan.md §8):
///   phone (< 600dp)      → bottom tab bar, single panes
///   tablet (600–899dp)   → navigation rail
///   desktop/large (≥900) → rail + master-detail where useful
enum StudyFlowBreakpoint { phone, tablet, desktop }

extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);

  StudyFlowBreakpoint get breakpoint {
    final width = screenSize.width;
    if (width >= 900) return StudyFlowBreakpoint.desktop;
    if (width >= 600) return StudyFlowBreakpoint.tablet;
    return StudyFlowBreakpoint.phone;
  }

  bool get isPhone => breakpoint == StudyFlowBreakpoint.phone;
  bool get isTablet => breakpoint == StudyFlowBreakpoint.tablet;
  bool get isDesktop => breakpoint == StudyFlowBreakpoint.desktop;
}
