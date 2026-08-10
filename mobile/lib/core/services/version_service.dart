import 'package:package_info_plus/package_info_plus.dart';

/// Reads the real app version + build number from the platform package
/// configuration (pubspec / Info.plist / build.gradle) — never
/// hard-coded. Gracefully falls back when the plugin is unavailable
/// (e.g. in widget tests).
class AppVersion {
  const AppVersion({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;

  static Future<AppVersion> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return AppVersion(
        version: info.version.isNotEmpty ? info.version : '0.0.0',
        buildNumber: info.buildNumber.isNotEmpty ? info.buildNumber : '0',
      );
    } catch (_) {
      return const AppVersion(version: '0.0.0', buildNumber: '0');
    }
  }
}
