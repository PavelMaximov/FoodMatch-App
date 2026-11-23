package com.example.food_match

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "foodmatch/session_share")
            .setMethodCallHandler { call, result ->
                if (call.method != "share") {
                    result.notImplemented()
                } else {
                    val text = call.argument<String>("text")
                    val url = call.argument<String>("url")
                    if (text == null || url == null) {
                        result.error("invalid_arguments", "Missing invitation", null)
                    } else {
                        try {
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, "$text\n$url")
                            }
                            startActivity(Intent.createChooser(intent, null))
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("share_unavailable", "Cannot open share sheet", null)
                        }
                    }
                }
            }
    }
}
