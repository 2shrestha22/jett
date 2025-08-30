package com.sangamshrestha.jett

import APKInfo
import JettApi
import JettFlutterApi
import PlatformFile
import Version
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.core.content.FileProvider
import androidx.core.graphics.drawable.toBitmap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity(), JettApi {

    private var _initialFiles: MutableList<PlatformFile> = mutableListOf()
    private lateinit var flutterApi: JettFlutterApi


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        JettApi.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        flutterApi = JettFlutterApi(flutterEngine.dartExecutor.binaryMessenger)
    }


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent, true);
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent, false);
    }

    override fun getPlatformVersion(): Version {
        return Version("Android ${android.os.Build.VERSION.RELEASE}")
    }

    override fun getInitialFiles(): List<PlatformFile> {
        val filesToReturn = ArrayList(_initialFiles)
        _initialFiles.clear()
        return filesToReturn
    }

    override fun getAPKs(withSystemApp: Boolean): List<APKInfo> {
        val apps =
            packageManager.getInstalledApplications(PackageManager.MATCH_UNINSTALLED_PACKAGES)

        return apps.mapNotNull { app ->
            val isSystemApp = (app.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val isSplitApk = !app.splitSourceDirs.isNullOrEmpty()


            // only return non split apk
            if ((!isSystemApp || withSystemApp) && !isSplitApk) {
                val drawable = packageManager.getApplicationIcon(app)
                val stream = ByteArrayOutputStream()
                drawable.toBitmap().compress(Bitmap.CompressFormat.PNG, 100, stream)
                val iconBytes = stream.toByteArray()


                val apkFile = File(app.sourceDir)
                val fileName = apkFile.name
                // Convert to content:// URI using FileProvider
                val apkUri = FileProvider.getUriForFile(
                    context, "${applicationContext.packageName}.fileprovider", apkFile
                )

                APKInfo(
                    app.loadLabel(packageManager).toString(),
                    app.packageName,
                    fileName,
                    isSystemApp,
                    isSplitApk,
                    iconBytes,
                    apkUri.toString()
                )
            } else null
        }

    }

    private fun handleIntent(intent: Intent?, isOnCreate: Boolean) {
        if (intent == null || intent.action == null || intent.type == null) {
            return
        }

        when (intent.action) {
            Intent.ACTION_SEND -> {
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let {
                    val files = getFileWithDetails(uris = listOf(it))
                    if (isOnCreate) _initialFiles = ArrayList(files)
                    else flutterApi.onIntent(files) {};
                }
            }

            Intent.ACTION_SEND_MULTIPLE -> {
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let {
                    val files = getFileWithDetails(uris = it);
                    if (isOnCreate) _initialFiles = ArrayList(files)
                    else flutterApi.onIntent(files) {};
                }
            }
        }
    }

    private fun getFileWithDetails(uris: List<Uri>): List<PlatformFile> {
        return uris.map {
            val details = getFileNameAndSizeFromUri(context, it);
            PlatformFile(it.toString(), name = details.first, size = details.second)
        }
    }

}
