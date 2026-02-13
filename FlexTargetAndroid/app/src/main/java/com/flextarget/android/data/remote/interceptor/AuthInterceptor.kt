package com.flextarget.android.data.remote.interceptor

import android.util.Log
import com.flextarget.android.data.auth.AuthManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import okhttp3.Interceptor
import okhttp3.Response
import javax.inject.Inject
import javax.inject.Singleton

/**
 * OkHttp Interceptor for automatic logout on 401 responses.
 * 
 * When a 401 Unauthorized is received, triggers user logout.
 */
@Singleton
class AuthInterceptor @Inject constructor(
    private val authManager: AuthManager
) : Interceptor {
    
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        
        val response = chain.proceed(request)
        
        // Handle 401 Unauthorized - trigger logout
        if (response.code == 401) {
            Log.w(TAG, "Received 401 Unauthorized, logging out user")
            CoroutineScope(Dispatchers.IO).launch {
                authManager.logout()
            }
        }
        
        return response
    }
    
    companion object {
        private const val TAG = "AuthInterceptor"
    }
}
