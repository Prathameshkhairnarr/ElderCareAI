package com.example.eldercare_ai

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.telephony.SmsManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import kotlin.math.sin

class MainActivity: FlutterFragmentActivity() {
    private val SMS_CHANNEL = "com.eldercare/sms"
    private val BATTERY_CHANNEL = "eldercare/battery"
    private var customSiren: SirenPlayer? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // SMS channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "sendSMS") {
                val ph = call.argument<String>("phone")
                val msg = call.argument<String>("message")
                if (ph != null && msg != null) {
                    sendSMS(ph, msg, result)
                } else {
                    result.error("INVALID_ARGS", "Phone or Message is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Battery channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "getBatteryLevel") {
                val level = getBatteryLevel()
                if (level != -1) {
                    result.success(level)
                } else {
                    result.error("UNAVAILABLE", "Battery level not available", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // OEM Auto-Start & Manufacturer detection channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.eldercare.battery").setMethodCallHandler {
            call, result ->
            when (call.method) {
                "getManufacturer" -> {
                    result.success(android.os.Build.MANUFACTURER.lowercase())
                }
                "openAutoStart" -> {
                    try {
                        val pkg = call.argument<String>("package")
                        val cls = call.argument<String>("class")
                        if (pkg != null && cls != null) {
                            val intent = Intent()
                            intent.component = android.content.ComponentName(pkg, cls)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "Package or class is null", null)
                        }
                    } catch (e: Exception) {
                        result.error("LAUNCH_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Focus Mode (App Locking) channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.eldercare/focus").setMethodCallHandler {
            call, result ->
            when (call.method) {
                "startLockTask" -> {
                    try {
                        startLockTask()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_FAILED", e.message, null)
                    }
                }
                "stopLockTask" -> {
                    try {
                        stopLockTask()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNLOCK_FAILED", e.message, null)
                    }
                }
                "playSiren" -> {
                    try {
                        if (customSiren == null) {
                            customSiren = SirenPlayer(applicationContext)
                        }
                        customSiren?.play()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SIREN_FAILED", e.message, null)
                    }
                }
                "stopSiren" -> {
                    try {
                        customSiren?.stop()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SIREN_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getBatteryLevel(): Int {
        val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        return batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    }

    private fun sendSMS(phone: String, message: String, result: MethodChannel.Result) {
        try {
            val smsManager = SmsManager.getDefault()
            val parts = smsManager.divideMessage(message)
            smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
            result.success("Sent")
        } catch (e: Exception) {
            result.error("SEND_FAILED", e.message, null)
        }
    }
}

class SirenPlayer(private val context: Context) {
    private var isPlaying = false
    private var sirenThread: Thread? = null

    fun play() {
        if (isPlaying) return
        isPlaying = true
        sirenThread = Thread {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)

            val sampleRate = 44100
            val bufferSize = AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)
            
            val audioTrack = AudioTrack.Builder()
                .setAudioAttributes(AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build())
                .setAudioFormat(AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build())
                .setBufferSizeInBytes(bufferSize)
                .build()

            audioTrack.play()

            val buffer = ShortArray(bufferSize)
            var angle = 0.0
            var freq = 600.0
            var direction = 1.0

            while (isPlaying) {
                // Force MAX Volume persistently so user cannot lower it during SOS
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVol, 0)

                for (i in 0 until bufferSize) {
                    buffer[i] = (sin(angle) * Short.MAX_VALUE).toInt().toShort()
                    angle += 2.0 * Math.PI * freq / sampleRate
                }
                audioTrack.write(buffer, 0, buffer.size)

                // Modulate frequency to create Wailing Siren effect
                freq += direction * 5.0
                if (freq > 1200.0) direction = -1.0
                if (freq < 600.0) direction = 1.0
            }

            audioTrack.stop()
            audioTrack.release()
        }
        sirenThread?.start()
    }

    fun stop() {
        isPlaying = false
        sirenThread?.join()
    }
}
