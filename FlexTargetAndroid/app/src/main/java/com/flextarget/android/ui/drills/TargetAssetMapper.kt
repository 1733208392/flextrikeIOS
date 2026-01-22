package com.flextarget.android.ui.drills

/**
 * Maps target types to live target image asset names
 * Assets are located in assets/ folder and referenced with .png extension
 */
object TargetAssetMapper {
    fun getTargetImageAssetName(targetType: String): String {
        return when (targetType.lowercase()) {
            "ipsc" -> "ipsc.live.target.png"
            "hostage" -> "hostage.live.target.png"
            "popper" -> "popper.live.target.png"
            "paddle" -> "paddle.live.target.png"
            "special_1" -> "ipsc.special.1.live.target.png"
            "special_2" -> "ipsc.special.2.live.target.png"
            "rotation" -> "rotation.live.target.png"
            "cqb_front" -> "cqb_front.live.target.png"
            "cqb_hostage" -> "cqb_hostage.live.target.png"
            "cqb_move" -> "cqb_move.live.target.png"
            "cqb_swing" -> "cqb_swing.live.target.png"
            "idpa" -> "idpa.live.target.png"
            "disguised_enemy" -> "disguised_enemy.live.target.png"
            else -> "ipsc.live.target.png" // Default fallback
        }
    }
}
