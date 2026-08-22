import 'package:flutter/material.dart';

import '../../core/theme/swiss_tokens.dart';

/// Swiss splash screen — minimal, editorial, no decoration.
/// Shows while the session is restoring on boot.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SwissColors.darkBackground : SwissColors.background;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Swiss mark — black square with white text
            Container(
              width: 64,
              height: 64,
              color: fg,
              alignment: Alignment.center,
              child: Icon(
                Icons.school,
                size: 32,
                color: bg,
              ),
            ),
            const SizedBox(height: SwissSpacing.xl),
            Text(
              'STUDYFLOW',
              style: SwissTypography.label.copyWith(
                color: fg,
                letterSpacing: 3.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
