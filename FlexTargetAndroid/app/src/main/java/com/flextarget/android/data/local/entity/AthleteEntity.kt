package com.flextarget.android.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.Date
import java.util.UUID

/**
 * Athlete entity for storing user profiles.
 * Migrated from iOS CoreData Athlete entity.
 */
@Entity(tableName = "athletes")
data class AthleteEntity(
    @PrimaryKey
    val id: UUID = UUID.randomUUID(),

    val name: String? = null,

    val club: String? = null,

    val avatarData: ByteArray? = null,

    val createdAt: Date = Date(),

    val updatedAt: Date = Date()
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as AthleteEntity

        if (id != other.id) return false
        if (name != other.name) return false
        if (club != other.club) return false
        if (avatarData != null) {
            if (other.avatarData == null) return false
            if (!avatarData.contentEquals(other.avatarData)) return false
        } else if (other.avatarData != null) return false
        if (createdAt != other.createdAt) return false
        if (updatedAt != other.updatedAt) return false

        return true
    }

    override fun hashCode(): Int {
        var result = id.hashCode()
        result = 31 * result + (name?.hashCode() ?: 0)
        result = 31 * result + (club?.hashCode() ?: 0)
        result = 31 * result + (avatarData?.contentHashCode() ?: 0)
        result = 31 * result + createdAt.hashCode()
        result = 31 * result + updatedAt.hashCode()
        return result
    }
}