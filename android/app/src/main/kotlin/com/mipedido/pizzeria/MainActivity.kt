package com.mipedido.pizzeria

import android.content.ClipData
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var currentRingtone: android.media.Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mipedido.pizzeria/sounds")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRingtones" -> {
                        val ringtones = mutableListOf<Map<String, String>>()
                        val manager = RingtoneManager(applicationContext)
                        // Incluir TODO: Notificaciones, Ringtones y Alarmas
                        manager.setType(RingtoneManager.TYPE_ALL)
                        val cursor = manager.cursor
                        while (cursor.moveToNext()) {
                            val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX)
                            val uri = manager.getRingtoneUri(cursor.position).toString()
                            ringtones.add(mapOf("title" to title, "uri" to uri))
                        }
                        result.success(ringtones)
                    }
                    "playCustomRingtone" -> {
                        val uriStr = call.argument<String>("uri")
                        val volume = call.argument<Double>("volume") ?: 1.0
                        if (uriStr != null) {
                            try {
                                currentRingtone?.stop()
                                val uri = Uri.parse(uriStr)
                                
                                // Intentar obtener el ringtone
                                val ringtone = RingtoneManager.getRingtone(applicationContext, uri)
                                
                                if (ringtone != null) {
                                    // Configurar atributos de audio para que suene como ALARMA (prioridad alta)
                                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                                        val aa = android.media.AudioAttributes.Builder()
                                            .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                                            .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                            .build()
                                        ringtone.audioAttributes = aa
                                    } else {
                                        @Suppress("DEPRECATION")
                                        ringtone.streamType = android.media.AudioManager.STREAM_ALARM
                                    }

                                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                                        ringtone.volume = volume.toFloat()
                                    }
                                    
                                    currentRingtone = ringtone
                                    currentRingtone?.play()
                                    result.success(true)
                                } else {
                                    // Fallback manual si getRingtone devuelve null
                                    throw Exception("Ringtone is null")
                                }
                            } catch (e: Exception) {
                                // Fallback al default de ALARMA si falla el URI específico
                                try {
                                    val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                                    currentRingtone = RingtoneManager.getRingtone(applicationContext, defaultUri)
                                    currentRingtone?.play()
                                    result.error("SOUND_ERROR", "Playing default instead of $uriStr: ${e.message}", null)
                                } catch (e2: Exception) {
                                    result.error("CORE_ERROR", e2.message, null)
                                }
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

        // WhatsApp directo: sin chooser; content:// + EXTRA_STREAM + jid (mismo criterio que WA nativo).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mipedido.pizzeria/whatsapp_direct")
            .setMethodCallHandler { call, result ->
                if (call.method != "sendImageToWhatsApp") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val phone = call.argument<String>("phone")?.trim()?.replace(Regex("[^0-9]"), "")
                    val filePath = call.argument<String>("filePath")
                    val text = call.argument<String>("text") ?: ""
                    if (phone.isNullOrEmpty() || filePath.isNullOrEmpty()) {
                        result.error("BAD_ARGS", "phone y filePath son obligatorios", null)
                        return@setMethodCallHandler
                    }
                    val file = File(filePath)
                    if (!file.exists() || !file.canRead()) {
                        result.error("FILE_NOT_FOUND", filePath, null)
                        return@setMethodCallHandler
                    }
                    val authority = "${applicationContext.packageName}.fileprovider"
                    val streamUri = FileProvider.getUriForFile(applicationContext, authority, file)

                    fun buildIntent(pkg: String): Intent {
                        return Intent(Intent.ACTION_SEND).apply {
                            setPackage(pkg)
                            type = "image/jpeg"
                            putExtra(Intent.EXTRA_STREAM, streamUri)
                            putExtra("jid", "$phone@s.whatsapp.net")
                            if (text.isNotEmpty()) {
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            clipData = ClipData.newRawUri("", streamUri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                    }

                    val pkgs = listOf("com.whatsapp", "com.whatsapp.w4b")
                    var launched = false
                    for (pkg in pkgs) {
                        val intent = buildIntent(pkg)
                        if (intent.resolveActivity(packageManager) != null) {
                            startActivity(intent)
                            launched = true
                            break
                        }
                    }
                    if (launched) {
                        result.success(true)
                    } else {
                        result.error("NO_WHATSAPP", "WhatsApp no instalado o no visible", null)
                    }
                } catch (e: Exception) {
                    result.error("WHATSAPP_SEND", e.message, null)
                }
            }
    }
}
