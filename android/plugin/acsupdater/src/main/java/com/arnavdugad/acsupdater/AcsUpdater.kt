package com.arnavdugad.acsupdater

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import java.io.File

/**
 * In-app updater bridge for Arnav Country Simulator.
 * GDScript: Engine.get_singleton("AcsUpdater")
 */
class AcsUpdater(godot: Godot) : GodotPlugin(godot) {

    override fun getPluginName() = "AcsUpdater"

    /** True if the user has allowed this app to install packages ("Install unknown apps"). */
    @UsedByGodot
    fun canRequestInstalls(): Boolean {
        val act = activity ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            act.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    /** Opens the system screen where the user can allow installs from this app. */
    @UsedByGodot
    fun openInstallPermissionSettings(): Boolean {
        val act = activity ?: return false
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + act.packageName))
            } else {
                Intent(Settings.ACTION_SECURITY_SETTINGS)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            act.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.w(TAG, "openInstallPermissionSettings failed", e)
            false
        }
    }

    /**
     * Launches the package installer for an APK stored in the app's files dir
     * (Godot user://). Returns "ok" or an error string.
     */
    @UsedByGodot
    fun installApk(path: String): String {
        val act = activity ?: return "no_activity"
        val file = File(path)
        if (!file.exists()) return "missing_file"
        return try {
            val uri = FileProvider.getUriForFile(act, act.packageName + ".fileprovider", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            act.startActivity(intent)
            "ok"
        } catch (e: Exception) {
            Log.w(TAG, "installApk failed", e)
            "error: " + (e.message ?: e.javaClass.simpleName)
        }
    }

    /**
     * Opens the Android share sheet with an image (stored in the app's files dir,
     * i.e. Godot user://) and a caption. Returns "ok" or an error string.
     */
    @UsedByGodot
    fun shareImage(path: String, text: String): String {
        val act = activity ?: return "no_activity"
        val file = File(path)
        if (!file.exists()) return "missing_file"
        return try {
            val uri = FileProvider.getUriForFile(act, act.packageName + ".fileprovider", file)
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TEXT, text)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val chooser = Intent.createChooser(send, null).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            act.startActivity(chooser)
            "ok"
        } catch (e: Exception) {
            Log.w(TAG, "shareImage failed", e)
            "error: " + (e.message ?: e.javaClass.simpleName)
        }
    }

    /** The installed versionCode (helps the updater avoid offering the same build). */
    @UsedByGodot
    fun getVersionCode(): Long {
        val act = activity ?: return 0L
        return try {
            val info = act.packageManager.getPackageInfo(act.packageName, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else info.versionCode.toLong()
        } catch (e: Exception) {
            0L
        }
    }

    companion object {
        private const val TAG = "AcsUpdater"
    }
}
