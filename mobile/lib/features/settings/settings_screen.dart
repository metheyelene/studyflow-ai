import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/performance/device_tier.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import 'ai_preferences.dart';

/// Settings — AI preferences (style/level/language), appearance
/// (light/dark/system), and About StudyFlow → Creator.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _showAppearance = false;
  bool _showAiPreferences = false;

  void _toggleAppearance() =>
      setState(() => _showAppearance = !_showAppearance);

  void _toggleAiPreferences() =>
      setState(() => _showAiPreferences = !_showAiPreferences);

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final themeMode = ref.watch(themeModeProvider);
    final reduceEffects = ref.watch(reduceEffectsProvider);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
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
                        'Settings',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        GlassListTile(
                          title: 'Profile',
                          subtitle: 'Name, study level, preferences',
                          leading: Icon(
                            Icons.person_outline,
                            size: 22,
                            color: g.primary,
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: g.textMuted,
                          ),
                          onTap: () => showGlassToast(
                            context,
                            'Profile editing arrives with sign-in.',
                          ),
                        ),
                        const Divider(
                          color: Color(0x14000000),
                          height: 1,
                          indent: 50,
                        ),
                        GlassListTile(
                          title: 'Appearance',
                          subtitle: 'Light / dark / system',
                          leading: Icon(
                            Icons.palette_outlined,
                            size: 22,
                            color: g.primary,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                switch (themeMode) {
                                  ThemeMode.light => 'Light',
                                  ThemeMode.dark => 'Dark',
                                  ThemeMode.system => 'System',
                                },
                                style: AppText.small.copyWith(
                                  color: g.textMuted,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _showAppearance
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                                color: g.textMuted,
                              ),
                            ],
                          ),
                          onTap: _toggleAppearance,
                        ),
                        if (_showAppearance)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                            child: SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  icon: Icon(Icons.light_mode_outlined),
                                  label: Text('Light'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  icon: Icon(Icons.dark_mode_outlined),
                                  label: Text('Dark'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  icon: Icon(Icons.brightness_auto_outlined),
                                  label: Text('System'),
                                ),
                              ],
                              selected: {themeMode},
                              showSelectedIcon: false,
                              onSelectionChanged: (selection) => ref
                                  .read(themeModeProvider.notifier)
                                  .setMode(selection.first),
                            ),
                          ),
                        if (_showAppearance)
                          GlassListTile(
                            title: 'Reduce visual effects',
                            subtitle:
                                'Smaller blur and a plainer background — '
                                'smoother on low-end devices.',
                            leading: Icon(
                              Icons.animation_outlined,
                              size: 22,
                              color: g.primary,
                            ),
                            trailing: Switch(
                              value: reduceEffects,
                              onChanged: (value) => ref
                                  .read(reduceEffectsProvider.notifier)
                                  .setEnabled(value),
                            ),
                          ),
                        const Divider(
                          color: Color(0x14000000),
                          height: 1,
                          indent: 50,
                        ),
                        GlassListTile(
                          title: 'AI preferences',
                          subtitle: 'Response style, level, language',
                          leading: Icon(
                            Icons.tune_outlined,
                            size: 22,
                            color: g.primary,
                          ),
                          trailing: Icon(
                            _showAiPreferences
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 20,
                            color: g.textMuted,
                          ),
                          onTap: _toggleAiPreferences,
                        ),
                        if (_showAiPreferences)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                            child: _AiPreferencesPanel(
                              onChanged: (next) =>
                                  _saveAiPreferences(context, ref, next),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        GlassListTile(
                          title: 'About StudyFlow',
                          subtitle: 'About the app and its creator',
                          leading: Icon(
                            Icons.info_outline,
                            size: 22,
                            color: g.primary,
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: g.textMuted,
                          ),
                          onTap: () => context.go(AppRoutes.aboutCreator),
                        ),
                      ],
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

/// Optimistically apply a preference change, persist it server-side, and
/// revert with a friendly toast when the save fails. The optimistic value
/// keeps the UI feeling instant; the server is the source of truth.
Future<void> _saveAiPreferences(
  BuildContext context,
  WidgetRef ref,
  AiPreferences next,
) async {
  final notifier = ref.read(aiPreferencesControllerProvider.notifier);
  final previous = ref.read(aiPreferencesControllerProvider).valueOrNull;
  notifier.set(next);
  try {
    await ref.read(aiPreferencesRepositoryProvider).save(next);
  } catch (_) {
    if (previous != null) notifier.set(previous);
    if (context.mounted) {
      showGlassToast(
        context,
        "We couldn't save your preferences. Please try again.",
      );
    }
  }
}

/// The expanded AI preferences panel: response style, study level, and
/// language — the only AI configuration the app shows. It loads lazily
/// from the backend when first expanded and shows honest loading/error
/// states instead of fake defaults.
class _AiPreferencesPanel extends ConsumerWidget {
  const _AiPreferencesPanel({required this.onChanged});

  final ValueChanged<AiPreferences> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final prefs = ref.watch(aiPreferencesControllerProvider);
    return prefs.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          GlassSkeleton(width: 110, height: 13),
          SizedBox(height: 8),
          GlassSkeleton(width: double.infinity, height: 38),
          SizedBox(height: 14),
          GlassSkeleton(width: 90, height: 13),
          SizedBox(height: 8),
          GlassSkeleton(width: double.infinity, height: 38),
        ],
      ),
      error: (_, _) => Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: g.textMuted.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Could not load your AI preferences.',
              style: AppText.small.copyWith(color: g.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(aiPreferencesControllerProvider),
            style: TextButton.styleFrom(foregroundColor: g.primary),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (prefs) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PrefLabel('Response style'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AiResponseStyle>(
              segments: const [
                ButtonSegment(
                  value: AiResponseStyle.concise,
                  label: Text('Concise'),
                ),
                ButtonSegment(
                  value: AiResponseStyle.balanced,
                  label: Text('Balanced'),
                ),
                ButtonSegment(
                  value: AiResponseStyle.detailed,
                  label: Text('Detailed'),
                ),
              ],
              selected: {prefs.responseStyle},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  onChanged(prefs.copyWith(responseStyle: selection.first)),
            ),
          ),
          const SizedBox(height: 16),
          const _PrefLabel('Study level'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AiStudyLevel>(
              segments: const [
                ButtonSegment(
                  value: AiStudyLevel.school,
                  label: Text('School'),
                ),
                ButtonSegment(
                  value: AiStudyLevel.university,
                  label: Text('University'),
                ),
                ButtonSegment(
                  value: AiStudyLevel.professional,
                  label: Text('Professional'),
                ),
              ],
              selected: {prefs.studyLevel},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  onChanged(prefs.copyWith(studyLevel: selection.first)),
            ),
          ),
          const SizedBox(height: 16),
          const _PrefLabel('Language'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final lang in kAiPreferenceLanguages)
                _LanguageChip(
                  label: lang,
                  selected: prefs.language == lang,
                  onTap: () => onChanged(prefs.copyWith(language: lang)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'These preferences shape every StudyFlow answer.',
            style: AppText.small.copyWith(
              color: g.textMuted.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Curated common study languages. The backend accepts any language; these
/// presets keep the picker a clean product surface.
const kAiPreferenceLanguages = [
  'English',
  'Spanish',
  'Hindi',
  'French',
  'German',
  'Arabic',
  'Chinese',
  'Portuguese',
];

class _PrefLabel extends StatelessWidget {
  const _PrefLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppText.eyebrow.copyWith(color: context.glass.textMuted),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? g.primarySoft : g.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? g.primary.withValues(alpha: 0.5) : g.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? g.primary : g.textPrimary,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
