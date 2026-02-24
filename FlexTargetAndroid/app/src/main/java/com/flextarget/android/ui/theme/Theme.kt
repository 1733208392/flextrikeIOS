package com.flextarget.android.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ButtonColors
import androidx.compose.material3.Text
import androidx.compose.foundation.text.selection.TextSelectionColors
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight

val LocalCursorColor = staticCompositionLocalOf<Color> { md_theme_dark_onPrimary }

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
            CompositionLocalProvider(
                LocalAppButtonColors provides appButtonColors,
                LocalCursorColor provides md_theme_dark_onPrimary,
                androidx.compose.foundation.text.selection.LocalTextSelectionColors provides TextSelectionColors(
                    handleColor = md_theme_dark_onPrimary,
                    backgroundColor = md_theme_dark_onPrimary.copy(alpha = 0.4f)
                )
            ) {
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
        androidx.compose.runtime.CompositionLocalProvider(
            androidx.compose.material3.LocalTextStyle provides MaterialTheme.typography.labelLarge.copy(
                fontWeight = FontWeight.Bold
            )
        ) {
            content()
        }
    }
}

@Composable
fun AppButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
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
        Text(
            text = text.uppercase(),
            style = MaterialTheme.typography.labelLarge.copy(
                fontWeight = FontWeight.Bold
            )
        )
    }
}
