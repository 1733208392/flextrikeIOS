package com.flextarget.android.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.UUID

/**
 * App authentication entity for storing auth tokens.
 * Migrated from iOS CoreData AppAuth entity.
 */
@Entity(tableName = "app_auth")
data class AppAuthEntity(
    @PrimaryKey
    val id: UUID = UUID.randomUUID(),

    val token: String? = null
)