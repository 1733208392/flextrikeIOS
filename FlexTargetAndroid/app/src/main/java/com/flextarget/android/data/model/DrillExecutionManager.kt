package com.flextarget.android.data.model

import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.gson.Gson
import java.util.*
import java.util.Timer
import java.util.Date
import java.util.TimerTask
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
import com.flextarget.android.data.ble.AndroidBLEManager

/**
 * Drill Execution Manager for Android - ported from iOS DrillExecutionManager
 * Handles all BLE message interactions with targets and manages drill execution state
 */
class DrillExecutionManager(
    private val bleManager: AndroidBLEManager,
    private val drillSetup: DrillSetupEntity,
    private val targets: List<DrillTargetsConfigEntity>,
    private val expectedDevices: List<String>,
    private val onComplete: (List<DrillRepeatSummary>) -> Unit,
    private val onFailure: () -> Unit,
    private val onReadinessUpdate: (Int, Int) -> Unit = { _, _ -> },
    private val onReadinessTimeout: (List<String>) -> Unit = { _ -> },
    private val onRepeatComplete: ((Int, Int) -> Unit)? = null
) {
    private var randomDelay: Double = 0.0
    private var totalRepeats: Int = 1

    private var currentRepeat = 0
    private var ackedDevices = mutableSetOf<String>()
    private var ackTimeoutTimer: Timer? = null
    private var waitingForAcks = false
    private var repeatSummaries = mutableListOf<DrillRepeatSummary>()
    private var currentRepeatShots = mutableListOf<ShotEvent>()
    private var currentRepeatStartTime: Date? = null
    private var startCommandTime: Date? = null
    private var beepTime: Date? = null
    private var endCommandTime: Date? = null
    private var shotObserver: Any? = null
    private var deviceDelayTimes = mutableMapOf<String, String>()
    private var globalDelayTime: String? = null
    private var firstTargetName: String? = null
    private var lastTargetName: String? = null
    private var isWaitingForEnd = false
    private var pauseTimer: Timer? = null
    private var gracePeriodTimer: Timer? = null
    private var isStopped = false
    private var drillDuration: Double? = null
    private var isReadinessCheckOnly = false

    val summaries: List<DrillRepeatSummary>
        get() = repeatSummaries

    init {
        startObservingShots()
    }

    /// Call this when all repeats are completed to finalize the drill
    fun completeDrill() {
        stopObservingShots()
        onComplete(repeatSummaries)
    }

    fun performReadinessCheck() {
        isReadinessCheckOnly = true
        sendReadyCommands()
        beginWaitingForAcks()
    }

    fun startExecution() {
        isStopped = false
        // Assumes currentRepeat is already set by UI before calling
        // Ready command was already sent in performReadinessCheck()
        // Send start command and begin waiting for shots
        sendStartCommands()
        beginWaitingForEnd()
    }

    fun setCurrentRepeat(repeat: Int) {
        this.currentRepeat = repeat
    }

    fun setRandomDelay(delay: Double) {
        this.randomDelay = delay
    }

    fun setBeepTime(time: Date) {
        this.beepTime = time
    }

    fun stopExecution() {
        isStopped = true
        ackTimeoutTimer?.cancel()
        pauseTimer?.cancel()
        gracePeriodTimer?.cancel()
        stopObservingShots()
    }

    fun manualStopRepeat() {
        isStopped = true
        ackTimeoutTimer?.cancel()
        pauseTimer?.cancel()
        isWaitingForEnd = false
        endCommandTime = Date()
        sendEndCommand()

        // Start grace period to collect in-flight shots before finalizing
        // Keep shot observer active during this period
        gracePeriodTimer?.cancel()
        gracePeriodTimer = Timer().apply {
            schedule(object : TimerTask() {
                override fun run() {
                    completeManualStopRepeat()
                }
            }, 3000)
        }
    }

    private fun completeManualStopRepeat() {
        gracePeriodTimer?.cancel()
        gracePeriodTimer = null
        // DO NOT stop observing shots here - let them continue arriving during grace period
        // stopObservingShots() will be called when stopping execution or leaving the view
        val repeatIndex = currentRepeat
        finalizeRepeat(repeatIndex)
        // NOTE: Do NOT call onComplete here - UI manages the next repeat or drill completion
    }

    private fun sendReadyCommands() {
        if (!bleManager.isConnected) {
            println("BLE not connected")
            onFailure()
            return
        }

        // Clear state from previous repeat before starting new readiness check
        currentRepeatStartTime = null
        beepTime = null

        val sortedTargets = targets.sortedBy { it.seqNo }

        for ((index, target) in sortedTargets.withIndex()) {
            val delayValue = if (randomDelay > 0) randomDelay else drillSetup.delay
            val roundedDelay = String.format("%.2f", delayValue).toDouble()

            val content = mapOf(
                "command" to "ready",
                "delay" to roundedDelay,
                "targetType" to (target.targetType ?: ""),
                "timeout" to 300,
                "countedShots" to target.countedShots,
                "repeat" to currentRepeat,
                "isFirst" to (index == 0),
                "isLast" to (index == sortedTargets.size - 1)
            )

            val message = mapOf(
                "action" to "netlink_forward",
                "dest" to (target.targetName ?: ""),
                "content" to content
            )

            val messageData = Gson().toJson(message)
            println("Sending ready message for target ${target.targetName}, length: ${messageData.length}")
            bleManager.writeJSON(messageData)

            // TODO: Add simulator mock logic if needed
        }
    }

    private fun beginWaitingForAcks() {
        if (!bleManager.isConnected) {
            onFailure()
            return
        }

        // Reset tracking
        ackedDevices.clear()
        deviceDelayTimes.clear()
        globalDelayTime = null
        waitingForAcks = true

        // Start 10s guard timer
        ackTimeoutTimer?.cancel()
        ackTimeoutTimer = Timer().apply {
            schedule(object : TimerTask() {
                override fun run() {
                    handleAckTimeout()
                }
            }, 10000)
        }

        // If no expected devices, proceed immediately
        if (expectedDevices.isEmpty()) {
            finishWaitingForAcks(success = true)
        }
    }

    private fun handleAckTimeout() {
        println("Ack timeout for repeat $currentRepeat")
        val nonResponsiveTargets = expectedDevices.filter { !ackedDevices.contains(it) }
        println("Non-responsive targets: $nonResponsiveTargets")
        Handler(Looper.getMainLooper()).post {
            onReadinessTimeout(nonResponsiveTargets)
        }
        finishWaitingForAcks(success = false)
    }

    fun handleNetlinkForward(json: Map<String, Any>) {
        val device = json["device"] as? String ?: return

        // Content may be a string or object; normalize and detect "ready"
        var didAck = false
        var didEnd = false

        val contentObj = json["content"] as? Map<String, Any>
        if (contentObj != null) {
            if ((contentObj["ack"] as? String) == "ready") {
                didAck = true
            }
            if ((contentObj["ack"] as? String) == "end") {
                didEnd = true
            }

            // Extract delay_time if present and we have an ack
            if (didAck) {
                val delayTime = contentObj["delay_time"]
                if (delayTime != null) {
                    val delayTimeStr = delayTime.toString()
                    deviceDelayTimes[device] = delayTimeStr
                    if (globalDelayTime == null && delayTimeStr != "0") {
                        globalDelayTime = delayTimeStr
                    }
                }
            }

            if (didAck) {
                if (!waitingForAcks) return
                ackedDevices.add(device)
                println("Device ack received: $device")

                // Update readiness status
                Handler(Looper.getMainLooper()).post {
                    onReadinessUpdate(ackedDevices.size, expectedDevices.size)
                }

                // Check if all expected devices have acked
                if (ackedDevices.size >= expectedDevices.size) {
                    finishWaitingForAcks(success = true)
                }
            }

            if (didEnd) {
                if (!isWaitingForEnd) return
                // Extract drill_duration if present
                val duration = contentObj["drill_duration"] as? Double
                if (duration != null) {
                    drillDuration = duration
                    println("Drill duration received: $duration")
                }
                // Only process end message from the last target
                if (device == lastTargetName) {
                    println("Last device end received: $device")
                    endCommandTime = Date()  // Record when end command is received
                    sendEndCommand()
                    completeRepeat()
                }
            }
        }
    }

    private fun finishWaitingForAcks(success: Boolean) {
        waitingForAcks = false
        ackTimeoutTimer?.cancel()
        ackTimeoutTimer = null

        if (success) {
            if (isReadinessCheckOnly) {
                // Just completed readiness check, don't proceed to execution
                isReadinessCheckOnly = false
                return
            }

            // Readiness check passed, UI will call startExecution() when ready
            println("Ready check completed, waiting for UI to start execution")
        } else {
            // Ack timeout - for readiness check, this is handled by the timeout callback
            if (!isReadinessCheckOnly) {
                stopObservingShots()
                onFailure()
            }
        }
    }

    private fun sendStartCommands() {
        if (!bleManager.isConnected) {
            println("[DrillExecutionManager] startExecution() - BLE not connected")
            onFailure()
            return
        }

        prepareForRepeatStart()
        startCommandTime = Date()  // Record when start command is sent

        val content = mutableMapOf<String, Any>(
            "command" to "start"
        )
        globalDelayTime?.let { content["delay_time"] = it }

        val message = mapOf(
            "action" to "netlink_forward",
            "dest" to "all",
            "content" to content
        )

        val jsonString = Gson().toJson(message)
        println("Sending start command to all devices: $jsonString")
        bleManager.writeJSON(jsonString)
    }

    private fun sendEndCommand() {
        if (!bleManager.isConnected) {
            println("BLE not connected - cannot send end command")
            return
        }

        val content = mapOf(
            "command" to "end"
        )
        val message = mapOf(
            "action" to "netlink_forward",
            "dest" to "all",
            "content" to content
        )

        val jsonString = Gson().toJson(message)
        println("Sending end command to all devices: $jsonString")
        bleManager.writeJSON(jsonString)
    }

    private fun beginWaitingForEnd() {
        if (!bleManager.isConnected) {
            println("[DrillExecutionManager] beginWaitingForEnd() - BLE not connected")
            onFailure()
            return
        }

        println("[DrillExecutionManager] beginWaitingForEnd() - starting to listen for shots in repeat $currentRepeat")

        // Get the last target name
        val sortedTargets = targets.sortedBy { it.seqNo }
        lastTargetName = sortedTargets.lastOrNull()?.targetName

        isWaitingForEnd = true

        // Start 30s guard timer in case end message doesn't arrive
        ackTimeoutTimer?.cancel()
        ackTimeoutTimer = Timer().apply {
            schedule(object : TimerTask() {
                override fun run() {
                    handleEndTimeout()
                }
            }, 30000)
        }

        // If no expected devices, proceed immediately
        if (expectedDevices.isEmpty()) {
            println("[DrillExecutionManager] No expected devices, completing repeat immediately")
            completeRepeat()
        }
    }

    private fun handleEndTimeout() {
        println("End timeout for repeat $currentRepeat")
        completeRepeat()
    }

    private fun completeRepeat() {
        isWaitingForEnd = false
        ackTimeoutTimer?.cancel()
        ackTimeoutTimer = null

        val repeatIndex = currentRepeat
        finalizeRepeat(repeatIndex)

        // Notify UI that repeat is complete, UI will handle next repeat logic
        println("Completed repeat $repeatIndex")
        // NOTE: onComplete is NOT called here - UI will call completeDrill() when all repeats are done
    }

    private fun prepareForRepeatStart() {
        // DO NOT clear currentRepeatShots here - it's cleared in sendReadyCommands() at the start of readiness check
        // This ensures grace period shots from previous repeat are not lost
        currentRepeatStartTime = Date()
        startCommandTime = null
        // DO NOT reset beepTime here - it's set by UI via setBeepTime() before startExecution()
        endCommandTime = null
        drillDuration = null

        println("[DrillExecutionManager] prepareForRepeatStart() - ready for repeat $currentRepeat")

        // Set first target name for later use in finalizeRepeat
        val sortedTargets = targets.sortedBy { it.seqNo }
        firstTargetName = sortedTargets.firstOrNull()?.targetName
    }

    private fun finalizeRepeat(repeatIndex: Int) {
        val startTime = currentRepeatStartTime ?: run {
            println("[DrillExecutionManager] No start time for repeat $repeatIndex, skipping summary")
            return
        }

        val sortedShots = currentRepeatShots.sortedBy { it.receivedAt }

        println("[DrillExecutionManager] finalizeRepeat($repeatIndex) - currentRepeatShots count: ${currentRepeatShots.size}, sorted: ${sortedShots.size}")

        // Validate: if no shots received at all, invalidate this repeat
        if (sortedShots.isEmpty()) {
            println("[DrillExecutionManager] ⚠️ No shots received from any target for repeat $repeatIndex, invalidating repeat")
            println("[DrillExecutionManager] - currentRepeat: $currentRepeat")
            println("[DrillExecutionManager] - isWaitingForEnd: $isWaitingForEnd")
            println("[DrillExecutionManager] - BeepTime: $beepTime")
            // DO NOT clear currentRepeatStartTime here - let grace period shots be collected
            // It will be cleared in sendReadyCommands() when next repeat starts
            currentRepeatShots.clear()
            return
        }

        println("[DrillExecutionManager] ✅ finalizeRepeat($repeatIndex) - found ${sortedShots.size} shots")

        // Calculate total time: from BEEP to last shot
        var totalTime = 0.0
        val timerDelay = if (randomDelay > 0) randomDelay else drillSetup.delay

        if (beepTime != null && sortedShots.isNotEmpty()) {
            val lastShotTime = sortedShots.last().receivedAt
            totalTime = maxOf(0.0, (lastShotTime.time - beepTime!!.time) / 1000.0)
            println("Total time calculation - beep: $beepTime, last shot: $lastShotTime, total: $totalTime")
        } else {
            println("Warning: No beepTime or shots received for repeat $repeatIndex, using fallback calculation")
            // Fallback to old method if drill_duration available
            drillDuration?.let { duration ->
                totalTime = maxOf(0.0, duration - timerDelay)
                println("Fallback total time - drill_duration: $duration, delay_time: $timerDelay, total: $totalTime")
            } ?: run {
                // Last resort: use shot-based calculation
                val timeSumPerTarget = mutableMapOf<String, Double>()
                for (shot in sortedShots) {
                    val device = shot.shot.device ?: shot.shot.target ?: "unknown"
                    val currentSum = timeSumPerTarget[device] ?: 0.0
                    timeSumPerTarget[device] = currentSum + shot.shot.content.actualTimeDiff
                }
                totalTime = timeSumPerTarget.values.maxOrNull() ?: 0.0
            }
        }

        // Recalculate timeDiff: first shot relative to beepTime, rest relative to previous shot's timestamp
        val adjustedShots = sortedShots.mapIndexed { index, event ->
            val newTimeDiff = if (beepTime != null) {
                if (index == 0) {
                    (event.receivedAt.time - beepTime!!.time) / 1000.0
                } else {
                    val previousReceivedAt = sortedShots[index - 1].receivedAt
                    (event.receivedAt.time - previousReceivedAt.time) / 1000.0
                }
            } else {
                // Fallback to old adjustment
                if (event.shot.device != firstTargetName) {
                    maxOf(0.0, event.shot.content.actualTimeDiff - timerDelay)
                } else {
                    event.shot.content.actualTimeDiff
                }
            }

            val adjustedContent = Content(
                command = event.shot.content.actualCommand,
                hitArea = event.shot.content.actualHitArea,
                hitPosition = event.shot.content.actualHitPosition,
                rotationAngle = event.shot.content.actualRotationAngle,
                targetType = event.shot.content.actualTargetType,
                timeDiff = newTimeDiff,
                device = event.shot.content.device,
                targetPos = event.shot.content.actualTargetPos,
                `repeat` = event.shot.content.actualRepeat
            )

            ShotData(
                target = event.shot.target,
                content = adjustedContent,
                type = event.shot.type,
                action = event.shot.action,
                device = event.shot.device
            )
        }

        val numShots = adjustedShots.size
        val fastest = adjustedShots.map { it.content.actualTimeDiff }.minOrNull() ?: 0.0
        val firstShot = adjustedShots.firstOrNull()?.content?.actualTimeDiff ?: 0.0

        // Group shots by target/device and keep only the best 2 per target
        // Exception: shots in no-shoot zones (whitezone, blackzone) always count as they deduct score
        val shotsByTarget = mutableMapOf<String, MutableList<ShotData>>()
        for (shot in adjustedShots) {
            val device = shot.device ?: shot.target ?: "unknown"
            shotsByTarget.getOrPut(device) { mutableListOf() }.add(shot)
        }

        // Keep best 2 shots per target, but always include no-shoot zone hits
        val bestShotsPerTarget = mutableListOf<ShotData>()
        for ((_, shots) in shotsByTarget) {
            val noShootZoneShots = shots.filter { shot ->
                val trimmed = shot.content.actualHitArea.trim().lowercase()
                trimmed == "whitezone" || trimmed == "blackzone"
            }

            val otherShots = shots.filter { shot ->
                val trimmed = shot.content.actualHitArea.trim().lowercase()
                trimmed != "whitezone" && trimmed != "blackzone"
            }

            // Sort other shots by score (descending) and keep best 2
            val sortedOtherShots = otherShots.sortedByDescending { scoreForHitArea(it.content.actualHitArea) }
            val bestOtherShots = sortedOtherShots.take(2)

            // Always include no-shoot zone shots plus best 2 other shots
            bestShotsPerTarget.addAll(noShootZoneShots)
            bestShotsPerTarget.addAll(bestOtherShots)
        }

        var totalScore = bestShotsPerTarget.sumOf { scoreForHitArea(it.content.actualHitArea) }

        // Auto re-evaluate score: deduct 10 points for each missed target
        val missedTargetCount = calculateMissedTargets(adjustedShots)
        val missedTargetPenalty = missedTargetCount * 10
        totalScore -= missedTargetPenalty

        if (missedTargetCount > 0) {
            println("Repeat $repeatIndex: $missedTargetCount target(s) missed, penalty: -$missedTargetPenalty points")
        }

        val summary = DrillRepeatSummary(
            repeatIndex = repeatIndex,
            totalTime = totalTime,
            numShots = numShots,
            firstShot = firstShot,
            fastest = fastest,
            score = totalScore,
            shots = adjustedShots
        )

        if (repeatIndex - 1 < repeatSummaries.size) {
            repeatSummaries[repeatIndex - 1] = summary
        } else {
            repeatSummaries.add(summary)
        }

        // Clear shots after processing, but DO NOT clear currentRepeatStartTime yet
        // Grace period is still active and may have more shots arriving
        // currentRepeatStartTime will be cleared in sendReadyCommands() when next repeat starts
        currentRepeatShots.clear()
    }

    private fun startObservingShots() {
        println("[DrillExecutionManager] startObservingShots() - registering BLE shot observer")
        bleManager.onShotReceived = { shotData ->
            handleShotNotification(shotData)
        }
        println("[DrillExecutionManager] Shot observer registered")
    }

    private fun stopObservingShots() {
        println("[DrillExecutionManager] stopObservingShots() - removing BLE shot observer")
        bleManager.onShotReceived = null
        println("[DrillExecutionManager] Shot observer removed")
    }

    private fun handleShotNotification(shotData: ShotData) {
        val currentRepeatStartTime = this.currentRepeatStartTime ?: run {
            println("[DrillExecutionManager] Shot received but no currentRepeatStartTime set")
            return
        }

        println("[DrillExecutionManager] Received shot data: $shotData")

        try {
            val shot = shotData
            println("[DrillExecutionManager] Shot decoded successfully - cmd: ${shot.content.actualCommand}, ha: ${shot.content.actualHitArea}, device: ${shot.device ?: "unknown"}")

            // Filter shots by repeat number: only accept shots for the current repeat
            val shotRepeatNumber = shot.content.actualRepeat
            if (shotRepeatNumber != null && shotRepeatNumber != currentRepeat) {
                println("[DrillExecutionManager] Ignoring shot from repeat $shotRepeatNumber, currently in repeat $currentRepeat")
                return
            }
            if (shotRepeatNumber == null) {
                println("[DrillExecutionManager] Shot has no repeat number, accepting for current repeat $currentRepeat")
            } else {
                println("[DrillExecutionManager] Shot repeat $shotRepeatNumber matches current repeat $currentRepeat")
            }

            val event = ShotEvent(shot, Date())
            currentRepeatShots.add(event)

            println("[DrillExecutionManager] Shot accepted! Total shots in repeat $currentRepeat: ${currentRepeatShots.size}")
        } catch (e: Exception) {
            println("[DrillExecutionManager] Failed to decode shot: ${e.message}")
        }
    }

    private fun scoreForHitArea(hitArea: String): Int {
        val trimmed = hitArea.trim().lowercase()
        return when (trimmed) {
            "azone" -> 5
            "czone" -> 3
            "dzone" -> 2
            "miss" -> 0
            "whitezone" -> -10
            "blackzone" -> -10
            "circlearea" -> 5 // Paddle
            "popperzone" -> 5 // Popper
            else -> 0
        }
    }

    /// Calculate the number of missed targets in a drill repeat
    /// A target is considered missed if no shots were received from it
    private fun calculateMissedTargets(shots: List<ShotData>): Int {
        val expectedTargets = targets
            .mapNotNull { it.targetName }
            .filter { it.isNotEmpty() }
            .toSet()

        val shotsDevices = shots.mapNotNull { it.device ?: it.target }.toSet()
        val missedTargets = expectedTargets - shotsDevices

        return missedTargets.size
    }

    private data class ShotEvent(
        val shot: ShotData,
        val receivedAt: Date
    )
}