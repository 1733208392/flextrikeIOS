package com.flextarget.android.data.model

import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.gson.Gson
import java.util.*
import com.flextarget.android.data.ble.BLEManager
import java.util.Timer
import java.util.Date
import java.util.TimerTask
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
import com.flextarget.android.data.ble.AndroidBLEManager
import kotlin.math.max

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
    private var onRepeatFinalized: ((Int) -> Unit)? = null
    private var drillDuration: Double? = null
    private var isReadinessCheckOnly = false
    private var isFinalizingRepeat = false

    val summaries: List<DrillRepeatSummary>
        get() = repeatSummaries

    fun isCurrentRepeatFinalized(): Boolean = !isFinalizingRepeat

    init {
        startObservingShots()
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

    fun setOnRepeatFinalized(callback: ((Int) -> Unit)?) {
        onRepeatFinalized = callback
    }

    fun stopExecution() {
        isStopped = true
        ackTimeoutTimer?.cancel()
        pauseTimer?.cancel()
        gracePeriodTimer?.cancel()
        stopObservingShots()
    }

    fun completeDrill() {
        println("[DrillExecutionManager] completeDrill() - drill fully completed")
        println("[DrillExecutionManager] completeDrill() - returning ${summaries.size} summaries")
        summaries.forEach { summary ->
            println("[DrillExecutionManager] Summary ${summary.repeatIndex}: ${summary.numShots} shots, score: ${summary.score}")
        }
        stopExecution()
        onComplete(summaries)
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
        // NOTE: Do NOT call onRepeatFinalized here - it's already called in completeRepeat via finalizeRepeat completion
        // NOTE: Do NOT call onComplete here - UI will call completeDrill() when ready
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
            val content = if (target.targetType == "disguised_enemy") {
                mapOf(
                    "command" to "ready",
                    "mode" to "cqb",
                    "targetType" to "disguised_enemy"
                )
            } else {
                val delayValue = 0.0  // Always 0 for ready command, matching iOS
                val roundedDelay = String.format("%.2f", delayValue).toDouble()

                mapOf(
                    "command" to "ready",
                    "delay" to roundedDelay,
                    "targetType" to (target.targetType ?: ""),
                    "timeout" to 1200,
                    "countedShots" to target.countedShots,
                    "repeat" to currentRepeat,
                    "isFirst" to (index == 0),
                    "isLast" to (index == sortedTargets.size - 1),
                    "mode" to (drillSetup.mode ?: "ipsc")
                )
            }

            val message = mapOf(
                "action" to "netlink_forward",
                "dest" to (target.targetName ?: ""),
                "content" to content
            )

            val messageData = Gson().toJson(message)
            Log.d("DrillExecutionManager","Sending ready message for target ${target.targetName}, Data: ${messageData}")
            bleManager.writeJSON(messageData)

            // Send animation_config if CQB mode and action is set
            if ((drillSetup.mode ?: "").lowercase() == "cqb" && !target.action.isNullOrEmpty()) {
                val animationContent = mapOf(
                    "command" to "animation_config",
                    "action" to target.action,
                    "duration" to target.duration
                )
                val animationMessage = mapOf(
                    "action" to "netlink_forward",
                    "dest" to (target.targetName ?: ""),
                    "content" to animationContent
                )
                val animationData = Gson().toJson(animationMessage)
                Log.d("DrillExecutionManager", "Sending animation_config for target ${target.targetName}")
                bleManager.writeJSON(animationData)
            }
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
        println("[DrillExecutionManager] handleNetlinkForward called with: $json")
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

        // Notify UI that repeat is finalized
        println("Completed repeat $repeatIndex")
        onRepeatFinalized?.invoke(repeatIndex)
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
        isFinalizingRepeat = true
        try {
            val startTime = currentRepeatStartTime ?: run {
                println("[DrillExecutionManager] No start time for repeat $repeatIndex, skipping summary")
                isFinalizingRepeat = false
                return
            }

            // Sort shots by hardware timeDiff if available, fallback to receivedAt
            val sortedShots = currentRepeatShots.sortedWith(compareBy<ShotEvent> {
                it.shot.content.actualTimeDiff
            }.thenBy {
                it.receivedAt
            })

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
                isFinalizingRepeat = false
                return
            }

            println("[DrillExecutionManager] ✅ finalizeRepeat($repeatIndex) - found ${sortedShots.size} shots")

        // Use hardware-originated timeDiff from the shot data message (preferred over receivedAt timestamp)
        // timeDiff = timing of shot on target device - timing when repeat starts
        val totalTime = sortedShots.lastOrNull()?.shot?.content?.actualTimeDiff ?: 0.0

        // Create adjusted shots with calculated split times (relative to previous shot)
        // matching the iOS DrillExecutionManager behavior
        val adjustedShots = sortedShots.mapIndexed { index, event ->
            val hardwareAbsoluteTime = event.shot.content.actualTimeDiff
            val newTimeDiff = if (index == 0) {
                // First shot keeps original absolute timeDiff
                hardwareAbsoluteTime
            } else {
                // Subsequent shots: difference from previous shot's absolute timeDiff
                hardwareAbsoluteTime - sortedShots[index - 1].shot.content.actualTimeDiff
            }

            val adjustedContent = Content(
                command = event.shot.content.actualCommand,
                hitArea = event.shot.content.actualHitArea,
                hitPosition = event.shot.content.actualHitPosition,
                rotationAngle = event.shot.content.actualRotationAngle,
                targetType = event.shot.content.actualTargetType,
                timeDiff = newTimeDiff,
                device = event.shot.device ?: event.shot.content.device,
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

        val firstShot = adjustedShots.firstOrNull()?.content?.timeDiff ?: 0.0
        val fastest = (adjustedShots.map { it.content.timeDiff }.minOrNull() ?: 0.0).coerceAtLeast(0.0)

        // Log original timing data and adjusted timing data
        println("[DrillExecutionManager] ========== TIMING DEBUG ==========")
        println("[DrillExecutionManager] Original hardware timeDiff values (from shot data):")
        sortedShots.forEachIndexed { index, event ->
            println("[DrillExecutionManager]   Shot ${index + 1}: originalTimeDiff = ${event.shot.content.actualTimeDiff}s")
        }
        println("[DrillExecutionManager] Adjusted timeDiff values (split times):")
        adjustedShots.forEachIndexed { index, shot ->
            println("[DrillExecutionManager]   Shot ${index + 1}: adjustedTimeDiff = ${shot.content.timeDiff}s")
        }
        println("[DrillExecutionManager] Summary metrics - totalTime: $totalTime, firstShot: $firstShot, fastest: $fastest")
        println("[DrillExecutionManager] ==================================")

        val numShots = adjustedShots.size

        val totalScore = ScoringUtility.calculateTotalScore(adjustedShots, targets).toInt()

        var cqbResults: List<CQBShotResult>? = null
        var cqbPassed: Boolean? = null

        if ((drillSetup.mode ?: "").lowercase() == "cqb") {
            val targetDevices = targets.mapNotNull { it.targetName }.filter { it.isNotEmpty() }
            val cqbDrillResult = CQBScoringUtility.generateCQBDrillResult(
                shots = adjustedShots,
                drillDuration = totalTime,
                targetDevices = targetDevices
            )
            cqbResults = cqbDrillResult.shotResults
            cqbPassed = cqbDrillResult.drilPassed
        }

        val summary = DrillRepeatSummary(
            repeatIndex = repeatIndex,
            totalTime = totalTime,
            numShots = numShots,
            firstShot = firstShot,
            fastest = fastest,
            score = totalScore,
            shots = adjustedShots,
            cqbResults = cqbResults,
            cqbPassed = cqbPassed
        )
            println("[DrillExecutionManager] Created summary for repeat $repeatIndex")

            if (repeatIndex - 1 < repeatSummaries.size) {
                repeatSummaries[repeatIndex - 1] = summary
            } else {
                repeatSummaries.add(summary)
            }

            println("[DrillExecutionManager] Added summary for repeat $repeatIndex, repeatSummaries.size = ${repeatSummaries.size}")

            // Clear shots after processing, but DO NOT clear currentRepeatStartTime yet
            // Grace period is still active and may have more shots arriving
            // currentRepeatStartTime will be cleared in sendReadyCommands() when next repeat starts
            currentRepeatShots.clear()
        } catch (e: Exception) {
            println("[DrillExecutionManager] Exception in finalizeRepeat: ${e.message}")
            e.printStackTrace()
        } finally {
            isFinalizingRepeat = false
        }
    }

    private fun startObservingShots() {
        println("[DrillExecutionManager] startObservingShots() - registering BLE shot observer")
        bleManager.onShotReceived = { shotData ->
            handleShotNotification(shotData)
        }
        bleManager.onNetlinkForwardReceived = { message ->
            handleNetlinkForward(message)
        }
        println("[DrillExecutionManager] Shot and netlink forward observers registered")
    }

    private fun stopObservingShots() {
        println("[DrillExecutionManager] stopObservingShots() - removing BLE shot observer")
        bleManager.onShotReceived = null
        bleManager.onNetlinkForwardReceived = null
        println("[DrillExecutionManager] Shot and netlink forward observers removed")
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



    /// Calculate the number of missed targets in a drill repeat
    /// A target is considered missed if no shots were received from it
    private fun calculateMissedTargets(shots: List<ShotData>): Int {
        return ScoringUtility.calculateMissedTargets(shots, targets)
    }

    private data class ShotEvent(
        val shot: ShotData,
        val receivedAt: Date
    )
}