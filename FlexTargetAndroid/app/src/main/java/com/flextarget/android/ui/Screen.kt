package com.flextarget.android.ui

sealed class Screen(val route: String) {
    object Drills : Screen("drills")
    object History : Screen("history")
    object Competition : Screen("competition")
    object Admin : Screen("admin")
    object QRScanner : Screen("qr_scanner")
    object ConnectTarget : Screen("connect_target")
    object DrillList : Screen("drill_list")
}
