package com.pluralis.pluralis

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

class ArticleWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ArticleRemoteViewsFactory(applicationContext)
    }
}

private class ArticleRemoteViewsFactory(
    private val context: Context
) : RemoteViewsService.RemoteViewsFactory {

    private data class WidgetArticle(
        val title: String,
        val description: String,
        val link: String,
        val sourceName: String
    )

    private var articles = listOf<WidgetArticle>()

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    override fun onDestroy() {
        articles = emptyList()
    }

    override fun getCount(): Int = articles.size

    override fun getViewAt(position: Int): RemoteViews {
        val article = articles[position]
        val views = RemoteViews(context.packageName, R.layout.widget_item)

        views.setTextViewText(R.id.item_title, article.title)
        views.setTextViewText(R.id.item_source, article.sourceName)
        views.setTextViewText(R.id.item_description, article.description)

        // Fill-in intent for click handling — merged with the template
        val fillInIntent = Intent().apply {
            putExtra(ArticleWidgetProvider.EXTRA_URL, article.link)
        }
        views.setOnClickFillInIntent(R.id.item_root, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    private fun loadData() {
        // Flutter's shared_preferences stores in "FlutterSharedPreferences"
        // with keys prefixed by "flutter."
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )
        val json = prefs.getString("flutter.widget_articles", null) ?: return

        try {
            val arr = JSONArray(json)
            val list = mutableListOf<WidgetArticle>()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                list.add(
                    WidgetArticle(
                        title = obj.optString("title", ""),
                        description = obj.optString("description", ""),
                        link = obj.optString("link", ""),
                        sourceName = obj.optString("sourceName", "")
                    )
                )
            }
            articles = list
        } catch (_: Exception) {
            articles = emptyList()
        }
    }
}
