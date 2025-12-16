package com.flextarget.android.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.Date
import java.util.UUID

/**
 * Room entity representing a drill setup/configuration.
 * Migrated from iOS CoreData DrillSetup entity.
 */
@Entity(tableName = "drill_setup")
data class DrillSetupEntity(
    @PrimaryKey
    val id: UUID = UUID.randomUUID(),
    
    val name: String? = null,
    
    val desc: String? = null,
    
    val demoVideoURL: String? = null,
    
    val thumbnailURL: String? = null,
    
    val delay: Double = 0.0,
    
    val drillDuration: Double = 5.0,
    
    val repeats: Int = 1,
    
    val pause: Int = 5
)
