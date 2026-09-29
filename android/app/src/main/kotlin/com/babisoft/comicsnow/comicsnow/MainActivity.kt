package com.babisoft.comicsnow.comicsnow

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * Adds "Apri con" support: the manifest declares the comic formats, and this
 * activity takes over the incoming file.
 *
 * The file arrives as a `content://` URI (or a `file://` one), which the app may
 * only read while the grant lasts, and which Dart cannot open as a path. It is
 * therefore copied into the app cache first; the archive reader moves that copy
 * into its own storage, so nothing is left behind.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /** Set by Dart once its handler is installed; before that paths queue up. */
    private var ready = false
    private val pending = mutableListOf<String>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "ready" -> {
                        ready = true
                        result.success(null)
                    }
                    "takePending" -> {
                        val paths = pending.toList()
                        pending.clear()
                        result.success(paths)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Cold start: the app was launched by "Apri con".
        handleIncoming(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Warm start: the app was already open (singleTop).
        handleIncoming(intent)
    }

    private fun handleIncoming(intent: Intent?) {
        val uri = incomingUri(intent) ?: return
        val path = copyIntoInbox(uri) ?: return
        Log.i(TAG, "apri con: $uri -> $path")

        if (ready) {
            channel?.invokeMethod("open", path)
        } else {
            pending.add(path)
        }
    }

    private fun incomingUri(intent: Intent?): Uri? = when (intent?.action) {
        Intent.ACTION_VIEW -> intent.data
        Intent.ACTION_SEND -> streamFrom(intent)
        else -> null
    }

    private fun streamFrom(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    private fun copyIntoInbox(uri: Uri): String? = try {
        val inbox = File(cacheDir, "inbox").apply { mkdirs() }
        val target = File(inbox, displayName(uri))

        val source = if (uri.scheme == "file") {
            uri.path?.let { File(it).inputStream() }
        } else {
            contentResolver.openInputStream(uri)
        }

        if (source == null) {
            null
        } else {
            source.use { input -> FileOutputStream(target).use { input.copyTo(it, BUFFER_SIZE) } }
            target.absolutePath
        }
    } catch (error: Exception) {
        Log.w(TAG, "impossibile leggere $uri: $error")
        null
    }

    /** Real file name when the provider exposes one, a sane fallback otherwise. */
    private fun displayName(uri: Uri): String {
        val fromProvider = if (uri.scheme == "content") {
            try {
                contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
                }
            } catch (_: Exception) {
                null
            }
        } else {
            null
        }

        val name = fromProvider ?: uri.lastPathSegment?.substringAfterLast('/') ?: "comic"
        val safe = name.replace(Regex("[^A-Za-z0-9._-]"), "_").take(120)
        return if (safe.isEmpty() || safe.startsWith(".")) "comic_$safe" else safe
    }

    private companion object {
        const val CHANNEL = "comicsnow/open_with"
        const val TAG = "ComicsNow"
        const val BUFFER_SIZE = 1 shl 16
    }
}
