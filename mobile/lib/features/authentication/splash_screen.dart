import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/graphics/sf_graphics.dart';

/// Shown only while the session is restoring on boot — kept fast and
/// minimal (no artificial delay). The StudyFlow mark draws itself: a
/// thin line grows into a knowledge structure, then collapses back into
/// the logo.
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
            // The branded monochrome mark.
            const SFSplashGraphic(size: Size(112, 112)),
            const SizedBox(height: 10),
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
