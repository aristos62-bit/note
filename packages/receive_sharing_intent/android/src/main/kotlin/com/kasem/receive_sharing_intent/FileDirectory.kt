package com.kasem.receive_sharing_intent

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.concurrent.atomic.AtomicInteger

// ─────────────────────────────────────────────────────────────────────────────
// SuperNote fork (S321 / E53) of receive_sharing_intent 1.9.0.
//
// WHY: the upstream `content://` path either copied WITHOUT any error handling
// (SecurityException on the main thread => app crash) or returned a raw external
// path that the app cannot read (it holds NO storage permissions, by design).
// Now every `content://` URI is ALWAYS copied into the app cache, with limits,
// a sanitized file name, a per-intent folder and no exception escaping.
//
// Keep in sync with the Dart side:
//   MAX_FILE_BYTES / MAX_TOTAL_BYTES ↔ AppSettings.maxAttachmentCeilingMB /
//                                       ShareLimits.maxTotalBytes (100 MB)
//   INTAKE_DIR_PREFIX               ↔ InboundShare.intakeDirPrefix
//   error codes                     ↔ SharedMediaIntakeError (plugin model)
// ─────────────────────────────────────────────────────────────────────────────

internal const val INTAKE_ERROR_UNREADABLE = "unreadable"
internal const val INTAKE_ERROR_TOO_LARGE = "tooLarge"

/** Remaining byte budget for ONE intent (SEND_MULTIPLE shares it). */
internal class CopyBudget(var remainingBytes: Long)

/** Result of resolving one incoming URI. Never throws. */
internal data class IntakeResult(val path: String?, val error: String?) {
    companion object {
        fun ok(path: String) = IntakeResult(path, null)
        fun fail(error: String) = IntakeResult(null, error)
    }
}

private class TooLargeException : Exception()

object FileDirectory {

    /** Hard per-file ceiling — must match `AppSettings.maxAttachmentCeilingMB`. */
    internal const val MAX_FILE_BYTES = 100L * 1024 * 1024

    /** Hard per-intent total — must match `ShareLimits.maxTotalBytes`. */
    internal const val MAX_TOTAL_BYTES = 100L * 1024 * 1024

    /** Must match `InboundShare.intakeDirPrefix` (Dart cleanup relies on it). */
    internal const val INTAKE_DIR_PREFIX = "intake_"

    private const val CHUNK = 64 * 1024
    private const val MAX_NAME_LENGTH = 100
    private val dirCounter = AtomicInteger(0)

    /**
     * Resolves [uri] to a readable path.
     *
     * `content://` => always copied to `<cacheDir>/intake_<ts>_<n>/<name>`.
     * `file://`    => passthrough (only if the file actually exists).
     * anything else => [INTAKE_ERROR_UNREADABLE].
     */
    internal fun getAbsolutePath(
        context: Context,
        uri: Uri,
        budget: CopyBudget
    ): IntakeResult {
        return try {
            when {
                "file".equals(uri.scheme, ignoreCase = true) -> {
                    val raw = uri.path
                    if (raw.isNullOrEmpty() || !File(raw).isFile) {
                        IntakeResult.fail(INTAKE_ERROR_UNREADABLE)
                    } else {
                        IntakeResult.ok(raw)
                    }
                }
                "content".equals(uri.scheme, ignoreCase = true) ->
                    copyToCache(context, uri, budget)
                else -> IntakeResult.fail(INTAKE_ERROR_UNREADABLE)
            }
        } catch (e: Exception) {
            IntakeLog.w("resolve failed", e)
            IntakeResult.fail(INTAKE_ERROR_UNREADABLE)
        }
    }

