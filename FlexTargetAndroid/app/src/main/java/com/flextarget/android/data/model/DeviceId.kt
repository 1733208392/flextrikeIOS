package com.flextarget.android.data.model

/**
 * Value object representing a device ID.
 * Enforces non-empty constraint at construction time.
 */
@JvmInline
value class DeviceId(val value: String) {
    init {
        require(value.isNotEmpty()) { "DeviceId cannot be empty" }
    }

    override fun toString(): String = value
}
