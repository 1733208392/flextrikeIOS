package com.flextarget.android.ui.drills

import com.flextarget.android.data.model.ShotData

/**
 * Utility to calculate timing information for shots
 */
object TimingCalculator {
    /**
     * Calculate absolute timestamps for each shot based on accumulated timeDiff values
     * Returns a list of (shotIndex, absoluteTime) pairs
     */
    fun calculateShotTimestamps(shots: List<ShotData>): List<Pair<Int, Double>> {
        var cumulativeTime = 0.0
        return shots.mapIndexed { index, shot ->
            cumulativeTime += shot.content.actualTimeDiff
            index to cumulativeTime
        }
    }

    /**
     * Calculate total drill duration
     */
    fun calculateTotalDuration(shots: List<ShotData>): Double {
        return shots.fold(0.0) { acc, shot -> acc + shot.content.actualTimeDiff }
    }

    /**
     * Find the most recent shot at or before the given time
     */
    fun findShotAtTime(shots: List<ShotData>, time: Double): Int {
        var cumulativeTime = 0.0
        var lastIndex = 0

        for ((index, shot) in shots.withIndex()) {
            cumulativeTime += shot.content.actualTimeDiff
            if (cumulativeTime <= time) {
                lastIndex = index
            } else {
                break
            }
        }

        return lastIndex
    }

    /**
     * Get cumulative time at a specific shot index
     */
    fun getTimeAtShotIndex(shots: List<ShotData>, shotIndex: Int): Double {
        if (shotIndex < 0 || shotIndex >= shots.size) return 0.0
        return shots.take(shotIndex + 1).fold(0.0) { acc, shot ->
            acc + shot.content.actualTimeDiff
        }
    }

    /**
     * Sort shots by cumulative timestamp to ensure chronological ordering.
     * Ported from iOS approach: shots are sorted by absolute timestamp calculated from timeDiff deltas.
     * 
     * This ensures that when shots are loaded from database or elsewhere, they are displayed
     * in the correct temporal order matching iOS behavior.
     */
    fun sortShotsByTimestamp(shots: List<ShotData>): List<ShotData> {
        if (shots.isEmpty()) return shots
        
        // Create a list of (index, shot, cumulativeTime) tuples
        var cumulativeTime = 0.0
        val shotsWithTime = shots.mapIndexed { index, shot ->
            cumulativeTime += shot.content.actualTimeDiff
            Triple(index, shot, cumulativeTime)
        }
        
        // Sort by cumulative time, then by original index as tiebreaker
        return shotsWithTime
            .sortedWith(compareBy({ it.third }, { it.first }))
            .map { it.second }
    }
}
