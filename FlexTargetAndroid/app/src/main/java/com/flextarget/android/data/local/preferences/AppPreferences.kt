package com.flextarget.android.data.local.preferences

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
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
            if (expirationMillis != null) {
                putLong(KEY_DEVICE_TOKEN_EXPIRATION, expirationMillis)
            }
            apply()
        }
    }
    
    suspend fun getDeviceToken(): Pair<String?, String?> = withContext(Dispatchers.IO) {
        val deviceUUID = sharedPreferences.getString(KEY_DEVICE_UUID, null)
        val deviceToken = sharedPreferences.getString(KEY_DEVICE_TOKEN, null)
        
        // Check expiration
        if (deviceToken != null && deviceUUID != null) {
            val expiration = sharedPreferences.getLong(KEY_DEVICE_TOKEN_EXPIRATION, 0)
            if (expiration > 0 && expiration < System.currentTimeMillis()) {
                // Token expired
                clearDeviceToken()
                return@withContext Pair(null, null)
            }
        }
        
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
            remove(KEY_DEVICE_TOKEN_EXPIRATION)
            apply()
        }
    }
    
    suspend fun clearAll() = withContext(Dispatchers.IO) {
        sharedPreferences.edit().clear().apply()
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
        private const val KEY_DEVICE_TOKEN_EXPIRATION = "device_token_expiration"
    }
}

data class UserTokenData(
    val userUUID: String,
    val accessToken: String,
    val refreshToken: String,
    val mobile: String? = null,
    val username: String? = null
)
