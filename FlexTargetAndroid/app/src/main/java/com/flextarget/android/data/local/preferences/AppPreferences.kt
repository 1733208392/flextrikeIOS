package com.flextarget.android.data.local.preferences

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Encrypted SharedPreferences wrapper for secure token and device auth storage
 */
class AppPreferences(context: Context) {
    
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()
    
    private val sharedPreferences: SharedPreferences = EncryptedSharedPreferences.create(
        context,
        PREFS_FILE_NAME,
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )
    
    // User Token Keys
    suspend fun saveUserToken(
        userUUID: String,
        accessToken: String,
        refreshToken: String,
        mobile: String? = null,
        username: String? = null
    ) = withContext(Dispatchers.IO) {
        sharedPreferences.edit().apply {
            putString(KEY_USER_UUID, userUUID)
            putString(KEY_ACCESS_TOKEN, accessToken)
            putString(KEY_REFRESH_TOKEN, refreshToken)
            if (mobile != null) putString(KEY_MOBILE, mobile)
            if (username != null) putString(KEY_USERNAME, username)
            putLong(KEY_TOKEN_SAVED_TIME, System.currentTimeMillis())
            apply()
        }
    }
    
    suspend fun getUserToken(): UserTokenData? = withContext(Dispatchers.IO) {
        val userUUID = sharedPreferences.getString(KEY_USER_UUID, null) ?: return@withContext null
        val accessToken = sharedPreferences.getString(KEY_ACCESS_TOKEN, null) ?: return@withContext null
        val refreshToken = sharedPreferences.getString(KEY_REFRESH_TOKEN, null) ?: return@withContext null
        
        UserTokenData(
            userUUID = userUUID,
            accessToken = accessToken,
            refreshToken = refreshToken,
            mobile = sharedPreferences.getString(KEY_MOBILE, null),
            username = sharedPreferences.getString(KEY_USERNAME, null)
        )
    }
    
    suspend fun updateAccessToken(accessToken: String) = withContext(Dispatchers.IO) {
        sharedPreferences.edit().apply {
            putString(KEY_ACCESS_TOKEN, accessToken)
            apply()
        }
    }
    
    suspend fun updateTokens(accessToken: String, refreshToken: String) = withContext(Dispatchers.IO) {
        sharedPreferences.edit().apply {
            putString(KEY_ACCESS_TOKEN, accessToken)
            putString(KEY_REFRESH_TOKEN, refreshToken)
            apply()
        }
    }
    
    suspend fun updateUserProfile(username: String) = withContext(Dispatchers.IO) {
        sharedPreferences.edit().apply {
            putString(KEY_USERNAME, username)
            apply()
        }
    }
    
    suspend fun clearUserToken() = withContext(Dispatchers.IO) {
        sharedPreferences.edit().apply {
            remove(KEY_USER_UUID)
            remove(KEY_ACCESS_TOKEN)
            remove(KEY_REFRESH_TOKEN)
            remove(KEY_MOBILE)
            remove(KEY_USERNAME)
            remove(KEY_TOKEN_SAVED_TIME)
            apply()
        }
    }
    
    // Device Token Keys
    suspend fun saveDeviceToken(
        deviceUUID: String,
        deviceToken: String,
        expirationMillis: Long? = null
    ) = withContext(Dispatchers.IO) {
        sharedPreferences.edit().apply {
            putString(KEY_DEVICE_UUID, deviceUUID)
            putString(KEY_DEVICE_TOKEN, deviceToken)
            // Do not persist expiration; server decides token validity. Keep only UUID and token.
            apply()
        }
    }
    
    suspend fun getDeviceToken(): Pair<String?, String?> = withContext(Dispatchers.IO) {
        val deviceUUID = sharedPreferences.getString(KEY_DEVICE_UUID, null)
        val deviceToken = sharedPreferences.getString(KEY_DEVICE_TOKEN, null)
        // Do not check expiration here; server determines validity. Return whatever is persisted.
        Pair(deviceUUID, deviceToken)
    }
    
    suspend fun getDeviceUUID(): String? = withContext(Dispatchers.IO) {
        sharedPreferences.getString(KEY_DEVICE_UUID, null)
    }
    
