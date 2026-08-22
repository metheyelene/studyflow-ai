import 'package:flutter/material.dart';

import '../../core/theme/bauhaus_tokens.dart';
import '../../shared/widgets/bauhaus/bauhaus_primitives.dart';

/// Bauhaus splash screen — geometric composition with StudyFlow mark.
/// Shows while the session is restoring on boot.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: BauhausColors.background,
      body: Center(
        child: BauhausLogoMark(size: 120),
      ),
    );
  }
}
