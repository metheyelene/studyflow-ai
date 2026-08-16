import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User's light / dark / system preference, persisted locally so the
/// choice survives restarts. The default follows the OS via
/// `ThemeMode.system`; a stored value overrides it once loaded.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _prefsKey = 'app_theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final mode = ThemeModeController._fromStorage(raw);
        if (mode != state) state = mode;
      }
    } catch (_) {
      // Unreadable storage — fall back to following the system.
    }
  }

  void setMode(ThemeMode mode) {
    state = mode;
    unawaited(_write(mode));
  }

  Future<void> _write(ThemeMode mode) async {
    final name = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, name);
    } catch (_) {
      // Not persisted — non-fatal; the choice still applies this session.
    }
  }

  static ThemeMode _fromStorage(String raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
