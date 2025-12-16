package com.flextarget.android.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.Date
import java.util.UUID

/**
 * Room entity representing a drill execution result.
 * Migrated from iOS CoreData DrillResult entity.
 * 
 * Relationships:
 * - Many-to-one with DrillSetup (nullable, onDelete = SET NULL)
 * - One-to-many with Shot (cascade delete handled by Shot entity)
 */
@Entity(
    tableName = "drill_result",
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
        Index(value = ["drillId"]),
        Index(value = ["sessionId"]),
        Index(value = ["date"])
    ]
)
data class DrillResultEntity(
    @PrimaryKey
    val id: UUID = UUID.randomUUID(),
    
    val date: Date? = null,
    
    val drillId: UUID? = null,
    
    val sessionId: UUID? = null,
    
    val totalTime: Double = 0.0,
    
    val drillSetupId: UUID? = null
)
