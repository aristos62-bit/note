package com.kasem.receive_sharing_intent

import android.content.Context
import android.content.pm.ApplicationInfo
import android.util.Log

/**
 * SuperNote fork (S321): the only native logging gate.
 *
 * S-11 parity: logs are written ONLY for debuggable builds and NEVER contain
 * paths or file names (PII). Release builds stay completely silent.
 */
internal object IntakeLog {

    private const val TAG = "SuperNoteIntake"

    @Volatile
    private var enabled = false

    fun init(context: Context) {
        enabled = (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }

    fun w(message: String, error: Throwable? = null) {
        if (!enabled) return
        if (error == null) {
            Log.w(TAG, message)
        } else {
            Log.w(TAG, "$message (${error.javaClass.simpleName})")
        }
    }
}
