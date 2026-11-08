package ch.lukas.timelog

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Direct access to the app's SQLite database (same file as sqflite: databases/timelog.db). */
class TimeLogDb(private val context: Context) {
    private val file get() = context.getDatabasePath("timelog.db")

    fun exists() = file.exists()

    private fun <T> use(write: Boolean, block: (SQLiteDatabase) -> T): T {
        val db = SQLiteDatabase.openDatabase(
            file.path, null,
            if (write) SQLiteDatabase.OPEN_READWRITE else SQLiteDatabase.OPEN_READONLY,
        )
        try {
            return block(db)
        } finally {
            db.close()
        }
    }

    fun todayKey(date: Date = Date()): String = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).format(date)

    fun readDay(key: String): DayState? = use(false) { db ->
        db.rawQuery(
            "SELECT day_type, absence_part, arrival, lunch_start, lunch_end, departure FROM time_entries WHERE date = ?",
            arrayOf(key),
        ).use { c ->
            if (!c.moveToFirst()) return@use null
            fun int(i: Int): Int? = if (c.isNull(i)) null else c.getInt(i)
            DayState(c.getString(0) ?: "work", c.getString(1) ?: "full", int(2), int(3), int(4), int(5))
        }
    }

    fun setting(key: String): String? = use(false) { db ->
        db.rawQuery("SELECT value FROM settings WHERE key = ?", arrayOf(key)).use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        }
    }

    /** Writes [minutes] in the column of [step] for the day [key] (creates the day if needed). */
    fun punch(key: String, step: Step, minutes: Int) = use(true) { db ->
        val v = ContentValues().apply { put(step.column, minutes) }
        val updated = db.update("time_entries", v, "date = ?", arrayOf(key))
        if (updated == 0) {
            v.put("date", key)
            v.put("day_type", "work")
            db.insertOrThrow("time_entries", null, v)
        }
    }
}
