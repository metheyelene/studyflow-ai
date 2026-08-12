import 'package:flutter/material.dart';
import '../../core/routing/app_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_info.dart';
import '../../core/services/version_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_misc.dart';

/// About the Creator — a small personal signature, non-intrusive and
/// reachable from Settings / Profile → About StudyFlow. Only the
/// explicitly provided details are shown; the email is a contact method
/// (mailto), never metadata.
class CreatorScreen extends StatefulWidget {
  const CreatorScreen({super.key});

  @override
  State<CreatorScreen> createState() => _CreatorScreenState();
}

class _CreatorScreenState extends State<CreatorScreen> {
  late final Future<AppVersion> _versionFuture;

  @override
  void initState() {
    super.initState();
    _versionFuture = AppVersion.load();
  }

  Future<void> _openMail({String? subject}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppInfo.creatorEmail,
      queryParameters: subject == null ? null : {'subject': subject},
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showGlassToast(context, "Couldn't open your email app.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final disableMotion = MediaQuery.disableAnimationsOf(context);
    final horizontal = context.isPhone ? 20.0 : 48.0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.popOrHome(),
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'About StudyFlow',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Creator card
                  _FadeSlide(
                    duration: const Duration(milliseconds: 380),
                    enabled: !disableMotion,
                    child: GlassCard(
                      tone: GlassTone.floating,
                      child: Column(
                        children: [
                          _MonogramAvatar(size: 88),
                          const SizedBox(height: 14),
                          Text(
                            AppInfo.creatorName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppInfo.creatorRole,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: g.textMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '“${AppInfo.creatorQuote}”',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: g.textMuted,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () => _openMail(),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.mail_outline,
                                    size: 16,
                                    color: g.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      AppInfo.creatorEmail,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: g.primary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GlassButton(
                            label: 'Contact Creator',
                            icon: Icons.auto_awesome,
                            onPressed: () =>
                                _openMail(subject: AppInfo.feedbackSubject),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // About StudyFlow
                  _FadeSlide(
                    duration: const Duration(milliseconds: 440),
                    enabled: !disableMotion,
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About StudyFlow',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppInfo.tagline,
                            style: TextStyle(
                              color: g.textMuted,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          for (final feature in AppInfo.features)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: g.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: TextStyle(
                                        color: g.textPrimary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Feedback
                  _FadeSlide(
                    duration: const Duration(milliseconds: 500),
                    enabled: !disableMotion,
                    child: GlassCard(
                      tone: GlassTone.surfaceSubtle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Help improve StudyFlow',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Have an idea, found something that could be better, or '
                            'discovered a bug? I’d love to hear from you.',
                            style: TextStyle(
                              color: g.textMuted,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 14),
                          GlassButton(
                            label: 'Send Feedback',
                            icon: Icons.send_outlined,
                            variant: GlassButtonVariant.glass,
                            onPressed: () =>
                                _openMail(subject: AppInfo.feedbackSubject),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Version + credits
                  _FadeSlide(
                    duration: const Duration(milliseconds: 560),
                    enabled: !disableMotion,
                    child: FutureBuilder<AppVersion>(
                      future: _versionFuture,
                      builder: (context, snapshot) {
                        final v = snapshot.data;
                        return Column(
                          children: [
                            Text(
                              v == null
                                  ? 'StudyFlow AI'
                                  : 'StudyFlow AI · Version ${v.version} · Build ${v.buildNumber}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: g.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text.rich(
                              TextSpan(
                                text: 'Created by ',
                                style: TextStyle(
                                  color: g.textMuted,
                                  fontSize: 12,
                                ),
                                children: [
                                  TextSpan(
                                    text: AppInfo.creatorName,
                                    style: TextStyle(
                                      color: g.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' · ${AppInfo.creatorRole.split(' of ').first}',
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Monogram avatar — no photograph exists, so the creator's initials in
/// the StudyFlow visual identity (never a fabricated portrait).
class _MonogramAvatar extends StatelessWidget {
  const _MonogramAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: g.primarySoft,
        border: Border.all(
          color: g.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: g.primary.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'MV',
        style: TextStyle(
          color: g.primary,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

/// Gentle fade + slight upward entrance, disabled under reduced motion.
class _FadeSlide extends StatelessWidget {
  const _FadeSlide({
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.enabled = true,
  });

  final Widget child;
  final Duration duration;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, inner) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: inner,
        ),
      ),
      child: child,
    );
  }
}
