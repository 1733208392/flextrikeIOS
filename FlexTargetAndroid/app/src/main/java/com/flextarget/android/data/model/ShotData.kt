package com.flextarget.android.data.model

import com.google.gson.annotations.SerializedName
import java.util.UUID

/**
 * Data model for shot data received from BLE devices.
 * Ported from iOS ShotData struct.
 */
data class ShotData(
    @SerializedName("target") val target: String? = null,
    @SerializedName("content") val content: Content,
    @SerializedName("type") val type: String? = null,
    @SerializedName("action") val action: String? = null,
    @SerializedName("device") val device: String? = null
)

/**
 * Content of a shot message.
 * Ported from iOS Content struct.
 */
data class Content(
    @SerializedName("command") val command: String,
    @SerializedName("hit_area") val hitArea: String,
    @SerializedName("hit_position") val hitPosition: Position,
    @SerializedName("rotation_angle") val rotationAngle: Double? = null,
    @SerializedName("target_type") val targetType: String,
    @SerializedName("time_diff") val timeDiff: Double,
    @SerializedName("device") val device: String? = null,
    @SerializedName("targetPos") val targetPos: Position? = null,
    @SerializedName("repeat") val `repeat`: Int? = null,

    // New abbreviated format keys for compatibility
    @SerializedName("cmd") val cmd: String? = null,
    @SerializedName("ha") val ha: String? = null,
    @SerializedName("hp") val hp: Position? = null,
    @SerializedName("rot") val rot: Double? = null,
    @SerializedName("tt") val tt: String? = null,
    @SerializedName("td") val td: Double? = null,
    @SerializedName("tgt_pos") val tgtPos: Position? = null,
    @SerializedName("rep") val rep: Int? = null,

    // iOS format keys for compatibility
    @SerializedName("hitArea") val hitAreaIOS: String? = null,
    @SerializedName("timeDiff") val timeDiffIOS: Double? = null,
    @SerializedName("targetType") val targetTypeIOS: String? = null
) {
    // Computed properties to handle both old and new formats
    val actualCommand: String
        get() = cmd ?: command

    val actualHitArea: String
        get() = ha ?: hitAreaIOS ?: hitArea

    val actualHitPosition: Position
        get() = hp ?: hitPosition

    val actualRotationAngle: Double?
        get() = rot ?: rotationAngle

    val actualTargetType: String
        get() = tt ?: targetTypeIOS ?: targetType

    val actualTimeDiff: Double
        get() = td ?: timeDiffIOS ?: timeDiff

    val actualTargetPos: Position?
        get() = tgtPos ?: targetPos

    val actualRepeat: Int?
        get() = rep ?: `repeat`
}

/**
 * Position data for hit location.
 * Ported from iOS Position struct.
 */
data class Position(
    @SerializedName("x") val x: Double,
    @SerializedName("y") val y: Double
)