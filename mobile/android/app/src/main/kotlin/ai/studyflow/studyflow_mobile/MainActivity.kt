package ai.studyflow.studyflow_mobile

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val CHANNEL = "ai.studyflow/ota_installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handleMethod(call, result) }
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installApk" -> {
                val filePath = call.argument<String>("filePath")
                if (filePath == null || filePath.isEmpty()) {
                    result.error("INVALID_ARGS", "filePath is required", null)
                    return
                }
                installApk(filePath, result)
            }
            "canInstallPackages" -> {
                val canInstall = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    packageManager.canRequestPackageInstalls()
                } else {
                    true
                }
                result.success(mapOf("canInstall" to canInstall, "sdkVersion" to Build.VERSION.SDK_INT))
            }
            "openInstallSettings" -> {
                try {
                    val intent = Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                    intent.data = Uri.parse("package:$packageName")
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(mapOf("opened" to true))
                } catch (e: Exception) {
                    result.error("SETTINGS_FAILED", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun installApk(filePath: String, result: MethodChannel.Result) {
        val apkFile = when {
            filePath.startsWith("/") -> File(filePath)
            else -> File(cacheDir, filePath)
        }

        if (!apkFile.exists()) {
            result.error("FILE_NOT_FOUND", "APK not found: ${apkFile.absolutePath}", null)
            return
        }

        if (!apkFile.name.lowercase().endsWith(".apk")) {
            result.error("NOT_APK", "File is not an APK: ${apkFile.name}", null)
            return
        }

        try {
            val intent = Intent(Intent.ACTION_VIEW)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            val apkUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    apkFile
                ).also {
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
            } else {
                Uri.fromFile(apkFile)
            }

            intent.setDataAndType(apkUri, "application/vnd.android.package-archive")

            if (intent.resolveActivity(packageManager) != null) {
                startActivityForResult(intent, REQUEST_INSTALL)
                result.success(mapOf("launched" to true))
            } else {
                result.error(
                    "NO_INSTALLER",
                    "No app found to install APKs. Grant 'Install unknown apps' permission.",
                    null
                )
            }
        } catch (e: Exception) {
            result.error("INSTALL_FAILED", e.message, null)
        }
    }

    companion object {
        private const val REQUEST_INSTALL = 1001
    }
}
