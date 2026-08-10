import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shown only while the session is restoring on boot — kept fast and
/// minimal (no artificial delay).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: g.primarySoft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.auto_stories, size: 34, color: g.primary),
            ),
            const SizedBox(height: 14),
            Text(
              'StudyFlow',
              style: TextStyle(
                color: g.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
