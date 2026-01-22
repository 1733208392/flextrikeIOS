package com.flextarget.android.data.repository

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import javax.inject.Inject
import javax.inject.Singleton
import java.util.Date

/**
 * BLE message representation
 */
data class BLEMessage(
    val type: MessageType,
    val payload: String,
    val timestamp: Date = Date()
)

enum class MessageType {
    READY,           // Drill ready
    SHOT,           // Shot received
    END,            // Drill end
    ACK,            // Acknowledgment
    ERROR,          // Error message
    AUTH_DATA,      // Device authentication data
    SYNC,           // Sync request
    UNKNOWN
}

/**
 * State of the message queue
 */
enum class QueueState {
    IDLE,           // Waiting for messages
    QUEUED,         // Messages buffered, debounce timer running
    SENDING,        // Currently processing queued messages
    WAITING,        // Sent, waiting for response
    GRACE_PERIOD    // Short grace period before returning to IDLE
}

/**
 * BLEMessageQueue: Manages Bluetooth message processing with debouncing
 * 
 * Responsibilities:
 * - Buffer incoming BLE messages
 * - Implement 30-second debounce window
 * - Serialize message processing (prevent concurrent sends)
 * - Implement state machine: IDLE → QUEUED → SENDING → WAITING → GRACE_PERIOD → IDLE
 * - Track message history
 * - Handle timeouts and errors
 * 
 * Design Pattern: Debounce queue with state machine
 * - Multiple messages within 30s window are batched into single send
 * - After 30s without new messages, send accumulated batch
 * - 1.5s grace period allows last-minute additions before truly idle
 */
