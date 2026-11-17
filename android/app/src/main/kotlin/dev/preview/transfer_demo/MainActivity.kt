package dev.preview.transfer_demo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.preview.transfer_demo/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareText") {
                    result.notImplemented()
                } else {
                    val text = call.argument<String>("text")
                    if (text.isNullOrBlank() ||
                        (!text.startsWith("ДЕМО — НЕ ПОДТВЕРЖДАЕТ ОПЛАТУ") &&
                         !text.startsWith("МАКЕТ — НЕ ПОДТВЕРЖДАЕТ ОПЛАТУ") &&
                         !text.startsWith("ПЛАТЁЖ НЕ ВЫПОЛНЯЛСЯ — НЕ ПОДТВЕРЖДАЕТ ОПЛАТУ"))) {
                        result.error("INVALID_DEMO_TEXT", "Expected clearly marked demo receipt text", null)
                    } else {
                        try {
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            startActivity(Intent.createChooser(intent, "Поделиться квитанцией"))
                            result.success(null)
                        } catch (exception: android.content.ActivityNotFoundException) {
                            result.error("SHARE_UNAVAILABLE", "No sharing application available", null)
                        }
                    }
                }
            }
    }
}
