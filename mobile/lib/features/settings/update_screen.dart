import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/app_router.dart';
import '../../core/services/ota_service.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';

/// OTA update screen — check, download, and install updates from GitHub.
class UpdateScreen extends ConsumerStatefulWidget {
  const UpdateScreen({super.key});

  @override
  ConsumerState<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends ConsumerState<UpdateScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-check when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(otaProvider.notifier).checkForUpdates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ota = ref.watch(otaProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return SafeArea(
      child: ota.when(
        loading: () => _buildBody(context, fg, mutedFg, isLoading: true),
        error: (e, _) => _buildBody(
          context,
          fg,
          mutedFg,
          error: e.toString(),
        ),
        data: (state) => _buildBody(context, fg, mutedFg, state: state),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Color fg,
    Color mutedFg, {
    OtaState? state,
    bool isLoading = false,
    String? error,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SwissSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          IconButton(
            icon: Icon(Icons.arrow_back, size: 24, color: fg),
            onPressed: () => context.popOrHome(),
          ),
          const SizedBox(height: SwissSpacing.lg),

          // Header
          const SwissEyebrow(text: 'System'),
          const SizedBox(height: SwissSpacing.sm),
          Text(
            'SOFTWARE UPDATE',
            style: SwissTypography.headline.copyWith(color: fg),
          ),

          const SizedBox(height: SwissSpacing.xxxl),
          const SwissDivider(),
          const SizedBox(height: SwissSpacing.xxl),

          // Current version
          const SwissSectionLabel(number: '01', title: 'Current Version'),
          const SizedBox(height: SwissSpacing.md),
          Text(
            'v${state?.currentVersion ?? '...'}',
            style: SwissTypography.subheading.copyWith(color: fg),
          ),

          const SizedBox(height: SwissSpacing.xxl),
          const SwissDivider(),
          const SizedBox(height: SwissSpacing.xxl),

          // Status section
          const SwissSectionLabel(number: '02', title: 'Status'),
          const SizedBox(height: SwissSpacing.md),

          if (isLoading)
            _buildStatusCard(
              fg,
              mutedFg,
              icon: Icons.hourglass_top,
              title: 'CHECKING FOR UPDATES…',
              subtitle: 'Contacting GitHub releases',
            )
          else if (state?.status == OtaStatus.upToDate)
            _buildStatusCard(
              fg,
              mutedFg,
              icon: Icons.check_circle,
              title: 'YOU\'RE UP TO DATE',
              subtitle: 'v${state!.currentVersion} is the latest version',
              iconColor: const Color(0xFF00C853),
            )
          else if (state?.status == OtaStatus.updateAvailable)
            _buildUpdateAvailableCard(context, fg, mutedFg, state!)
          else if (state?.status == OtaStatus.downloading)
            _buildDownloadingCard(fg, mutedFg, state!)
          else if (state?.status == OtaStatus.installing)
            _buildStatusCard(
              fg,
              mutedFg,
              icon: Icons.android,
              title: 'INSTALLING…',
              subtitle: 'The system installer should appear shortly',
            )
          else if (state?.status == OtaStatus.error)
            _buildErrorCard(context, fg, mutedFg, state!.errorMessage ?? error ?? 'Unknown error')
          else
            _buildStatusCard(
              fg,
              mutedFg,
              icon: Icons.system_update,
              title: 'CHECK FOR UPDATES',
              subtitle: 'Tap the button below to check GitHub for a new version',
            ),

          const SizedBox(height: SwissSpacing.xxl),
          const SwissDivider(),
          const SizedBox(height: SwissSpacing.xxl),

          // Action button
          if (state?.status != OtaStatus.downloading &&
              state?.status != OtaStatus.installing)
            _buildActionButton(context, fg, state),

          const SizedBox(height: SwissSpacing.huge),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    Color fg,
    Color mutedFg, {
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(SwissSpacing.xl),
      decoration: BoxDecoration(
        border: Border.all(color: fg, width: SwissShapes.borderMedium),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: iconColor ?? fg),
          const SizedBox(width: SwissSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SwissTypography.label.copyWith(
                    color: fg,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: SwissTypography.caption.copyWith(color: mutedFg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateAvailableCard(
    BuildContext context,
    Color fg,
    Color mutedFg,
    OtaState state,
  ) {
    final release = state.release;
    if (release == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(SwissSpacing.xl),
      decoration: BoxDecoration(
        border: Border.all(
          color: SwissColors.red,
          width: SwissShapes.borderMedium,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.system_update, size: 28, color: SwissColors.red),
              const SizedBox(width: SwissSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UPDATE AVAILABLE',
                      style: SwissTypography.label.copyWith(
                        color: SwissColors.red,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v${release.version}${release.sizeLabel.isNotEmpty ? ' (${release.sizeLabel})' : ''}',
                      style: SwissTypography.caption.copyWith(color: mutedFg),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (release.body.isNotEmpty) ...[
            const SizedBox(height: SwissSpacing.md),
            const SwissHairline(),
            const SizedBox(height: SwissSpacing.md),
            Text(
              'RELEASE NOTES',
              style: SwissTypography.label.copyWith(
                color: mutedFg,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: SwissSpacing.sm),
            Text(
              release.body,
              style: SwissTypography.body.copyWith(
                color: fg,
                height: 1.5,
              ),
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: SwissSpacing.md),
            Text(
              state.errorMessage!,
              style: SwissTypography.caption.copyWith(
                color: SwissColors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadingCard(
    Color fg,
    Color mutedFg,
    OtaState state,
  ) {
    final pct = (state.downloadProgress * 100).toInt();
    return Container(
      padding: const EdgeInsets.all(SwissSpacing.xl),
      decoration: BoxDecoration(
        border: Border.all(color: fg, width: SwissShapes.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SwissColors.red,
                ),
              ),
              const SizedBox(width: SwissSpacing.md),
              Text(
                'DOWNLOADING… $pct%',
                style: SwissTypography.label.copyWith(
                  color: fg,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: SwissSpacing.md),
          SwissProgressBar(value: state.downloadProgress),
          const SizedBox(height: SwissSpacing.sm),
          Text(
            state.release?.sizeLabel ?? '',
            style: SwissTypography.caption.copyWith(color: mutedFg),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(
    BuildContext context,
    Color fg,
    Color mutedFg,
    String message,
  ) {
    return Container(
      padding: const EdgeInsets.all(SwissSpacing.xl),
      decoration: BoxDecoration(
        border: Border.all(
          color: SwissColors.red,
          width: SwissShapes.borderMedium,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 28, color: SwissColors.red),
              const SizedBox(width: SwissSpacing.md),
              Text(
                'UPDATE FAILED',
                style: SwissTypography.label.copyWith(
                  color: SwissColors.red,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: SwissSpacing.md),
          Text(
            message,
            style: SwissTypography.body.copyWith(color: fg),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    Color fg,
    OtaState? state,
  ) {
    final ota = ref.read(otaProvider);

    if (ota.hasValue &&
        (ota.value!.status == OtaStatus.updateAvailable ||
            ota.value!.status == OtaStatus.error)) {
      // Show both "Check Again" and "Install" if update available
      return Column(
        children: [
          if (ota.value!.status == OtaStatus.updateAvailable)
            SizedBox(
              width: double.infinity,
              child: SwissButton(
                label: 'DOWNLOAD & INSTALL',
                onPressed: () {
                  ref.read(otaProvider.notifier).downloadAndInstall();
                },
              ),
            ),
          const SizedBox(height: SwissSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SwissButton(
              label: 'CHECK AGAIN',variant: SwissButtonVariant.ghost,
                onPressed: () {
                  ref.read(otaProvider.notifier).checkForUpdates();
                },
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: SwissButton(
        label: 'CHECK FOR UPDATES',
        onPressed: () {
          ref.read(otaProvider.notifier).checkForUpdates();
        },
      ),
    );
  }
}
