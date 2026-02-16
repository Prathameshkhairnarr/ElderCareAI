package com.example.eldercare_ai

import android.telephony.SmsManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.eldercare/sms"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
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
