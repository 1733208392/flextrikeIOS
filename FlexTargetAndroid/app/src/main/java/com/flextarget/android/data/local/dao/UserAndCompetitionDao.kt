package com.flextarget.android.data.local.dao

import androidx.room.*
import com.flextarget.android.data.local.entity.GamePlayEntity
import com.flextarget.android.data.local.entity.UserEntity
import com.flextarget.android.data.local.entity.CompetitionEntity
import com.flextarget.android.data.local.entity.DrillHistoryEntity
import kotlinx.coroutines.flow.Flow
import java.util.UUID

/**
 * Data Access Object for User entity
 */
@Dao
interface UserDao {
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertUser(user: UserEntity)
    
    @Query("SELECT * FROM users WHERE userUUID = :userUUID")
    suspend fun getUserByUUID(userUUID: String): UserEntity?
    
    @Query("SELECT * FROM users LIMIT 1")
    fun getCurrentUser(): Flow<UserEntity?>
    
    @Query("DELETE FROM users WHERE userUUID = :userUUID")
    suspend fun deleteUserByUUID(userUUID: String)
    
    @Query("DELETE FROM users")
    suspend fun deleteAllUsers()
}

/**
 * Data Access Object for Competition entity
 */
@Dao
interface CompetitionDao {
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCompetition(competition: CompetitionEntity): Long
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCompetitions(competitions: List<CompetitionEntity>)
    
    @Update
    suspend fun updateCompetition(competition: CompetitionEntity)
    
    @Query("SELECT * FROM competitions WHERE id = :id")
    suspend fun getCompetitionById(id: UUID): CompetitionEntity?
    
    @Query("SELECT * FROM competitions ORDER BY date DESC")
    fun getAllCompetitions(): Flow<List<CompetitionEntity>>
    
    @Query("SELECT * FROM competitions WHERE name LIKE '%' || :query || '%' ORDER BY date DESC")
    fun searchCompetitions(query: String): Flow<List<CompetitionEntity>>
    
    @Query("SELECT * FROM competitions WHERE date >= datetime('now') ORDER BY date ASC")
    fun getUpcomingCompetitions(): Flow<List<CompetitionEntity>>
    
    @Query("DELETE FROM competitions WHERE id = :id")
    suspend fun deleteCompetitionById(id: UUID)
}

/**
 * Data Access Object for GamePlay entity
 * Manages game play results that can be submitted to server
 */
@Dao
interface GamePlayDao {
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertGamePlay(gamePlay: GamePlayEntity): Long
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertGamePlays(gamePlays: List<GamePlayEntity>)
    
    @Update
    suspend fun updateGamePlay(gamePlay: GamePlayEntity)
    
    @Query("SELECT * FROM game_plays WHERE id = :id")
    suspend fun getGamePlayById(id: UUID): GamePlayEntity?
    
    @Query("SELECT * FROM game_plays WHERE playUuid = :playUuid")
    suspend fun getGamePlayByPlayUuid(playUuid: String): GamePlayEntity?
    
    @Query("SELECT * FROM game_plays WHERE competitionId = :competitionId ORDER BY playTime DESC")
    fun getGamePlaysByCompetition(competitionId: UUID): Flow<List<GamePlayEntity>>
    
    @Query("SELECT * FROM game_plays WHERE competitionId = :competitionId AND submittedAt IS NOT NULL ORDER BY playTime DESC")
    fun getSubmittedGamePlays(competitionId: UUID): Flow<List<GamePlayEntity>>
    
    @Query("SELECT * FROM game_plays WHERE submittedAt IS NULL ORDER BY createdAt ASC")
    fun getPendingSyncGamePlays(): Flow<List<GamePlayEntity>>
    
    @Query("SELECT COUNT(*) FROM game_plays WHERE competitionId = :competitionId")
    suspend fun getGamePlayCountByCompetition(competitionId: UUID): Int
    
    @Query("SELECT AVG(score) FROM game_plays WHERE competitionId = :competitionId")
    suspend fun getAverageScoreByCompetition(competitionId: UUID): Double?
    
    @Delete
    suspend fun deleteGamePlay(gamePlay: GamePlayEntity)
    
    @Query("DELETE FROM game_plays WHERE id = :id")
    suspend fun deleteGamePlayById(id: UUID)
}

/**
 * Data Access Object for DrillHistory entity
 */
@Dao
interface DrillHistoryDao {
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDrillHistory(history: DrillHistoryEntity): Long
    
    @Update
    suspend fun updateDrillHistory(history: DrillHistoryEntity)
    
    @Query("SELECT * FROM drill_history WHERE drillSetupId = :drillSetupId ORDER BY executedAt DESC")
    fun getDrillHistoryBySetup(drillSetupId: UUID): Flow<List<DrillHistoryEntity>>
    
    @Query("SELECT * FROM drill_history WHERE competitionId = :competitionId ORDER BY executedAt DESC")
    fun getDrillHistoryByCompetition(competitionId: UUID): Flow<List<DrillHistoryEntity>>
    
    @Query("SELECT * FROM drill_history WHERE isSynced = 0")
    fun getUnsyncedHistory(): Flow<List<DrillHistoryEntity>>
    
    @Query("UPDATE drill_history SET isSynced = 1 WHERE id = :id")
    suspend fun markSynced(id: UUID)
    
    @Delete
    suspend fun deleteDrillHistory(history: DrillHistoryEntity)
}
