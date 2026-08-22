import 'package:flutter/services.dart';

/// Platform channel service that talks to the native Android installer.
class InstallService {
  static const _channel = MethodChannel('ai.studyflow/ota_installer');

  /// Check if the app has permission to install unknown apps.
  Future<bool> canInstallPackages() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'canInstallPackages',
      );
      return result?['canInstall'] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Open the system settings so the user can grant install permission.
  Future<bool> openInstallSettings() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'openInstallSettings',
      );
      return result?['opened'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Install an APK from the given file path.
  Future<bool> installApk(String filePath) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'installApk',
        {'filePath': filePath},
      );
      return result?['launched'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }
}
