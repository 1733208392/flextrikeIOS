package com.flextarget.android.data.remote.api

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

/**
 * Retrofit API interface for the IPSC Match Management System.
 * Base URL: http://124.222.233.30/
 * Base path: /api/v1
 */
interface IpscApi {

    /**
     * 接口 3: List all matches (used for match picker)
     * GET /api/v1/matches
     */
    @GET("api/v1/matches")
    suspend fun getMatches(): IpscApiResponse<List<IpscMatch>>

    /**
     * 接口 1: Get squad queue for a match — all squads + each squad's shooter list + progress.
     * GET /api/v1/matches/{matchId}/squads/queue
     *
     * Responses:
     *  200 – success: { success: true, data: [ IpscSquad ] }
     *  404 – match not found
     */
    @GET("api/v1/matches/{matchId}/squads/queue")
    suspend fun getSquadQueue(
        @Path("matchId") matchId: Int
    ): IpscApiResponse<List<IpscSquad>>

    /**
     * 接口 2: Submit FlexTarget score for a shooter/stage.
     * POST /api/v1/matches/{matchId}/scores/flextarget
     *
     * Same shooter+stage → UPSERT (overwrites previous result).
     */
    @POST("api/v1/matches/{matchId}/scores/flextarget")
    suspend fun submitScore(
        @Path("matchId") matchId: Int,
        @Body request: IpscScoreSubmitRequest
    ): IpscApiResponse<IpscScoreSubmitData>
}
