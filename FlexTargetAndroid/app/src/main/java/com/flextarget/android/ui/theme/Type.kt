package com.flextarget.android.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import com.flextarget.android.R

val ttNormFontFamily = FontFamily(
    Font(R.font.tt_norms_regular, FontWeight.Normal),
    Font(R.font.tt_norms_medium, FontWeight.Medium),
    Font(R.font.tt_norms_bold, FontWeight.Bold)
)

val digitalDreamFontFamily = FontFamily(
    Font(R.font.digitaldream, FontWeight.Normal)
)

val AppTypography = Typography().run {
    copy(
        displayLarge = this.displayLarge.copy(fontFamily = ttNormFontFamily),
        displayMedium = this.displayMedium.copy(fontFamily = ttNormFontFamily),
        displaySmall = this.displaySmall.copy(fontFamily = ttNormFontFamily),

        headlineLarge = this.headlineLarge.copy(fontFamily = ttNormFontFamily),
        headlineMedium = this.headlineMedium.copy(fontFamily = ttNormFontFamily),
        headlineSmall = this.headlineSmall.copy(fontFamily = ttNormFontFamily),

        titleLarge = this.titleLarge.copy(fontFamily = ttNormFontFamily),
        titleMedium = this.titleMedium.copy(fontFamily = ttNormFontFamily),
        titleSmall = this.titleSmall.copy(fontFamily = ttNormFontFamily),

        bodyLarge = this.bodyLarge.copy(fontFamily = ttNormFontFamily),
        bodyMedium = this.bodyMedium.copy(fontFamily = ttNormFontFamily),
        bodySmall = this.bodySmall.copy(fontFamily = ttNormFontFamily),

        labelLarge = this.labelLarge.copy(fontFamily = ttNormFontFamily),
        labelMedium = this.labelMedium.copy(fontFamily = ttNormFontFamily),
        labelSmall = this.labelSmall.copy(fontFamily = ttNormFontFamily)
    )
}