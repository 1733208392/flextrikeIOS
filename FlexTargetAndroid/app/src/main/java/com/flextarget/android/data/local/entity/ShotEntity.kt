package com.flextarget.android.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.Date
import java.util.UUID

/**
 * Room entity representing an individual shot within a drill result.
 * Migrated from iOS CoreData Shot entity.
 * 
 * Relationships:
 * - Many-to-one with DrillResult (nullable, onDelete = SET NULL)
 */
@Entity(
    tableName = "shot",
    foreignKeys = [
        ForeignKey(
            entity = DrillResultEntity::class,
            parentColumns = ["id"],
            childColumns = ["drillResultId"],
            onDelete = ForeignKey.SET_NULL
        )
    ],
    indices = [
        Index(value = ["drillResultId"]),
        Index(value = ["timestamp"])
    ]
)
data class ShotEntity(
    @PrimaryKey
    val id: UUID = UUID.randomUUID(),
    
    val data: String? = null,
    
    val timestamp: Date? = null,
    
    val drillResultId: UUID? = null
)
