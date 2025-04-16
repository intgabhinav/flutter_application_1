package com.example.garden_helper

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import android.os.Build

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.garden_helper/wifi"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openWifiSettings") {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        // For Android 10 and above, use the WiFi panel
                        val panelIntent = Intent(Settings.Panel.ACTION_WIFI)
                        startActivity(panelIntent)
                        result.success(true)
                    } else {
                        // For older versions, use the WiFi settings
                        val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    }
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "WiFi settings not available", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}