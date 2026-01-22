package com.flextarget.android.data.remote.api

import retrofit2.http.Body
import retrofit2.http.POST
import retrofit2.http.Header

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
    suspend fun login(@Body request: LoginRequest): ApiResponse<LoginResponse>
    
    /**
     * POST /user/token/refresh
     * Refresh access token using refresh token
     */
    @POST("/user/token/refresh")
    suspend fun refreshToken(@Body request: RefreshTokenRequest): ApiResponse<RefreshTokenResponse>
    
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
        @Body request: EditUserRequest,
        @Header("Authorization") authHeader: String
    ): ApiResponse<EditUserResponse>
    
    /**
     * POST /user/change-password
     * Change user password
     */
    @POST("/user/change-password")
    suspend fun changePassword(
        @Body request: ChangePasswordRequest,
        @Header("Authorization") authHeader: String
    ): ApiResponse<EditUserResponse>
    
    // ============ DEVICE AUTHENTICATION ============
    
    /**
     * POST /device/relate
     * Exchange BLE auth_data for device token
     */
    @POST("/device/relate")
    suspend fun relateDevice(
        @Body request: DeviceRelateRequest,
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
        @Body request: AddGamePlayRequest,
        @Header("Authorization") authHeader: String
    ): ApiResponse<GamePlayResponse>
    
    /**
     * POST /game/play/edit
     * Edit a game play result
     */
    @POST("/game/play/edit")
    suspend fun editGamePlay(
        @Body request: Map<String, Any>,
        @Header("Authorization") authHeader: String
    ): ApiResponse<GamePlayResponse>
    
    /**
     * POST /game/play/list
     * Get list of game play results for a competition
     */
    @POST("/game/play/list")
    suspend fun getGamePlayList(
        @Body request: GetGamePlayListRequest,
        @Header("Authorization") authHeader: String
    ): ApiResponse<GamePlayListResponse>
    
    /**
     * POST /game/play/detail
     * Get details of a specific game play
     */
    @POST("/game/play/detail")
    suspend fun getGamePlayDetail(
        @Body request: Map<String, String>,
        @Header("Authorization") authHeader: String
    ): ApiResponse<GamePlayRow>
    
    /**
     * POST /game/play/ranking
     * Get leaderboard/ranking for a competition
     */
    @POST("/game/play/ranking")
    suspend fun getGamePlayRanking(
        @Body request: GamePlayRankingRequest,
        @Header("Authorization") authHeader: String
    ): ApiResponse<List<RankingRow>>
    
    // ============ OTA UPDATE ============
    
    /**
     * POST /ota/game
     * Get latest OTA version for device
     */
    @POST("/ota/game")
    suspend fun getLatestOTAVersion(@Body request: GetOTAVersionRequest): ApiResponse<OTAVersionResponse>
    
    /**
     * POST /ota/game/history
     * Get OTA update history
     */
    @POST("/ota/game/history")
    suspend fun getOTAHistory(@Body request: GetOTAHistoryRequest): ApiResponse<OTAHistoryResponse>
}
