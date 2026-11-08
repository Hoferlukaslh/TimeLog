package ch.lukas.timelog

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.SystemClock
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import android.widget.Toast
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Home screen widget to clock in without opening the app. Each tap records the
 * current time for the next step: arrival -> lunch start -> lunch end -> departure.
 */
class ClockWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_PUNCH = "ch.lukas.timelog.PUNCH"

        /** Refreshes every clock widget (called by the app after a change). */
        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, ClockWidgetProvider::class.java))
            if (ids.isNotEmpty()) render(context, mgr, ids)
        }

        private fun nowMinutes(): Int {
            val c = Calendar.getInstance()
            return c.get(Calendar.HOUR_OF_DAY) * 60 + c.get(Calendar.MINUTE)
        }

        /** Context using the language chosen in the app settings (if any). */
        private fun localized(context: Context, lang: String?): Context {
            if (lang.isNullOrEmpty()) return context
            val conf = Configuration(context.resources.configuration)
            conf.setLocale(Locale(lang))
            return context.createConfigurationContext(conf)
        }

        private fun fmtTime(minutes: Int?, use24h: Boolean, locale: Locale): String {
            if (minutes == null) return "--:--"
            val c = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, minutes / 60)
                set(Calendar.MINUTE, minutes % 60)
            }
            val pattern = DateFormat.getBestDateTimePattern(locale, if (use24h) "Hm" else "hm")
            return java.text.SimpleDateFormat(pattern, locale).format(c.time)
        }

        private fun stepLabel(ctx: Context, step: Step) = ctx.getString(
            when (step) {
                Step.ARRIVAL -> R.string.w_arrival
                Step.LUNCH_START -> R.string.w_lunch_start
                Step.LUNCH_END -> R.string.w_lunch_end
                Step.DEPARTURE -> R.string.w_departure
            }
        )

        private fun punchLabel(ctx: Context, step: Step) = ctx.getString(
            when (step) {
                Step.ARRIVAL -> R.string.w_punch_arrival
                Step.LUNCH_START -> R.string.w_punch_lunch_start
                Step.LUNCH_END -> R.string.w_punch_lunch_end
                Step.DEPARTURE -> R.string.w_punch_departure
            }
        )

        private fun absenceLabel(ctx: Context, s: DayState): String {
            val type = ctx.getString(
                when (s.dayType) {
                    "vacation" -> R.string.w_vacation
                    "sick" -> R.string.w_sick
                    "holiday" -> R.string.w_holiday
                    else -> R.string.w_compensation
                }
            )
            return "$type · ${ctx.getString(R.string.w_full_day)}"
        }

        private fun render(context: Context, mgr: AppWidgetManager, ids: IntArray) {
            val db = TimeLogDb(context)
            val views = RemoteViews(context.packageName, R.layout.widget_clock)

            // Tap on the header opens the app.
            val open = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setOnClickPendingIntent(R.id.w_header, open)

            applyAccent(views, null)
            if (!db.exists()) {
                views.setTextViewText(R.id.w_date, context.getString(R.string.app_name))
                views.setViewVisibility(R.id.w_times, View.GONE)
                views.setViewVisibility(R.id.w_worked, View.GONE)
                views.setViewVisibility(R.id.w_chrono, View.GONE)
                views.setTextViewText(R.id.w_button, context.getString(R.string.w_open_app))
                views.setOnClickPendingIntent(R.id.w_button, open)
                mgr.updateAppWidget(ids, views)
                return
            }

            applyAccent(views, db)
            val (state, lang, use24h) = try {
                Triple(
                    db.readDay(db.todayKey()),
                    db.setting("language"),
                    (db.setting("use24h") ?: "true") == "true",
                )
            } catch (e: Exception) {
                // Database not migrated yet: the app has to be opened once.
                views.setTextViewText(R.id.w_button, context.getString(R.string.w_open_app))
                views.setOnClickPendingIntent(R.id.w_button, open)
                mgr.updateAppWidget(ids, views)
                return
            }
            val ctx = localized(context, lang)
            val locale = ctx.resources.configuration.locales[0]
            val now = nowMinutes()

            views.setViewVisibility(R.id.w_times, View.VISIBLE)
            val date = DateFormat.format(DateFormat.getBestDateTimePattern(locale, "EEEdMMM"), Date()).toString()
            views.setTextViewText(R.id.w_date, date.replaceFirstChar { it.titlecase(locale) })

            // The four clock times.
            val s = state ?: DayState()
            val half = ClockLogic.isHalfDay(s)
            val cells = listOf(
                Triple(R.id.w_l1, R.id.w_v1, Step.ARRIVAL),
                Triple(R.id.w_l2, R.id.w_v2, Step.LUNCH_START),
                Triple(R.id.w_l3, R.id.w_v3, Step.LUNCH_END),
                Triple(R.id.w_l4, R.id.w_v4, Step.DEPARTURE),
            )
            val next = ClockLogic.nextStep(state)
            for ((labelId, valueId, step) in cells) {
                views.setTextViewText(labelId, stepLabel(ctx, step))
                val unused = half && (step == Step.LUNCH_START || step == Step.LUNCH_END)
                views.setTextViewText(
                    valueId,
                    if (unused) "—" else fmtTime(ClockLogic.value(s, step), use24h, locale),
                )
                // Highlights the next step.
                views.setTextColor(
                    valueId,
                    if (step == next || ClockLogic.value(s, step) != null) 0xFFFFFFFF.toInt() else 0x80FFFFFF.toInt(),
                )
            }

            // Worked time: live counter while working, fixed text otherwise.
            val worked = ClockLogic.workedMinutes(state, now)
            if (ClockLogic.isWorking(state)) {
                val secs = Calendar.getInstance().get(Calendar.SECOND)
                val base = SystemClock.elapsedRealtime() - (worked * 60L + secs) * 1000L
                views.setChronometer(R.id.w_chrono, base, ctx.getString(R.string.w_worked, "%s"), true)
                views.setViewVisibility(R.id.w_chrono, View.VISIBLE)
                views.setViewVisibility(R.id.w_worked, View.GONE)
            } else {
                views.setChronometer(R.id.w_chrono, SystemClock.elapsedRealtime(), null, false)
                views.setViewVisibility(R.id.w_chrono, View.GONE)
                views.setViewVisibility(R.id.w_worked, View.VISIBLE)
                views.setTextViewText(
                    R.id.w_worked,
                    if (state != null && ClockLogic.isFullAbsence(s)) "" else
                        ctx.getString(R.string.w_worked, ClockLogic.formatDuration(worked)),
                )
            }

            // Main button.
            when {
                state != null && ClockLogic.isFullAbsence(s) -> {
                    views.setTextViewText(R.id.w_button, absenceLabel(ctx, s))
                    views.setOnClickPendingIntent(R.id.w_button, open)
                    views.setInt(R.id.w_button, "setBackgroundResource", R.drawable.widget_button_disabled)
                }
                next == null -> {
                    views.setTextViewText(R.id.w_button, ctx.getString(R.string.w_day_done))
                    views.setOnClickPendingIntent(R.id.w_button, open)
                    views.setInt(R.id.w_button, "setBackgroundResource", R.drawable.widget_button_disabled)
                }
                else -> {
                    views.setTextViewText(R.id.w_button, "⏱  " + punchLabel(ctx, next))
                    val punch = PendingIntent.getBroadcast(
                        context, 1,
                        Intent(context, ClockWidgetProvider::class.java).setAction(ACTION_PUNCH),
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                    )
                    views.setOnClickPendingIntent(R.id.w_button, punch)
                    views.setInt(R.id.w_button, "setBackgroundResource", R.drawable.widget_button)
                }
            }
            mgr.updateAppWidget(ids, views)
            scheduleMidnightRefresh(context)
        }

        /** Default accent colour of the app (logo green). */
        private const val DEFAULT_ACCENT = 0xFF1F6038.toInt()

        /** Background and button text use the accent colour chosen in the app. */
        private fun applyAccent(views: RemoteViews, db: TimeLogDb?) {
            val accent = runCatching { db?.setting("accentColor")?.toLong()?.toInt() }.getOrNull()
                ?: DEFAULT_ACCENT
            val opaque = accent or 0xFF000000.toInt()
            views.setInt(R.id.w_bg, "setColorFilter", opaque)
            views.setTextColor(R.id.w_button, opaque)
        }

        /** The widget must switch to the new day right after midnight. */
        private fun scheduleMidnightRefresh(context: Context) {
            val am = context.getSystemService(AlarmManager::class.java) ?: return
            val c = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 5)
            }
            val pi = PendingIntent.getBroadcast(
                context, 2,
                Intent(context, ClockWidgetProvider::class.java).setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            am.set(AlarmManager.RTC, c.timeInMillis, pi)
        }
    }

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        render(context, mgr, ids)
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_PUNCH -> punch(context)
            AppWidgetManager.ACTION_APPWIDGET_UPDATE,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                if (intent.hasExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)) super.onReceive(context, intent)
                else updateAll(context)
            }
            else -> super.onReceive(context, intent)
        }
    }

    private fun punch(context: Context) {
        val db = TimeLogDb(context)
        if (!db.exists()) return
        val ctx = localized(context, runCatching { db.setting("language") }.getOrNull())
        val use24h = runCatching { db.setting("use24h") }.getOrNull() != "false"
        val locale = ctx.resources.configuration.locales[0]
        try {
            val key = db.todayKey()
            val state = db.readDay(key)
            val now = nowMinutes()
            val msg = when (ClockLogic.check(state, now)) {
                PunchCheck.NOTHING_TO_DO -> null
                PunchCheck.SAME_MINUTE -> ctx.getString(R.string.w_same_minute, fmtTime(now, use24h, locale))
                PunchCheck.BEFORE_PREVIOUS -> ctx.getString(R.string.w_before_previous)
                PunchCheck.OK -> {
                    val step = ClockLogic.nextStep(state)!!
                    db.punch(key, step, now)
                    ctx.getString(R.string.w_punched, stepLabel(ctx, step), fmtTime(now, use24h, locale))
                }
            }
            if (msg != null) Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Toast.makeText(context, ctx.getString(R.string.w_open_app), Toast.LENGTH_LONG).show()
        }
        updateAll(context)
    }
}
