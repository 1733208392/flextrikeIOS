package com.flextarget.android.data.remote.api

import com.google.gson.annotations.SerializedName
import retrofit2.http.*

/**
 * Common API response wrapper
 */
data class ApiResponse<T>(
    @SerializedName("code")
    val code: Int,
    @SerializedName("msg")
    val msg: String,
    @SerializedName("data")
    val data: T?
)

// ============ LOGIN & AUTHENTICATION ============

data class LoginRequest(
    @SerializedName("mobile")
    val mobile: String,
    @SerializedName("password")
    val password: String // Base64 encoded without padding
)

data class LoginResponse(
    @SerializedName("user_uuid")
    val userUUID: String,
    @SerializedName("access_token")
    val accessToken: String,
    @SerializedName("refresh_token")
    val refreshToken: String
)

data class RefreshTokenRequest(
    @SerializedName("refresh_token")
    val refresh_token: String
)

data class RefreshTokenResponse(
    @SerializedName("user_uuid")
    val userUUID: String,
    @SerializedName("access_token")
    val accessToken: String,
    @SerializedName("refresh_token")
    val refreshToken: String? // Optional in some responses
)

// ============ USER MANAGEMENT ============

data class EditUserRequest(
    @SerializedName("username")
    val username: String
)

data class EditUserResponse(
    @SerializedName("user_uuid")
    val user_uuid: String
)

data class ChangePasswordRequest(
    @SerializedName("old_password")
    val old_password: String, // Base64 encoded
    @SerializedName("new_password")
    val new_password: String  // Base64 encoded
)

data class DeviceRelateRequest(
    @SerializedName("auth_data")
    val auth_data: String
)

data class DeviceRelateResponse(
    @SerializedName("device_uuid")
    val deviceUUID: String,
    @SerializedName("device_token")
    val deviceToken: String,
    @SerializedName("expiration")
    val expiration: Long? // Unix timestamp in milliseconds or seconds
)

// ============ GAME PLAY / COMPETITION ============

data class AddGamePlayRequest(
    @SerializedName("game_type")
    val game_type: String, // Competition UUID
    @SerializedName("game_ver")
    val game_ver: String = "1.0.0",
    @SerializedName("player_mobile")
    val player_mobile: String? = null,
    @SerializedName("player_nickname")
    val player_nickname: String? = null,
    @SerializedName("score")
    val score: Int,
    @SerializedName("detail")
    val detail: Any, // Shot details JSON object
    @SerializedName("play_time")
    val play_time: String, // "YYYY-MM-DD HH:MM:SS"
    @SerializedName("is_public")
    val is_public: Boolean = false,
    @SerializedName("namespace")
    val namespace: String = "default"
)

data class GamePlayResponse(
    @SerializedName("device_uuid")
    val deviceUUID: String,
    @SerializedName("play_uuid")
    val playUUID: String
)

data class GetGamePlayListRequest(
    @SerializedName("game_type")
    val game_type: String,
    @SerializedName("device_uuid")
    val device_uuid: String,
    @SerializedName("page")
    val page: Int = 1,
    @SerializedName("limit")
    val limit: Int = 20,
    @SerializedName("namespace")
    val namespace: String = "default"
)

data class GamePlayListResponse(
    @SerializedName("total_count")
    val totalCount: Int,
    @SerializedName("limit")
    val limit: Int,
    @SerializedName("page")
    val page: Int,
    @SerializedName("rows")
    val rows: List<GamePlayRow>
)

data class GamePlayRow(
    @SerializedName("play_uuid")
    val playUUID: String,
    @SerializedName("device_uuid")
    val deviceUUID: String,
    @SerializedName("bluetooth_name")
    val bluetoothName: String?,
    @SerializedName("game_type")
    val gameType: String,
    @SerializedName("game_ver")
    val gameVer: String,
    @SerializedName("score")
    val score: Int,
    @SerializedName("detail")
    val detail: String?, // JSON string
    @SerializedName("play_time")
    val playTime: String,
    @SerializedName("player_mobile")
    val playerMobile: String?,
    @SerializedName("player_nickname")
    val playerNickname: String?,
    @SerializedName("is_public")
    val isPublic: Boolean
)

data class GamePlayRankingRequest(
    @SerializedName("game_type")
    val game_type: String,
    @SerializedName("game_ver")
    val game_ver: String = "1.0.0",
    @SerializedName("namespace")
    val namespace: String = "default",
    @SerializedName("page")
    val page: Int = 1,
    @SerializedName("limit")
    val limit: Int = 20
)

data class RankingRow(
    @SerializedName("rank")
    val rank: Int,
    @SerializedName("play_uuid")
    val playUUID: String,
    @SerializedName("device_uuid")
    val deviceUUID: String,
    @SerializedName("bluetooth_name")
    val bluetoothName: String?,
    @SerializedName("game_type")
    val gameType: String,
    @SerializedName("game_ver")
    val gameVer: String,
    @SerializedName("score")
    val score: Int,
    @SerializedName("play_time")
    val playTime: String,
    @SerializedName("player_mobile")
    val playerMobile: String?,
    @SerializedName("player_nickname")
    val playerNickname: String?,
    @SerializedName("is_public")
    val isPublic: Boolean
)

data class GamePlayRankingResponse(
    @SerializedName("total_count")
    val totalCount: Int,
    @SerializedName("limit")
    val limit: Int,
    @SerializedName("page")
    val page: Int,
    @SerializedName("rows")
    val rows: List<RankingRow>
)

// ============ OTA UPDATE ============

data class GetOTAVersionRequest(
    @SerializedName("auth_data")
    val auth_data: String
)

data class OTAVersionResponse(
    @SerializedName("version")
    val version: String,
    @SerializedName("address")
    val address: String,
    @SerializedName("checksum")
    val checksum: String
)

data class GetOTAHistoryRequest(
    @SerializedName("auth_data")
    val auth_data: String,
    @SerializedName("page")
    val page: Int = 1,
    @SerializedName("limit")
    val limit: Int = 10
)

data class OTAHistoryResponse(
    @SerializedName("total_count")
    val totalCount: Int,
    @SerializedName("limit")
    val limit: Int,
    @SerializedName("page")
    val page: Int,
    @SerializedName("rows")
    val rows: List<OTAVersionRow>
)

data class OTAVersionRow(
    @SerializedName("version")
    val version: String,
    @SerializedName("checksum")
    val checksum: String
)
