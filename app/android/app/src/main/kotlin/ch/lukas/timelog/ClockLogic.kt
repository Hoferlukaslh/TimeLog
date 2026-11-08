package ch.lukas.timelog

/** Clock times of one day (minutes after midnight), as stored in `time_entries`. */
data class DayState(
    val dayType: String = "work",
    val absencePart: String = "full",
    val arrival: Int? = null,
    val lunchStart: Int? = null,
    val lunchEnd: Int? = null,
    val departure: Int? = null,
)

/** The four clock steps, in order, with their database column. */
enum class Step(val column: String) {
    ARRIVAL("arrival"),
    LUNCH_START("lunch_start"),
    LUNCH_END("lunch_end"),
    DEPARTURE("departure"),
}

enum class PunchCheck { OK, SAME_MINUTE, BEFORE_PREVIOUS, NOTHING_TO_DO }

/** Pure logic of the clock widget (same rules as the Flutter app). */
object ClockLogic {
    fun isFullAbsence(s: DayState) = s.dayType != "work" && s.absencePart == "full"

    /** Half-day absence: only arrival and departure of the worked half. */
    fun isHalfDay(s: DayState) =
        s.dayType != "work" && (s.absencePart == "morning" || s.absencePart == "afternoon")

    fun steps(s: DayState): List<Step> =
        if (isHalfDay(s)) listOf(Step.ARRIVAL, Step.DEPARTURE) else Step.values().toList()

    fun value(s: DayState, step: Step): Int? = when (step) {
        Step.ARRIVAL -> s.arrival
        Step.LUNCH_START -> s.lunchStart
        Step.LUNCH_END -> s.lunchEnd
        Step.DEPARTURE -> s.departure
    }

    fun with(s: DayState, step: Step, minutes: Int): DayState = when (step) {
        Step.ARRIVAL -> s.copy(arrival = minutes)
        Step.LUNCH_START -> s.copy(lunchStart = minutes)
        Step.LUNCH_END -> s.copy(lunchEnd = minutes)
        Step.DEPARTURE -> s.copy(departure = minutes)
    }

    /** Next step to clock, or null when the day is complete / a whole-day absence. */
    fun nextStep(s: DayState?): Step? {
        if (s == null) return Step.ARRIVAL
        if (isFullAbsence(s)) return null
        return steps(s).firstOrNull { value(s, it) == null }
    }

    private fun times(s: DayState) =
        listOfNotNull(s.arrival, s.lunchStart, s.lunchEnd, s.departure)

    fun check(s: DayState?, now: Int): PunchCheck {
        if (nextStep(s) == null) return PunchCheck.NOTHING_TO_DO
        val t = if (s == null) emptyList() else times(s)
        if (t.any { it > now }) return PunchCheck.BEFORE_PREVIOUS
        // Protects against an accidental double tap.
        if (t.isNotEmpty() && t.max() == now) return PunchCheck.SAME_MINUTE
        return PunchCheck.OK
    }

    /** True while a work period is running (the counter keeps going). */
    fun isWorking(s: DayState?): Boolean {
        if (s == null || s.arrival == null || isFullAbsence(s) || s.departure != null) return false
        if (s.lunchStart == null && s.lunchEnd == null) return true // morning, or no lunch break
        return s.lunchEnd != null // afternoon
    }

    /** Minutes worked so far (the running period counts until [now]). */
    fun workedMinutes(s: DayState?, now: Int): Int {
        if (s == null || isFullAbsence(s)) return 0
        fun span(a: Int?, b: Int?): Int = if (a == null || b == null) 0 else maxOf(0, b - a)
        val end = s.departure ?: now
        if (s.lunchStart == null && s.lunchEnd == null) return span(s.arrival, end)
        val morning = span(s.arrival, s.lunchStart)
        val afternoon = if (s.lunchEnd == null) 0 else span(s.lunchEnd, end)
        return morning + afternoon
    }

    fun formatDuration(minutes: Int) = "${minutes / 60}h ${(minutes % 60).toString().padStart(2, '0')}"
}
