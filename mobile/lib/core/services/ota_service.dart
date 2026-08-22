import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'install_service.dart';

/// GitHub owner/repo for checking releases.
const _githubOwner = 'metheyelene';
const _githubRepo = 'studyflow-ai';

/// GitHub Releases API endpoint.
final _releasesUrl =
    'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest';

/// Parsed info about a GitHub release.
class OtaRelease {
  const OtaRelease({
    required this.tagName,
    required this.version,
    required this.body,
    required this.publishedAt,
    required this.apkUrl,
    required this.apkSize,
  });

  final String tagName;
  final String version;
  final String body;
  final String publishedAt;
  final String apkUrl;
  final int apkSize;

  /// Human-readable size, e.g. "12.3 MB".
  String get sizeLabel {
    if (apkSize <= 0) return '';
    final mb = apkSize / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// State of the OTA update process.
enum OtaStatus {
  idle,
  checking,
  updateAvailable,
  downloading,
  installing,
  error,
  upToDate,
}

/// Full OTA state carried by the Riverpod provider.
class OtaState {
  const OtaState({
    this.status = OtaStatus.idle,
    this.release,
    this.currentVersion = '',
    this.downloadProgress = 0.0,
    this.errorMessage,
  });

  final OtaStatus status;
  final OtaRelease? release;
  final String currentVersion;
  final double downloadProgress;
  final String? errorMessage;

  OtaState copyWith({
    OtaStatus? status,
    OtaRelease? release,
    String? currentVersion,
    double? downloadProgress,
    String? errorMessage,
  }) =>
      OtaState(
        status: status ?? this.status,
        release: release ?? this.release,
        currentVersion: currentVersion ?? this.currentVersion,
        downloadProgress: downloadProgress ?? this.downloadProgress,
        errorMessage: errorMessage,
      );
}

/// Manages the full OTA update lifecycle: check → download → install.
class OtaNotifier extends AsyncNotifier<OtaState> {
  final _dio = Dio();
  final _installService = InstallService();

  @override
  Future<OtaState> build() async {
    final info = await PackageInfo.fromPlatform();
    return OtaState(currentVersion: info.version);
  }

  /// Check GitHub for a new release.
  Future<void> checkForUpdates() async {
    state = const AsyncValue.loading();
    state = AsyncData(state.value!.copyWith(status: OtaStatus.checking));

    try {
      final response = await _dio.get(
        _releasesUrl,
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final body = data['body'] as String? ?? '';
      final publishedAt = data['published_at'] as String? ?? '';

      // Find the APK asset
      final assets = (data['assets'] as List?) ?? [];
      String? apkUrl;
      int apkSize = 0;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          apkSize = asset['size'] as int? ?? 0;
          break;
        }
      }

      if (apkUrl == null || tagName.isEmpty) {
        state = AsyncData(
          state.value!.copyWith(
            status: OtaStatus.error,
            errorMessage: 'No APK found in latest release',
          ),
        );
        return;
      }

      // Parse version from tag (strip leading "v")
      final version = tagName.startsWith('v')
          ? tagName.substring(1)
          : tagName;

      final current = state.value!.currentVersion;
      final isNewer = _isNewerVersion(current, version);

      if (!isNewer) {
        state = AsyncData(state.value!.copyWith(status: OtaStatus.upToDate));
        return;
      }

      final release = OtaRelease(
        tagName: tagName,
        version: version,
        body: body,
        publishedAt: publishedAt,
        apkUrl: apkUrl,
        apkSize: apkSize,
      );

      state = AsyncData(
        state.value!.copyWith(
          status: OtaStatus.updateAvailable,
          release: release,
        ),
      );
    } on DioException catch (e) {
      state = AsyncData(
        state.value!.copyWith(
          status: OtaStatus.error,
          errorMessage: 'Network error: ${e.message}',
        ),
      );
    } catch (e) {
      state = AsyncData(
        state.value!.copyWith(
          status: OtaStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Download the APK and install it.
  Future<void> downloadAndInstall() async {
    final release = state.value?.release;
    if (release == null) return;

    state = AsyncData(
      state.value!.copyWith(status: OtaStatus.downloading, downloadProgress: 0),
    );

    try {
      // Ensure updates directory exists
      final cacheDir = await getTemporaryDirectory();
      final updatesDir = Directory('${cacheDir.path}/updates');
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
      }

      final fileName = 'studyflow-${release.tagName}.apk';
      final filePath = '${updatesDir.path}/$fileName';
      final file = File(filePath);

      // Stream download with progress
      await _dio.download(
        release.apkUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            state = AsyncData(
              state.value!.copyWith(downloadProgress: progress),
            );
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          headers: {'Accept': 'application/octet-stream'},
        ),
      );

      // Verify the file was downloaded
      if (!await file.exists() || await file.length() == 0) {
        state = AsyncData(
          state.value!.copyWith(
            status: OtaStatus.error,
            errorMessage: 'Download failed — file is empty',
          ),
        );
        return;
      }

      // Check install permission
      final canInstall = await _installService.canInstallPackages();
      if (!canInstall) {
        await _installService.openInstallSettings();
        state = AsyncData(
          state.value!.copyWith(
            status: OtaStatus.updateAvailable,
            errorMessage:
                'Please grant "Install unknown apps" permission, then tap Install again.',
          ),
        );
        return;
      }

      // Trigger native installer
      state = AsyncData(state.value!.copyWith(status: OtaStatus.installing));
      final launched = await _installService.installApk(filePath);

      if (!launched) {
        state = AsyncData(
          state.value!.copyWith(
            status: OtaStatus.error,
            errorMessage: 'Could not launch the package installer.',
          ),
        );
      }
    } on DioException catch (e) {
      state = AsyncData(
        state.value!.copyWith(
          status: OtaStatus.error,
          errorMessage: 'Download failed: ${e.message}',
        ),
      );
    } catch (e) {
      state = AsyncData(
        state.value!.copyWith(
          status: OtaStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Compare two semver strings. Returns true if `latest` is newer than `current`.
  static bool _isNewerVersion(String current, String latest) {
    final cParts = current.split('.').map(int.tryParse).toList();
    final lParts = latest.split('.').map(int.tryParse).toList();

    final maxLen = cParts.length > lParts.length
        ? cParts.length
        : lParts.length;

    for (var i = 0; i < maxLen; i++) {
      final c = (i < cParts.length ? cParts[i] : 0) ?? 0;
      final l = (i < lParts.length ? lParts[i] : 0) ?? 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }
}

/// Riverpod provider for the OTA update state.
final otaProvider = AsyncNotifierProvider<OtaNotifier, OtaState>(
  OtaNotifier.new,
);
