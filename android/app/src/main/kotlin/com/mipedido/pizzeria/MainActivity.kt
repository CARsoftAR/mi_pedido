package com.mipedido.pizzeria

import android.media.RingtoneManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var currentRingtone: android.media.Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mipedido.pizzeria/sounds").setMethodCallHandler { call, result ->
            when (call.method) {
                "playCustomRingtone" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr != null) {
                        try {
                            currentRingtone?.stop()
                            val uri = Uri.parse(uriStr)
                            currentRingtone = RingtoneManager.getRingtone(applicationContext, uri)
                            currentRingtone?.play()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SOUND_ERROR", e.message, null)
                        }
                    } else {
                        result.error("MISSING_ARG", "URI is null", null)
                    }
                }
                "stopAllSounds" -> {
                    currentRingtone?.stop()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
