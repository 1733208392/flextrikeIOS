package com.flextarget.android.data.model

/**
 * Value object representing a drill target type.
 * Enforces validation at construction time.
 */
@JvmInline
value class TargetType(val value: String) {
    init {
        require(value.isNotEmpty()) { "TargetType cannot be empty" }
        require(!value.startsWith("[")) { "TargetType must be expanded (not JSON array): $value" }
    }

    companion object {
        val VALID_TYPES = setOf(
            "ipsc", "hostage", "popper", "paddle",
            "special_1", "special_2",
            "cqb_front", "cqb_hostage", "cqb_swing",
            "idpa", "idpa_ns", "idpa-back-1", "idpa-back-2",
            "disguised_enemy", "disguised_enemy_surrender"
        )

        fun isValid(type: String): Boolean = VALID_TYPES.contains(type.lowercase())
    }

    override fun toString(): String = value
}
