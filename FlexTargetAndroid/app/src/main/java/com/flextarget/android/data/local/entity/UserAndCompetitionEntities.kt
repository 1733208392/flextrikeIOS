package com.flextarget.android.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.Date
import java.util.UUID

/**
 * User entity for storing authenticated user information
 */
@Entity(tableName = "users")
data class UserEntity(
    @PrimaryKey
    val userUUID: String,
    val mobile: String,
    val username: String? = null,
    val createdAt: Date = Date()
)

/**
 * Competition entity for storing competition/game configurations
 * Migrated from iOS CoreData Competition entity.
 */
@Entity(
    tableName = "competitions",
    foreignKeys = [
        ForeignKey(
            entity = DrillSetupEntity::class,
            parentColumns = ["id"],
            childColumns = ["drillSetupId"],
            onDelete = ForeignKey.SET_NULL
        )
    ],
    indices = [
        Index(value = ["drillSetupId"]),
        Index(value = ["date"])
    ]
)
data class CompetitionEntity(
    @PrimaryKey
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val venue: String? = null,
    val date: Date = Date(),
    val description: String? = null,
    val createdAt: Date = Date(),
    val updatedAt: Date = Date(),
    // Foreign key for drillSetup relationship
    val drillSetupId: UUID? = null
)

/**
 * GamePlay entity for storing individual game play results
 * Tracks results submitted to server for competitions
 */
@Entity(
    tableName = "game_plays",
    indices = [
        androidx.room.Index(value = ["playUuid"], unique = true),
        androidx.room.Index(value = ["competitionId"]),
        androidx.room.Index(value = ["drillSetupId"]),
        androidx.room.Index(value = ["submittedAt"]) // For sync tracking
    ]
)
data class GamePlayEntity(
    @PrimaryKey
    val id: UUID = UUID.randomUUID(),
    val playUuid: String? = null, // Server-assigned UUID after submission
    val competitionId: UUID,
    val drillSetupId: UUID,
    val score: Int,
    val detail: String, // JSON string of shot details
    val playTime: Date,
    val isPublic: Boolean = false,
    val namespace: String = "default",
    val playerMobile: String? = null,
    val playerNickname: String? = null,
    val submittedAt: Date? = null, // Null means not yet submitted
    val createdAt: Date = Date(),
    val updatedAt: Date = Date()
)

/**
 * DrillHistory entity for tracking drill execution history
 */
@Entity(
    tableName = "drill_history",
    indices = [
        androidx.room.Index(value = ["drillSetupId"]),
        androidx.room.Index(value = ["competitionId"]),
        androidx.room.Index(value = ["executedAt"])
    ]
)
data class DrillHistoryEntity(
    @PrimaryKey
    val id: UUID = UUID.randomUUID(),
    val drillSetupId: UUID,
    val competitionId: UUID? = null,
    val executedAt: Date = Date(),
    val totalTime: Double,
    val averageScore: Double? = null,
    val notes: String? = null,
    val isSynced: Boolean = false
)
