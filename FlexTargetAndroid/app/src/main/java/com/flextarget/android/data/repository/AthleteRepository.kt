package com.flextarget.android.data.repository

import com.flextarget.android.data.local.dao.AthleteDao
import com.flextarget.android.data.local.entity.AthleteEntity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.withContext
import java.util.UUID
import javax.inject.Singleton

@Singleton
class AthleteRepository(
    private val athleteDao: AthleteDao
) {
    fun getAllAthletes(): Flow<List<AthleteEntity>> = athleteDao.getAllAthletes()

    fun searchAthletes(query: String): Flow<List<AthleteEntity>> = athleteDao.searchAthletes(query)

    suspend fun getAthleteById(id: UUID): AthleteEntity? = withContext(Dispatchers.IO) {
        athleteDao.getAthleteById(id)
    }

    suspend fun insertAthlete(athlete: AthleteEntity) = withContext(Dispatchers.IO) {
        athleteDao.insertAthlete(athlete)
    }

    suspend fun updateAthlete(athlete: AthleteEntity) = withContext(Dispatchers.IO) {
        athleteDao.updateAthlete(athlete)
    }

    suspend fun deleteAthlete(athlete: AthleteEntity) = withContext(Dispatchers.IO) {
        athleteDao.deleteAthlete(athlete)
    }
}