    private fun copyToCache(
        context: Context,
        uri: Uri,
        budget: CopyBudget
    ): IntakeResult {
        val resolver = context.contentResolver
        val mimeType = try {
            resolver.getType(uri)
        } catch (e: Exception) {
            IntakeLog.w("getType failed", e)
            null
        }

        val displayName = queryDisplayName(context, uri)
        val fileName = sanitizeName(displayName) ?: fallbackName(mimeType)

        val dir = File(
            context.cacheDir,
            INTAKE_DIR_PREFIX + System.currentTimeMillis() + "_" + dirCounter.incrementAndGet()
        )
        if (!dir.mkdirs() && !dir.isDirectory) {
            IntakeLog.w("cannot create intake dir")
            return IntakeResult.fail(INTAKE_ERROR_UNREADABLE)
        }

        val target = File(dir, fileName)
        val input: InputStream? = try {
            resolver.openInputStream(uri)
        } catch (e: Exception) {
            IntakeLog.w("openInputStream failed", e)
            null
        }
        if (input == null) {
            dir.deleteRecursively()
            return IntakeResult.fail(INTAKE_ERROR_UNREADABLE)
        }

        var written = 0L
        var failure: String? = null
        var output: FileOutputStream? = null
        try {
            output = FileOutputStream(target)
            val buffer = ByteArray(CHUNK)
            while (true) {
                val read = input.read(buffer)
                if (read <= 0) break
                written += read
                if (written > MAX_FILE_BYTES || written > budget.remainingBytes) {
                    throw TooLargeException()
                }
                output.write(buffer, 0, read)
            }
            output.flush()
        } catch (e: TooLargeException) {
            failure = INTAKE_ERROR_TOO_LARGE
            IntakeLog.w("copy aborted: over limit")
        } catch (e: Exception) {
            failure = INTAKE_ERROR_UNREADABLE
            IntakeLog.w("copy failed", e)
        } finally {
            closeQuietly(input)
            closeQuietly(output)
        }

        val failed = failure
        if (failed != null) {
            dir.deleteRecursively()
            return IntakeResult.fail(failed)
        }
        if (written <= 0L) {
            dir.deleteRecursively()
            return IntakeResult.fail(INTAKE_ERROR_UNREADABLE)
        }

        budget.remainingBytes -= written
        return IntakeResult.ok(target.path)
    }

    /** Reads `OpenableColumns.DISPLAY_NAME` — null when the provider refuses. */
    private fun queryDisplayName(context: Context, uri: Uri): String? {
        var cursor: android.database.Cursor? = null
        return try {
            cursor = context.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null
            )
            if (cursor != null && cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) cursor.getString(index) else null
            } else {
                null
            }
        } catch (e: Exception) {
            IntakeLog.w("display name query failed", e)
            null
        } finally {
            try {
                cursor?.close()
            } catch (e: Exception) {
                // ignore
            }
        }
    }

    /**
     * Mirrors `AppStringUtils.sanitizeFileName` (Dart) so the 📎 name the user
     * sees does not change: separators/illegal chars -> `_`, no control chars,
     * no trailing dots/spaces. Also prevents writing OUTSIDE the cache dir.
     */
    private fun sanitizeName(raw: String?): String? {
        val trimmed = raw?.trim().orEmpty()
        if (trimmed.isEmpty()) return null
        var name = trimmed.substringAfterLast('/').substringAfterLast('\\')
        name = name.replace(Regex("[<>:\"/\\\\|?*\\x00-\\x1F\\x7F]"), "_")
        name = name.trimEnd('.', ' ')
        if (name.isEmpty() || name == "." || name == "..") return null
        if (name.length > MAX_NAME_LENGTH) {
            val dot = name.lastIndexOf('.')
            val ext = if (dot > 0) name.substring(dot).take(10) else ""
            val stem = if (dot > 0) name.substring(0, dot) else name
            name = stem.take((MAX_NAME_LENGTH - ext.length).coerceAtLeast(1)) + ext
        }
        return name
    }

    private fun fallbackName(mimeType: String?): String {
        val prefix = when {
            mimeType?.startsWith("image") == true -> "IMG"
            mimeType?.startsWith("video") == true -> "VID"
            else -> "FILE"
        }
        val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType) ?: "bin"
        return "${prefix}_${System.currentTimeMillis()}.$ext"
    }

    private fun closeQuietly(stream: java.io.Closeable?) {
        try {
            stream?.close()
        } catch (e: Exception) {
            // ignore
        }
    }
}
