package ch.lukas.timelog

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The app asks the home screen widget to refresh after each change.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ch.lukas.timelog/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "refresh") {
                    ClockWidgetProvider.updateAll(applicationContext)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
