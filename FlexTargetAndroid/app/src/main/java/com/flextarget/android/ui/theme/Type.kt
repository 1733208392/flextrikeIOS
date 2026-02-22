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

val AppTypography = Typography().run {
    copy(
        labelSmall = this.labelSmall.copy(fontFamily = ttNormFontFamily),
        bodyLarge = this.bodyLarge.copy(fontFamily = ttNormFontFamily),
        titleLarge = this.titleLarge.copy(fontFamily = ttNormFontFamily)
    )
}