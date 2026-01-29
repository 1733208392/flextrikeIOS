package com.flextarget.android.data.local.dao

import androidx.room.*
import com.flextarget.android.data.local.entity.AppAuthEntity
import java.util.UUID

@Dao
interface AppAuthDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAuth(auth: AppAuthEntity)

    @Query("SELECT * FROM app_auth LIMIT 1")
    suspend fun getAuth(): AppAuthEntity?

    @Query("DELETE FROM app_auth")
    suspend fun deleteAuth()
}
