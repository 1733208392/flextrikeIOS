package com.flextarget.android.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID

/**
 * Room entity representing target configuration for a drill.
 * Migrated from iOS CoreData DrillTargetsConfig entity.
 * 
 * Relationships:
 * - Many-to-one with DrillSetup (nullable, onDelete = SET NULL)
 */
@Entity(
    tableName = "drill_targets_config",
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
        Index(value = ["seqNo"])
    ]
)
data class DrillTargetsConfigEntity(
    @PrimaryKey
    val id: UUID = UUID.randomUUID(),
    
    val seqNo: Int = 0,
    
    val targetName: String? = null,
    
    val targetType: String? = null,
    
    val timeout: Double = 0.0,
    
    val countedShots: Int = 0,
    
    val drillSetupId: UUID? = null
)
