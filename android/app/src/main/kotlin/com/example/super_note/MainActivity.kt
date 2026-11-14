package com.example.super_note

import android.net.Uri
import android.os.StatFs
import android.os.SystemClock
import android.view.WindowManager
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterFragmentActivity() {
  private var filesChannel: MethodChannel? = null
  private var pendingSave: MethodChannel.Result? = null
  private var pendingSourcePath: String? = null

  // S-307: SAF picker για αποθήκευση αντιγράφου (χωρίς bytes μέσω channel).
  // Ο κατασκευαστής του contract απαιτεί MIME — το octet-stream επιτρέπει .snb.
  private val createDocumentLauncher =
      registerForActivityResult(
          ActivityResultContracts.CreateDocument("application/octet-stream")) { uri ->
        val result = pendingSave
        val source = pendingSourcePath
        pendingSave = null
        pendingSourcePath = null
        if (result == null) return@registerForActivityResult
        if (uri == null || source == null) {
          // Ακύρωση από τον χρήστη.
          result.success(null)
          return@registerForActivityResult
        }
        copyToUri(source, uri, result)
      }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger, "super_note/security")
        .setMethodCallHandler { call, result ->
      if (call.method == "setSecure") {
        try {
          val secure = call.argument<Boolean>("secure") ?: false
          runOnUiThread {
            if (secure) {
              window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
              window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
          }
          result.success(null)
        } catch (e: Exception) {
          result.error("ERR", e.message, null)
        }
      } else if (call.method == "elapsedRealtime") {
        // S-03: monotonic ρολόι (περιλαμβάνει deep sleep) για persisted lockout.
        try {
          result.success(SystemClock.elapsedRealtime())
        } catch (e: Exception) {
          result.error("ERR", e.message, null)
        }
      } else {
        result.notImplemented()
      }
    }

    // S-307: super_note/files — αποθήκευση + ελεύθερος χώρος.
    val files =
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "super_note/files")
    filesChannel = files
    files.setMethodCallHandler { call, result ->
      when (call.method) {
        "saveDocument" -> {
          try {
            if (pendingSave != null) {
              result.error("BUSY", "Another save is already in progress", null)
              return@setMethodCallHandler
            }
            val sourcePath = call.argument<String>("sourcePath")
            val fileName = call.argument<String>("fileName")
                ?: "super_note_backup.snb"
            if (sourcePath == null) {
              result.error("ARG", "sourcePath missing", null)
              return@setMethodCallHandler
            }
            if (!File(sourcePath).exists()) {
              result.error("ARG", "Source file not found", null)
              return@setMethodCallHandler
            }
            pendingSave = result
            pendingSourcePath = sourcePath
            runOnUiThread {
              try {
                createDocumentLauncher.launch(fileName)
              } catch (e: Exception) {
                pendingSave = null
                pendingSourcePath = null
                result.error("IO", e.message, null)
              }
            }
          } catch (e: Exception) {
            result.error("ERR", e.message, null)
          }
        }
        "freeSpace" -> {
          try {
            val path = call.argument<String>("path") ?: filesDir.absolutePath
            val stat = StatFs(path)
            result.success(stat.availableBytes)
          } catch (e: Exception) {
            result.error("ERR", e.message, null)
          }
        }
        else -> result.notImplemented()
      }
    }
  }

  /// Streaming αντίγραφο σε content Uri (1MB buffer) — ποτέ bytes μέσω channel.
  private fun copyToUri(sourcePath: String, uri: Uri, result: MethodChannel.Result) {
    Thread {
      try {
        val source = File(sourcePath)
        val total = source.length()
        var copied = 0L
        var lastReport = 0L
        source.inputStream().use { input ->
          val output = contentResolver.openOutputStream(uri, "wt")
              ?: throw IOException("openOutputStream returned null")
          output.use { out ->
            val buffer = ByteArray(1 shl 20)
            while (true) {
              val read = input.read(buffer)
              if (read <= 0) break
              out.write(buffer, 0, read)
              copied += read
              if (copied - lastReport >= 256 * 1024) {
                lastReport = copied
                reportCopy(copied, total)
              }
            }
            out.flush()
          }
        }
        reportCopy(copied, total)
        runOnUiThread { result.success(uri.toString()) }
      } catch (e: Exception) {
        runOnUiThread { result.error("IO", e.message, null) }
      }
    }.start()
  }

  private fun reportCopy(done: Long, total: Long) {
    val args = mapOf("done" to done, "total" to total)
    runOnUiThread { filesChannel?.invokeMethod("copyProgress", args) }
  }
}
