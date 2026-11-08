package ch.lukas.timelog

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ClockLogicTest {
    private fun h(hh: Int, mm: Int = 0) = hh * 60 + mm

    @Test
    fun stepsFollowEachOther() {
        var s: DayState? = null
        val order = mutableListOf<Step>()
        for (t in listOf(h(8), h(12), h(13), h(17))) {
            val step = ClockLogic.nextStep(s)!!
            assertEquals(PunchCheck.OK, ClockLogic.check(s, t))
            order += step
            s = ClockLogic.with(s ?: DayState(), step, t)
        }
        assertEquals(listOf(Step.ARRIVAL, Step.LUNCH_START, Step.LUNCH_END, Step.DEPARTURE), order)
        assertNull(ClockLogic.nextStep(s))
        assertEquals(PunchCheck.NOTHING_TO_DO, ClockLogic.check(s, h(18)))
        assertEquals(h(8), ClockLogic.workedMinutes(s, h(23)))
    }

    @Test
    fun doubleTapAndEarlierTimeAreRefused() {
        val s = DayState(arrival = h(8, 5))
        assertEquals(PunchCheck.SAME_MINUTE, ClockLogic.check(s, h(8, 5)))
        assertEquals(PunchCheck.BEFORE_PREVIOUS, ClockLogic.check(s, h(7, 50)))
        assertEquals(PunchCheck.OK, ClockLogic.check(s, h(12)))
    }

    @Test
    fun absences() {
        val vacation = DayState(dayType = "vacation")
        assertNull(ClockLogic.nextStep(vacation))
        assertEquals(PunchCheck.NOTHING_TO_DO, ClockLogic.check(vacation, h(9)))
        // Half day: only arrival and departure.
        val half = DayState(dayType = "vacation", absencePart = "morning", arrival = h(13))
        assertEquals(Step.DEPARTURE, ClockLogic.nextStep(half))
        assertTrue(ClockLogic.isWorking(half))
        assertEquals(h(2), ClockLogic.workedMinutes(half, h(15)))
        // Custom duration (e.g. sick at 10:00): normal four steps.
        assertEquals(Step.LUNCH_START, ClockLogic.nextStep(DayState(dayType = "sick", absencePart = "custom", arrival = h(8))))
    }

    @Test
    fun runningCounter() {
        assertFalse(ClockLogic.isWorking(null))
        val morning = DayState(arrival = h(8))
        assertTrue(ClockLogic.isWorking(morning))
        assertEquals(h(2, 30), ClockLogic.workedMinutes(morning, h(10, 30)))
        val lunch = morning.copy(lunchStart = h(12))
        assertFalse(ClockLogic.isWorking(lunch))
        assertEquals(h(4), ClockLogic.workedMinutes(lunch, h(12, 40)))
        val afternoon = lunch.copy(lunchEnd = h(13))
        assertTrue(ClockLogic.isWorking(afternoon))
        assertEquals(h(5), ClockLogic.workedMinutes(afternoon, h(14)))
        assertEquals("5h 00", ClockLogic.formatDuration(h(5)))
        assertEquals("0h 07", ClockLogic.formatDuration(7))
    }
}