    suspend fun getDeviceTokenString(): String? = withContext(Dispatchers.IO) {
        sharedPreferences.getString(KEY_DEVICE_TOKEN, null)
    }
    
    suspend fun clearDeviceToken() = withContext(Dispatchers.IO) {
        sharedPreferences.edit().apply {
            remove(KEY_DEVICE_UUID)
            remove(KEY_DEVICE_TOKEN)
            apply()
        }
    }
    
    suspend fun clearAll() = withContext(Dispatchers.IO) {
        sharedPreferences.edit().clear().apply()
    }

    suspend fun saveCompetitionSessionSelection(
        matchId: Int?,
        stageId: Int?,
        squadId: Int?,
        drillId: String?
    ) = withContext(Dispatchers.IO) {
        sharedPreferences.edit().apply {
            if (matchId != null) putInt(KEY_COMPETITION_SESSION_MATCH_ID, matchId) else remove(KEY_COMPETITION_SESSION_MATCH_ID)
            if (stageId != null) putInt(KEY_COMPETITION_SESSION_STAGE_ID, stageId) else remove(KEY_COMPETITION_SESSION_STAGE_ID)
            if (squadId != null) putInt(KEY_COMPETITION_SESSION_SQUAD_ID, squadId) else remove(KEY_COMPETITION_SESSION_SQUAD_ID)
            if (!drillId.isNullOrEmpty()) putString(KEY_COMPETITION_SESSION_DRILL_ID, drillId) else remove(KEY_COMPETITION_SESSION_DRILL_ID)
            apply()
        }
    }

    suspend fun getCompetitionSessionSelection(): CompetitionSessionSelection = withContext(Dispatchers.IO) {
        CompetitionSessionSelection(
            matchId = if (sharedPreferences.contains(KEY_COMPETITION_SESSION_MATCH_ID)) sharedPreferences.getInt(KEY_COMPETITION_SESSION_MATCH_ID, 0) else null,
            stageId = if (sharedPreferences.contains(KEY_COMPETITION_SESSION_STAGE_ID)) sharedPreferences.getInt(KEY_COMPETITION_SESSION_STAGE_ID, 0) else null,
            squadId = if (sharedPreferences.contains(KEY_COMPETITION_SESSION_SQUAD_ID)) sharedPreferences.getInt(KEY_COMPETITION_SESSION_SQUAD_ID, 0) else null,
            drillId = sharedPreferences.getString(KEY_COMPETITION_SESSION_DRILL_ID, null)
        )
    }

    suspend fun clearCompetitionSessionSelection() = withContext(Dispatchers.IO) {
        sharedPreferences.edit().apply {
            remove(KEY_COMPETITION_SESSION_MATCH_ID)
            remove(KEY_COMPETITION_SESSION_STAGE_ID)
            remove(KEY_COMPETITION_SESSION_SQUAD_ID)
            remove(KEY_COMPETITION_SESSION_DRILL_ID)
            apply()
        }
    }
    
    companion object {
        private const val PREFS_FILE_NAME = "flextarget_encrypted_prefs"
        
        // User Token Keys
        private const val KEY_USER_UUID = "user_uuid"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
        private const val KEY_MOBILE = "mobile"
        private const val KEY_USERNAME = "username"
        private const val KEY_TOKEN_SAVED_TIME = "token_saved_time"
        
        // Device Token Keys
        private const val KEY_DEVICE_UUID = "device_uuid"
        private const val KEY_DEVICE_TOKEN = "device_token"

        // Competition Session Selection Keys
        private const val KEY_COMPETITION_SESSION_MATCH_ID = "competition_session_match_id"
        private const val KEY_COMPETITION_SESSION_STAGE_ID = "competition_session_stage_id"
        private const val KEY_COMPETITION_SESSION_SQUAD_ID = "competition_session_squad_id"
        private const val KEY_COMPETITION_SESSION_DRILL_ID = "competition_session_drill_id"
        private const val TAG = "AppPreferences"
    }
}

data class CompetitionSessionSelection(
    val matchId: Int?,
    val stageId: Int?,
    val squadId: Int?,
    val drillId: String?
)

data class UserTokenData(
    val userUUID: String,
    val accessToken: String,
    val refreshToken: String,
    val mobile: String? = null,
    val username: String? = null
)
