package com.sangamshrestha.jett

import JettApi
import JettFlutterApi
import PlatformFile
import Version
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity(), JettApi {

    private var _initialFiles: MutableList<PlatformFile> = mutableListOf()
    lateinit var flutterApi: JettFlutterApi


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
