package com.kasem.receive_sharing_intent

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Parcelable
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.NewIntentListener
import org.json.JSONArray
import org.json.JSONObject
import java.net.URLConnection

// ─────────────────────────────────────────────────────────────────────────────
// SuperNote fork (S321 / E53) of receive_sharing_intent 1.9.0.
//
// Changes vs upstream:
//  * every `content://` is copied through ContentResolver (see FileDirectory),
//  * a record that cannot be resolved is NOT dropped silently: it carries
//    `"error": "unreadable" | "tooLarge"` (path is empty) so Dart can explain it,
//  * `EXTRA_TEXT` is preserved as `"message"` when a stream is also present,
//  * video thumbnail/duration generation was REMOVED: the app never consumes
//    them, they leaked native resources (no release() on failure), blocked the
//    main thread and left orphan PNGs in the cache,
//  * no exception can escape to the main thread.
// ─────────────────────────────────────────────────────────────────────────────

private const val MESSAGES_CHANNEL = "receive_sharing_intent/messages"
private const val EVENTS_CHANNEL_MEDIA = "receive_sharing_intent/events-media"
private const val EVENTS_CHANNEL_TEXT = "receive_sharing_intent/events-text"

class ReceiveSharingIntentPlugin : FlutterPlugin, ActivityAware, MethodCallHandler,
        EventChannel.StreamHandler, NewIntentListener {

    private var initialMedia: JSONArray? = null
    private var latestMedia: JSONArray? = null

    private var eventSinkMedia: EventChannel.EventSink? = null

    private var binding: ActivityPluginBinding? = null
    private lateinit var applicationContext: Context

    private fun setupCallbackChannels(binaryMessenger: BinaryMessenger) {
        val mChannel = MethodChannel(binaryMessenger, MESSAGES_CHANNEL)
        mChannel.setMethodCallHandler(this)

        val eChannelMedia = EventChannel(binaryMessenger, EVENTS_CHANNEL_MEDIA)
        eChannelMedia.setStreamHandler(this)

        val eChannelText = EventChannel(binaryMessenger, EVENTS_CHANNEL_TEXT)
        eChannelText.setStreamHandler(this)
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        IntakeLog.init(applicationContext)
        setupCallbackChannels(binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSinkMedia = events
    }

    override fun onCancel(arguments: Any?) {
        eventSinkMedia = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getInitialMedia" -> result.success(initialMedia?.toString())
            "reset" -> {
                initialMedia = null
                latestMedia = null
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun handleIntent(intent: Intent, initial: Boolean) {
        try {
            when {
                // Sharing or opening media (image, video, text, file)
                intent.type != null && (
                        intent.action == Intent.ACTION_VIEW
                                || intent.action == Intent.ACTION_SEND
                                || intent.action == Intent.ACTION_SEND_MULTIPLE) -> {

                    val value = getMediaUris(intent)
                    if (initial) initialMedia = value
                    latestMedia = value
                    eventSinkMedia?.success(latestMedia?.toString())
                }

                // Opening URL
                intent.action == Intent.ACTION_VIEW -> {
                    val value = JSONArray(
                            listOf(JSONObject()
                                    .put("path", intent.dataString)
                                    .put("type", MediaType.URL.value))
                    )
                    if (initial) initialMedia = value
                    latestMedia = value
                    eventSinkMedia?.success(latestMedia?.toString())
                }
            }
        } catch (e: Exception) {
            // Never let a share intent crash the app (upstream crashed here).
            IntakeLog.w("handleIntent failed", e)
        }
    }

    private fun getMediaUris(intent: Intent?): JSONArray? {
        if (intent == null) return null

        // One budget per intent: SEND_MULTIPLE cannot exceed MAX_TOTAL_BYTES.
        val budget = CopyBudget(FileDirectory.MAX_TOTAL_BYTES)

        return when (intent.action) {
            Intent.ACTION_VIEW -> {
                val uri = intent.data
                toJsonObject(uri, null, intent.type, budget)?.let { JSONArray(listOf(it)) }
            }

            Intent.ACTION_SEND -> {
                val uri = intent.parcelable<Uri>(Intent.EXTRA_STREAM)
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                toJsonObject(uri, text, intent.type, budget)?.let { JSONArray(listOf(it)) }
            }

            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = intent.parcelableArrayList<Uri>(Intent.EXTRA_STREAM)
                val mimeTypes = intent.getStringArrayExtra(Intent.EXTRA_MIME_TYPES)

                uris?.mapIndexedNotNull { index, uri ->
                    toJsonObject(uri, null, mimeTypes?.getOrNull(index), budget)
                }?.let { JSONArray(it) }
            }

            else -> null
        }
    }

    // content can only be uri or string
    private fun toJsonObject(
            uri: Uri?,
            text: String?,
            mimeType: String?,
            budget: CopyBudget): JSONObject? {

        val result = uri?.let { FileDirectory.getAbsolutePath(applicationContext, it, budget) }
        val path = result?.path
        val error = result?.error
        val message = text?.trim()

        // Pure text share (no stream): keep upstream semantics (path = text).
        val isTextOnly = uri == null && error == null
        val pathValue: String? = when {
            path != null -> path
            isTextOnly && !message.isNullOrEmpty() -> message
            else -> null
        }
        if (pathValue == null && error == null) return null

        val resolvedMime = mimeType ?: path?.let { URLConnection.guessContentTypeFromName(it) }
        val type = if (isTextOnly) MediaType.TEXT else MediaType.fromMimeType(resolvedMime)

        val json = JSONObject()
                .put("path", pathValue ?: "")
                .put("type", type.value)
                .put("mimeType", resolvedMime)
        if (error != null) json.put("error", error)
        // Text that accompanied a stream (or a stream that failed) must not be lost.
        if (!message.isNullOrEmpty() && pathValue != message) {
            json.put("message", message)
        }
        return json
    }

    enum class MediaType(val value: String) {
        IMAGE("image"), VIDEO("video"), TEXT("text"), FILE("file"), URL("url");

        companion object {
            fun fromMimeType(mimeType: String?): MediaType {
                return when {
                    mimeType?.startsWith("image") == true -> IMAGE
                    mimeType?.startsWith("video") == true -> VIDEO
                    mimeType?.startsWith("text") == true -> TEXT
                    else -> FILE
                }
            }
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addOnNewIntentListener(this)
        handleIntent(binding.activity.intent, true)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        binding?.removeOnNewIntentListener(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivity() {
        binding?.removeOnNewIntentListener(this)
    }

    override fun onNewIntent(intent: Intent): Boolean {
        handleIntent(intent, false)
        return false
    }

    // A malformed extra (e.g. a String where a Uri is expected) must not crash.
    // NOTE: inline functions cannot touch internal members => no logging here.
    inline fun <reified T : Parcelable> Intent.parcelable(key: String): T? = try {
        when {
            Build.VERSION.SDK_INT >= 33 -> getParcelableExtra(key, T::class.java)
            else -> @Suppress("DEPRECATION") getParcelableExtra(key) as? T
        }
    } catch (e: Exception) {
        null
    }

    inline fun <reified T : Parcelable> Intent.parcelableArrayList(key: String): ArrayList<T>? = try {
        when {
            Build.VERSION.SDK_INT >= 33 -> getParcelableArrayListExtra(key, T::class.java)
            else -> @Suppress("DEPRECATION") getParcelableArrayListExtra(key)
        }
    } catch (e: Exception) {
        null
    }
}
