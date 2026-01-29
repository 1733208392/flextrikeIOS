package com.flextarget.android.data.local.dao

import androidx.room.*
import com.flextarget.android.data.local.entity.AthleteEntity
import kotlinx.coroutines.flow.Flow
import java.util.UUID

@Dao
interface AthleteDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAthlete(athlete: AthleteEntity)

    @Update
    suspend fun updateAthlete(athlete: AthleteEntity)

    @Delete
    suspend fun deleteAthlete(athlete: AthleteEntity)

    @Query("SELECT * FROM athletes WHERE id = :id")
    suspend fun getAthleteById(id: UUID): AthleteEntity?

    @Query("SELECT * FROM athletes ORDER BY name ASC")
    fun getAllAthletes(): Flow<List<AthleteEntity>>

    @Query("SELECT * FROM athletes WHERE name LIKE '%' || :query || '%' OR club LIKE '%' || :query || '%' ORDER BY name ASC")
    fun searchAthletes(query: String): Flow<List<AthleteEntity>>
}
