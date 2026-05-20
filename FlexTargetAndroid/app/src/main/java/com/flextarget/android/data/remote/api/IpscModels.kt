package com.flextarget.android.data.remote.api

import com.google.gson.annotations.SerializedName

// ============ COMMON ============

data class IpscApiResponse<T>(
    val success: Boolean,
    val data: T? = null,
    val error: String? = null
)

// ============ MATCHES (接口 3) ============

data class IpscMatch(
    val id: Int,
    val name: String,
    val date: String,
    val status: String,
    @SerializedName("created_at") val createdAt: String
)

data class IpscStage(
    val id: Int,
    @SerializedName("match_id") val matchId: Int,
    val name: String,
    @SerializedName("sort_order") val sortOrder: Int
)

// ============ SQUAD QUEUE (接口 1) ============

data class IpscShooter(
    val id: Int,
    val name: String,
    @SerializedName("bib_number") val bibNumber: String,
    @SerializedName("division_name") val divisionName: String,
    @SerializedName(value = "category_name", alternate = ["category"]) val categoryName: String? = null,
    @SerializedName("power_factor") val powerFactor: String,
    @SerializedName("stages_done") val stagesDone: Int,
    val status: String  // "waiting" | "shooting" | "done"
)

data class IpscSquad(
    val id: Int,
    val name: String,
    @SerializedName("sort_order") val sortOrder: Int,
    @SerializedName("shooter_count") val shooterCount: Int,
    @SerializedName("stages_total") val stagesTotal: Int,
    val shooters: List<IpscShooter>
)

// ============ SCORE SUBMIT (接口 2) ============

data class IpscScoreHits(
    @SerializedName("A") val a: Int,
    @SerializedName("C") val c: Int,
    @SerializedName("D") val d: Int,
    @SerializedName("M") val m: Int,
    @SerializedName("N") val n: Int
)

data class IpscScorePenalties(
    @SerializedName("PE") val pe: Int
)

data class IpscScoreTargetRow(
    @SerializedName("row_type") val rowType: String,
    @SerializedName("row_no") val rowNo: Int,
    @SerializedName("A") val a: Int,
    @SerializedName("C") val c: Int,
    @SerializedName("D") val d: Int,
    @SerializedName("M") val m: Int,
    @SerializedName("N") val n: Int
)

data class IpscScoreSubmitRequest(
    @SerializedName("shooter_bib") val shooterBib: String,
    @SerializedName("stage_id") val stageId: String,
    @SerializedName("total_time") val totalTime: Double,
    val hits: IpscScoreHits? = null,
    val rows: List<IpscScoreTargetRow>? = null,
    val penalties: IpscScorePenalties,
    @SerializedName("first_shot") val firstShot: Double? = null,
    @SerializedName("fastest_split") val fastestSplit: Double? = null
)

data class IpscScoreRecord(
    val id: Int,
    @SerializedName("match_id") val matchId: Int,
    @SerializedName("shooter_id") val shooterId: Int,
    @SerializedName("stage_id") val stageId: Int,
    @SerializedName("total_time") val totalTime: Double,
    @SerializedName("a_hits") val aHits: Int,
    @SerializedName("c_hits") val cHits: Int,
    @SerializedName("d_hits") val dHits: Int,
    @SerializedName("m_hits") val mHits: Int,
    @SerializedName("n_hits") val nHits: Int,
    val pe: Int,
    @SerializedName("first_shot") val firstShot: Double?,
    @SerializedName("fastest_split") val fastestSplit: Double?,
    @SerializedName("total_points") val totalPoints: Int,
    @SerializedName("hit_factor") val hitFactor: Double
)

data class IpscScoreSubmitData(
    val score: IpscScoreRecord,
    @SerializedName(value = "totalPoints", alternate = ["total_points"]) val totalPoints: Int,
    @SerializedName(value = "hitFactor", alternate = ["hit_factor"]) val hitFactor: Double
)
