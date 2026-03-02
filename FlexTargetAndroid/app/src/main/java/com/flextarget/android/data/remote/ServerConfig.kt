package com.flextarget.android.data.remote

import android.content.Context
import android.content.SharedPreferences

class ServerConfig(private val context: Context) {

    private val prefs: SharedPreferences = context.getSharedPreferences("server_prefs", Context.MODE_PRIVATE)

    companion object {

        const val INTERNATIONAL = "https://app.etarget.grwolftactical.com"

        const val CHINA = "https://etarget.topoint-archery.cn"

    }

    fun getServerUrl(): String {

        return prefs.getString("server_url", INTERNATIONAL) ?: INTERNATIONAL

    }

    fun setServerUrl(url: String) {

        prefs.edit().putString("server_url", url).apply()

    }

    fun isInternational(): Boolean = getServerUrl() == INTERNATIONAL

    fun toggleServer() {

        val current = getServerUrl()

        setServerUrl(if (current == INTERNATIONAL) CHINA else INTERNATIONAL)

    }

}