package com.example.eldercare_ai

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.telephony.SmsManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val SMS_CHANNEL = "com.eldercare/sms"
    private val BATTERY_CHANNEL = "eldercare/battery"

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
