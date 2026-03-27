package com.pluralis.pluralis

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.pluralis.pluralis/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "updateWidget") {
                    val manager = AppWidgetManager.getInstance(this)
                    val ids = manager.getAppWidgetIds(
                        ComponentName(this, ArticleWidgetProvider::class.java)
                    )
                    if (ids.isNotEmpty()) {
                        manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_list)
                    }
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }
}
