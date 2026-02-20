package com.flextarget.android.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID
import org.json.JSONArray

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
    
    val drillSetupId: UUID? = null,
    
    val action: String? = null,
    
    val duration: Double = 0.0,
    
    val targetVariant: String? = null
)

/**
 * Parses targetType which can be either a legacy single value ("ipsc")
 * or a JSON array string ("[\"ipsc\",\"hostage\"]")
 */
fun DrillTargetsConfigEntity.parseTargetTypes(): List<String> {
    val raw = targetType?.trim() ?: return emptyList()
    if (raw.isEmpty()) return emptyList()

    return if (raw.startsWith("[")) {
        try {
            val json = JSONArray(raw)
            val parsed = (0 until json.length())
                .mapNotNull { index -> json.optString(index).takeIf { it.isNotBlank() } }
            if (parsed.isEmpty()) {
                println("[DrillTargetsConfigEntity] WARNING: JSON array parsed but resulted in empty list, falling back to single value")
                listOf(raw)
            } else {
                parsed
            }
        } catch (e: Exception) {
            println("[DrillTargetsConfigEntity] ERROR parsing JSON array: ${e.message}, raw='$raw', falling back to single value")
            listOf(raw)
        }
    } else {
        listOf(raw)
    }
}

/**
 * Gets the primary (first) targetType, with optional fallback
 */
fun DrillTargetsConfigEntity.primaryTargetType(default: String = "ipsc"): String {
    return parseTargetTypes().firstOrNull() ?: default
}