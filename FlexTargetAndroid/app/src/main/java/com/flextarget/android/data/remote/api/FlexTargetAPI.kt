package com.flextarget.android.data.remote.api

import retrofit2.http.*

/**
 * Retrofit API interface for FlexTarget backend
 * Base URL: https://etarget.topoint-archery.cn
 */
interface FlexTargetAPI {
    
    // ============ AUTHENTICATION ============
    
    /**
     * POST /user/login
     * User login with mobile and password
     */
    @POST("/user/login")
    suspend fun login(
        @Query("mobile") mobile: String,
        @Query("password") password: String
    ): ApiResponse<LoginResponse>
    
    /**
     * POST /user/token/refresh
     * Refresh access token using refresh token
     */
    @POST("/user/token/refresh")
    suspend fun refreshToken(
        @Query("refresh_token") refresh_token: String
    ): ApiResponse<RefreshTokenResponse>
    
    /**
     * POST /user/logout
     * Logout current user
     */
    @POST("/user/logout")
    suspend fun logout(
        @Header("Authorization") authHeader: String
    ): ApiResponse<Unit>
    
    // ============ USER MANAGEMENT ============
    
    /**
     * POST /user/edit
     * Edit user profile (username)
     */
    @POST("/user/edit")
    suspend fun editUser(
        @Query("username") username: String,
        @Header("Authorization") authHeader: String
    ): ApiResponse<EditUserResponse>
    
    /**
     * POST /user/change-password
     * Change user password
     */
    @POST("/user/change-password")
    suspend fun changePassword(
        @Query("old_password") old_password: String,
        @Query("new_password") new_password: String,
        @Header("Authorization") authHeader: String
    ): ApiResponse<EditUserResponse>
    
    // ============ DEVICE AUTHENTICATION ============
    
    /**
     * POST /device/relate
     * Exchange BLE auth_data for device token
     */
    @POST("/device/relate")
    suspend fun relateDevice(
        @Query("auth_data") auth_data: String,
        @Header("Authorization") authHeader: String
    ): ApiResponse<DeviceRelateResponse>
    
    // ============ GAME PLAY / COMPETITION ============
    
    /**
     * POST /game/play/add
     * Submit a game play result (drill execution result for competition)
     * Requires device token in Authorization header
     */
    @POST("/game/play/add")
    suspend fun addGamePlay(
        @Query("game_type") game_type: String,
        @Query("game_ver") game_ver: String = "1.0",
        @Query("player_mobile") player_mobile: String? = null,
        @Query("player_nickname") player_nickname: String? = null,
        @Query("score") score: Int,
        @Query("detail") detail: String, // JSON string
        @Query("play_time") play_time: String,
        @Query("is_public") is_public: Boolean = false,
        @Query("namespace") namespace: String = "default",
        @Header("Authorization") authHeader: String
    ): ApiResponse<GamePlayResponse>
    
    /**
     * POST /game/play/list
     * Get list of game play results for a competition
     */
    @POST("/game/play/list")
    suspend fun getGamePlayList(
        @Query("game_type") game_type: String,
        @Query("device_uuid") device_uuid: String,
        @Query("page") page: Int = 1,
        @Query("limit") limit: Int = 20,
        @Query("namespace") namespace: String = "default",
        @Header("Authorization") authHeader: String
    ): ApiResponse<GamePlayListResponse>
    
    /**
     * POST /game/play/detail
     * Get details of a specific game play
     */
    @POST("/game/play/detail")
    suspend fun getGamePlayDetail(
        @Query("play_uuid") play_uuid: String,
        @Header("Authorization") authHeader: String
    ): ApiResponse<GamePlayRow>
    
    /**
     * POST /game/play/ranking
     * Get leaderboard/ranking for a competition
     */
    @POST("/game/play/ranking")
    suspend fun getGamePlayRanking(
        @Query("game_type") game_type: String,
        @Query("game_ver") game_ver: String = "1.0",
        @Query("namespace") namespace: String = "default",
        @Query("page") page: Int = 1,
        @Query("limit") limit: Int = 20,
        @Header("Authorization") authHeader: String
    ): ApiResponse<GamePlayRankingResponse>
    
    // ============ OTA UPDATE ============
    
    /**
     * POST /ota/game
     * Get latest OTA version for device
     */
    @POST("/ota/game")
    suspend fun getLatestOTAVersion(
        @Query("auth_data") auth_data: String
    ): ApiResponse<OTAVersionResponse>
    
    /**
     * POST /ota/game/history
     * Get OTA update history
     */
    @POST("/ota/game/history")
    suspend fun getOTAHistory(
        @Query("auth_data") auth_data: String,
        @Query("page") page: Int = 1,
        @Query("limit") limit: Int = 10
    ): ApiResponse<OTAHistoryResponse>
}
