package com.flextarget.android.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.foundation.isSystemInDarkTheme

@Composable
fun FlexTargetTheme(
    useDarkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colors = if (useDarkTheme) DarkColorScheme else DarkColorScheme

    MaterialTheme(
        colorScheme = colors,
        typography = AppTypography,
        content = {
            Surface {
                content()
            }
        }
    )
}
