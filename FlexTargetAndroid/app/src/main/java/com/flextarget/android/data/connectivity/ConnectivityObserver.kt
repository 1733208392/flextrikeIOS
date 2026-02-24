package com.flextarget.android.data.connectivity

import kotlinx.coroutines.flow.Flow

/**
 * ConnectivityObserver: Single source of truth for network connectivity state.
 */
interface ConnectivityObserver {
    fun observe(): Flow<ConnectionStatus>

    enum class ConnectionStatus {
        Available,
        Unavailable
    }
}
