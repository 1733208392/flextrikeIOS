package com.flextarget.android.data.local.entity

import androidx.room.Embedded
import androidx.room.Relation

/**
 * Relationship data class representing a DrillSetup with its associated targets.
 * Mirrors the one-to-many relationship from iOS CoreData.
 */
data class DrillSetupWithTargets(
    @Embedded val drillSetup: DrillSetupEntity,
    
    @Relation(
        parentColumn = "id",
        entityColumn = "drillSetupId"
    )
    val targets: List<DrillTargetsConfigEntity>
)

/**
 * Relationship data class representing a DrillSetup with its execution results.
 * Mirrors the one-to-many relationship from iOS CoreData.
 */
data class DrillSetupWithResults(
    @Embedded val drillSetup: DrillSetupEntity,
    
    @Relation(
        parentColumn = "id",
        entityColumn = "drillSetupId"
    )
    val results: List<DrillResultEntity>
)

/**
 * Relationship data class representing a DrillResult with its shots.
 * Mirrors the one-to-many relationship from iOS CoreData.
 */
data class DrillResultWithShots(
    @Embedded val drillResult: DrillResultEntity,
    
    @Relation(
        parentColumn = "id",
        entityColumn = "drillResultId"
    )
    val shots: List<ShotEntity>
)

/**
 * Complete drill setup data including targets and results with shots.
 */
data class CompleteDrillSetup(
    @Embedded val drillSetup: DrillSetupEntity,
    
    @Relation(
        parentColumn = "id",
        entityColumn = "drillSetupId"
    )
    val targets: List<DrillTargetsConfigEntity>,
    
    @Relation(
        entity = DrillResultEntity::class,
        parentColumn = "id",
        entityColumn = "drillSetupId"
    )
    val results: List<DrillResultWithShots>
)
