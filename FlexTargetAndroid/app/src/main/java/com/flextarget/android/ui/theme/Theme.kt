package com.flextarget.android.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ButtonColors
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier

@Composable
fun FlexTargetTheme(
    useDarkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colors = if (useDarkTheme) DarkColorScheme else DarkColorScheme

    // App-level button colors: normal state uses md_theme_dark_onPrimary as background
    // with md_theme_dark_primary as content; disabled state is the opposite.
    val appButtonColors: ButtonColors = ButtonDefaults.buttonColors(
        containerColor = md_theme_dark_onPrimary,
        contentColor = md_theme_dark_primary,
        disabledContainerColor = md_theme_dark_primary,
        disabledContentColor = md_theme_dark_onPrimary
    )

    val LocalAppButtonColors = staticCompositionLocalOf<ButtonColors> { appButtonColors }

    MaterialTheme(
        colorScheme = colors,
        typography = AppTypography,
        content = {
            CompositionLocalProvider(LocalAppButtonColors provides appButtonColors) {
                Surface {
                    content()
                }
            }
        }
    )
}

@Composable
fun AppButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable () -> Unit
) {
    // Use app-level button colors by default
    val colors = ButtonDefaults.buttonColors(
        containerColor = md_theme_dark_onPrimary,
        contentColor = md_theme_dark_primary,
        disabledContainerColor = md_theme_dark_primary,
        disabledContentColor = md_theme_dark_onPrimary
    )

    Button(
        onClick = onClick,
        modifier = modifier,
        enabled = enabled,
        colors = colors,
        shape = RoundedCornerShape(12.dp)
    ) {
        content()
    }
}
