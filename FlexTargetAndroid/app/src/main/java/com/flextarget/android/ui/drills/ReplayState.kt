package com.flextarget.android.ui.drills

/**
 * State for drill replay playback
 */
data class ReplayState(
    val currentProgress: Double = 0.0,  // Current time in seconds
    val isPlaying: Boolean = false,
    val currentShotIndex: Int = 0,
    val totalDuration: Double = 0.0
)
