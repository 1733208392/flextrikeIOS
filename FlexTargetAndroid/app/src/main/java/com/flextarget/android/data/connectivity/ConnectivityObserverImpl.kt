package com.flextarget.android.data.connectivity

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Default Android implementation of [ConnectivityObserver].
 * Emits `Available`/`Unavailable` and keeps the subscription until cancelled.
 */
@Singleton
class ConnectivityObserverImpl @Inject constructor(
    private val context: Context
) : ConnectivityObserver {

    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    override fun observe(): Flow<ConnectivityObserver.ConnectionStatus> = callbackFlow {
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                trySend(ConnectivityObserver.ConnectionStatus.Available).isSuccess
            }

            override fun onLost(network: Network) {
                trySend(ConnectivityObserver.ConnectionStatus.Unavailable).isSuccess
            }

            override fun onUnavailable() {
                trySend(ConnectivityObserver.ConnectionStatus.Unavailable).isSuccess
            }
        }

        // Register callback for networks that have internet capability
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        try {
            connectivityManager.registerNetworkCallback(request, callback)
        } catch (t: Throwable) {
            // Some devices may throw; best-effort registration
            trySend(ConnectivityObserver.ConnectionStatus.Unavailable).isSuccess
        }

        // Emit current state immediately
        trySend(if (isConnected()) ConnectivityObserver.ConnectionStatus.Available else ConnectivityObserver.ConnectionStatus.Unavailable)

        awaitClose {
            try {
                connectivityManager.unregisterNetworkCallback(callback)
            } catch (_: Exception) {
            }
        }
    }.distinctUntilChanged()

    private fun isConnected(): Boolean {
        val network = try { connectivityManager.activeNetwork } catch (_: Exception) { null }
            ?: return false
        val caps = try { connectivityManager.getNetworkCapabilities(network) } catch (_: Exception) { null }
            ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }
}