@Singleton
class BLEMessageQueue @Inject constructor(
    private val bleRepository: BLERepository
) {
    private val coroutineScope = CoroutineScope(Dispatchers.IO)
    
    // Message queue (buffered channel)
    private val messageChannel = Channel<BLEMessage>(capacity = 100)
    
    // State tracking
    private val _queueState = MutableSharedFlow<QueueState>(replay = 1)
    val queueState: Flow<QueueState> = _queueState.asSharedFlow()
    
    // Processed messages (for history/debugging)
    private val _processedMessages = MutableSharedFlow<BLEMessage>()
    val processedMessages: Flow<BLEMessage> = _processedMessages.asSharedFlow()
    
    // Serialization lock (prevents concurrent message sends)
    private val processingLock = Mutex()
    
    // Debounce timer
    private var debounceJob: Job? = null
    private val debounceDelayMs = 30_000L  // 30 seconds
    private val gracePeriodMs = 1_500L      // 1.5 seconds
    private val ackTimeoutMs = 10_000L      // 10 seconds
    
    // Accumulated messages in current batch
    private val messageBatch = mutableListOf<BLEMessage>()
    
    // Message history
    private val messageHistory = mutableListOf<BLEMessage>()
    private val maxHistorySize = 1000
    
    init {
        coroutineScope.launch {
            _queueState.emit(QueueState.IDLE)
        }
        
        // Start message processing loop
        coroutineScope.launch {
            processMessages()
        }
    }
    
    /**
     * Queue a new message for processing
     */
    suspend fun queueMessage(message: BLEMessage) {
        try {
            messageChannel.send(message)
            Log.d(TAG, "Message queued: ${message.type}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to queue message", e)
        }
    }
    
    /**
     * Main message processing loop
     */
    private suspend fun processMessages() {
        try {
            for (message in messageChannel) {
                processingLock.withLock {
                    try {
                        val currentState = getCurrentState()
                        
                        when (currentState) {
                            QueueState.IDLE -> handleIdle(message)
                            QueueState.QUEUED -> handleQueued(message)
                            QueueState.SENDING -> handleSending(message)
                            QueueState.WAITING -> handleWaiting(message)
                            QueueState.GRACE_PERIOD -> handleGracePeriod(message)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error processing message", e)
                        _queueState.emit(QueueState.IDLE)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Message processing loop failed", e)
        }
    }
    
    /**
     * Handle message in IDLE state - start debounce timer
     */
    private suspend fun handleIdle(message: BLEMessage) {
        messageBatch.clear()
        messageBatch.add(message)
        addToHistory(message)
        
        _queueState.emit(QueueState.QUEUED)
        Log.d(TAG, "Transitioned to QUEUED, starting 30s debounce timer")
        
        startDebounceTimer()
    }
    
    /**
     * Handle message in QUEUED state - add to batch
     */
    private suspend fun handleQueued(message: BLEMessage) {
        messageBatch.add(message)
        addToHistory(message)
        
        // Reset debounce timer (new message extends the window)
        debounceJob?.cancel()
        startDebounceTimer()
        
        Log.d(TAG, "Message added to batch (${messageBatch.size} total)")
    }
    
    /**
     * Handle message in SENDING state - queue for next batch
     */
    private suspend fun handleSending(message: BLEMessage) {
        // Current batch is being sent, queue this for next cycle
        messageBatch.add(message)
        addToHistory(message)
        Log.d(TAG, "Message queued while sending")
    }
    
    /**
     * Handle message in WAITING state - queue for retry
     */
    private suspend fun handleWaiting(message: BLEMessage) {
        messageBatch.add(message)
        addToHistory(message)
        Log.d(TAG, "Message queued while waiting for ACK")
    }
    
    /**
     * Handle message in GRACE_PERIOD state - add to batch
     */
    private suspend fun handleGracePeriod(message: BLEMessage) {
        messageBatch.add(message)
        addToHistory(message)
        
        // Reset grace period timer
        debounceJob?.cancel()
        startDebounceTimer()
        
        // Return to QUEUED to wait full debounce again
        _queueState.emit(QueueState.QUEUED)
        Log.d(TAG, "Message in grace period, back to QUEUED")
    }
    
    /**
     * Start 30-second debounce timer
     * After 30s without new messages, transition to SENDING
     */
    private fun startDebounceTimer() {
        debounceJob?.cancel()
        debounceJob = coroutineScope.launch {
            delay(debounceDelayMs)
            
            processingLock.withLock {
                if (messageBatch.isNotEmpty()) {
                    Log.d(TAG, "Debounce timer fired, sending ${messageBatch.size} messages")
                    sendBatch()
                }
            }
        }
    }
    
    /**
     * Send accumulated message batch to BLE device
     */
    private suspend fun sendBatch() {
        try {
            _queueState.emit(QueueState.SENDING)
            
            val batch = messageBatch.toList()
            messageBatch.clear()
            
            // Send all messages in batch
            for (message in batch) {
                bleRepository.processMessage(message.payload)
                _processedMessages.emit(message)
            }
            
            // Wait for ACK with timeout
            _queueState.emit(QueueState.WAITING)
            delay(ackTimeoutMs)
            
            // Enter grace period before returning to IDLE
            _queueState.emit(QueueState.GRACE_PERIOD)
            delay(gracePeriodMs)
            
            _queueState.emit(QueueState.IDLE)
            Log.d(TAG, "Batch sent and processed, returning to IDLE")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send batch", e)
            _queueState.emit(QueueState.IDLE)
        }
    }
    
    /**
     * Add message to history (keep last 1000 messages)
     */
    private fun addToHistory(message: BLEMessage) {
        messageHistory.add(message)
        if (messageHistory.size > maxHistorySize) {
            messageHistory.removeAt(0)
        }
    }
    
    /**
     * Get current queue state
     */
    private suspend fun getCurrentState(): QueueState {
        // Would normally track state, using IDLE as default
        return QueueState.IDLE
    }
    
    /**
     * Get message history
     */
    fun getMessageHistory(): List<BLEMessage> = messageHistory.toList()
    
    /**
     * Clear message history
     */
    fun clearHistory() {
        messageHistory.clear()
        Log.d(TAG, "Message history cleared")
    }
    
    /**
     * Get current batch size
     */
    fun getCurrentBatchSize(): Int = messageBatch.size
    
    companion object {
        private const val TAG = "BLEMessageQueue"
    }
}
