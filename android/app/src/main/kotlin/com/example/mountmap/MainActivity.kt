package com.example.mountmap

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.example.mountmap/shared_file"
    private var sharedFilePath: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getSharedFile") {
                val path = sharedFilePath
                sharedFilePath = null
                result.success(path)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action

        var uri: Uri? = null

        if (Intent.ACTION_VIEW == action) {
            uri = intent.data
        } else if (Intent.ACTION_SEND == action) {
            uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        }

        if (uri != null) {
            val localPath = copyUriToTempFile(uri)
            if (localPath != null) {
                sharedFilePath = localPath
                methodChannel?.invokeMethod("onFileShared", localPath)
            }
        }
    }

    private fun copyUriToTempFile(uri: Uri): String? {
        return try {
            val contentResolver = applicationContext.contentResolver
            var fileName = "shared_import.mountpack"

            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                    if (nameIndex != -1) {
                        val name = cursor.getString(nameIndex)
                        if (!name.isNullOrEmpty()) {
                            fileName = name
                        }
                    }
                }
            }

            val tempFile = File(cacheDir, "import_$fileName")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(tempFile).use { output ->
                    input.copyTo(output)
                }
            }
            tempFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
