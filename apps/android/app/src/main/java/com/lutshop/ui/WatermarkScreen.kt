package com.lutshop.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lutshop.LutShopAppState
import com.lutshop.R
import com.lutshop.WatermarkStyle

@Composable
fun WatermarkScreen(state: LutShopAppState) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 14.dp, vertical = 16.dp)
            .padding(bottom = 92.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(stringResource(R.string.watermark), color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.watermark_export_hint), color = Color.White.copy(alpha = 0.56f), fontSize = 14.sp)
        }

        WatermarkPreviewCard(state.exportSettings.watermarkStyle)

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            WatermarkTemplateCard(
                style = WatermarkStyle.None,
                title = stringResource(R.string.no_watermark),
                subtitle = stringResource(R.string.clean_export),
                selected = state.exportSettings.watermarkStyle == WatermarkStyle.None,
                modifier = Modifier.weight(1f)
            ) {
                state.exportSettings = state.exportSettings.copy(watermarkStyle = WatermarkStyle.None)
            }
            WatermarkTemplateCard(
                style = WatermarkStyle.FilmBorder,
                title = stringResource(R.string.film_border),
                subtitle = stringResource(R.string.camera_brand_exposure_data),
                selected = state.exportSettings.watermarkStyle == WatermarkStyle.FilmBorder,
                modifier = Modifier.weight(1f)
            ) {
                state.exportSettings = state.exportSettings.copy(watermarkStyle = WatermarkStyle.FilmBorder)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            WatermarkTemplateCard(
                style = WatermarkStyle.HasselbladMinimal,
                title = stringResource(R.string.hasselblad_minimal),
                subtitle = stringResource(R.string.large_border_centered_brand),
                selected = state.exportSettings.watermarkStyle == WatermarkStyle.HasselbladMinimal,
                modifier = Modifier.weight(1f)
            ) {
                state.exportSettings = state.exportSettings.copy(watermarkStyle = WatermarkStyle.HasselbladMinimal)
            }
            WatermarkTemplateCard(
                style = WatermarkStyle.LeicaMinimal,
                title = stringResource(R.string.leica_minimal),
                subtitle = stringResource(R.string.red_dot_clean_metadata),
                selected = state.exportSettings.watermarkStyle == WatermarkStyle.LeicaMinimal,
                modifier = Modifier.weight(1f)
            ) {
                state.exportSettings = state.exportSettings.copy(watermarkStyle = WatermarkStyle.LeicaMinimal)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            WatermarkTemplateCard(
                style = WatermarkStyle.AppleMinimal,
                title = stringResource(R.string.apple_minimal),
                subtitle = stringResource(R.string.small_mark_clean_metadata),
                selected = state.exportSettings.watermarkStyle == WatermarkStyle.AppleMinimal,
                modifier = Modifier.weight(1f)
            ) {
                state.exportSettings = state.exportSettings.copy(watermarkStyle = WatermarkStyle.AppleMinimal)
            }
        }
    }
}

@Composable
private fun WatermarkPreviewCard(style: WatermarkStyle) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .padding(12.dp)
    ) {
        WatermarkPreview(style, large = true, modifier = Modifier.fillMaxWidth().aspectRatio(0.78f))
    }
}

@Composable
private fun WatermarkTemplateCard(
    style: WatermarkStyle,
    title: String,
    subtitle: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = if (selected) 0.14f else 0.07f))
            .clickable(onClick = onClick)
            .padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        WatermarkPreview(style = style, large = false, modifier = Modifier.fillMaxWidth().aspectRatio(1f))
        Text(title, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
        Text(subtitle, color = Color.White.copy(alpha = 0.5f), fontSize = 11.sp, lineHeight = 14.sp)
    }
}

@Composable
private fun WatermarkPreview(style: WatermarkStyle, large: Boolean, modifier: Modifier = Modifier) {
    Canvas(
        modifier = modifier
            .clip(RoundedCornerShape(if (large) 12.dp else 8.dp))
            .background(if (style == WatermarkStyle.None) Color.White.copy(alpha = 0.05f) else Color.White)
    ) {
        val pad = size.minDimension * if (large) 0.06f else 0.05f
        val footer = if (style == WatermarkStyle.None) 0f else size.height * if (large) 0.15f else 0.16f
        val imageRect = Size(size.width - pad * 2f, size.height - pad * 2f - footer)
        val imageTopLeft = Offset(pad, pad)
        drawRoundRect(
            brush = Brush.linearGradient(
                colors = listOf(Color(0xFF203437), Color(0xFF6F8E7D), Color(0xFFE5C184)),
                start = imageTopLeft,
                end = Offset(size.width - pad, size.height - pad - footer)
            ),
            topLeft = imageTopLeft,
            size = imageRect,
            cornerRadius = CornerRadius(size.minDimension * 0.06f)
        )
        drawLine(
            color = Color.White.copy(alpha = 0.28f),
            start = Offset(pad * 2f, pad + imageRect.height * 0.32f),
            end = Offset(size.width - pad * 2f, pad + imageRect.height * 0.32f),
            strokeWidth = 2f,
            pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 8f))
        )

        if (style != WatermarkStyle.None) {
            val brandSize = if (large) size.height * 0.065f else size.height * 0.055f
            val detailSize = if (large) size.height * 0.03f else size.height * 0.026f
            drawIntoCanvas { canvas ->
                val detailPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                    color = android.graphics.Color.rgb(86, 86, 86)
                    textAlign = android.graphics.Paint.Align.CENTER
                    textSize = detailSize
                    letterSpacing = 0.03f
                }
                when (style) {
                    WatermarkStyle.FilmBorder -> {
                        detailPaint.textAlign = android.graphics.Paint.Align.LEFT
                        detailPaint.color = android.graphics.Color.rgb(18, 18, 18)
                        detailPaint.typeface = android.graphics.Typeface.create(android.graphics.Typeface.SANS_SERIF, android.graphics.Typeface.BOLD)
                        canvas.nativeCanvas.drawText("SONY", pad * 1.2f, size.height - footer * 0.52f, detailPaint)
                        detailPaint.color = android.graphics.Color.rgb(86, 86, 86)
                        detailPaint.typeface = android.graphics.Typeface.create(android.graphics.Typeface.SANS_SERIF, android.graphics.Typeface.NORMAL)
                        canvas.nativeCanvas.drawText("35mm f/2.8 1/250s ISO 100", pad * 1.2f, size.height - footer * 0.26f, detailPaint)
                    }
                    WatermarkStyle.HasselbladMinimal -> {
                        val brandPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                            color = android.graphics.Color.rgb(18, 18, 18)
                            textAlign = android.graphics.Paint.Align.CENTER
                            typeface = android.graphics.Typeface.create(android.graphics.Typeface.SERIF, android.graphics.Typeface.ITALIC)
                            textSize = brandSize
                            textSkewX = -0.08f
                            letterSpacing = 0.04f
                        }
                        canvas.nativeCanvas.drawText("Hasselblad", size.width / 2f, size.height - footer * 0.52f, brandPaint)
                        canvas.nativeCanvas.drawText("200mm f/2.8  1/250s  ISO 100", size.width / 2f, size.height - footer * 0.26f, detailPaint)
                    }
                    WatermarkStyle.LeicaMinimal -> {
                        val dotRadius = footer * 0.2f
                        val dotX = pad + dotRadius * 1.45f
                        val dotY = size.height - footer * 0.5f
                        val redPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                            color = android.graphics.Color.rgb(220, 0, 18)
                        }
                        canvas.nativeCanvas.drawCircle(dotX, dotY, dotRadius, redPaint)
                        val logoPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                            color = android.graphics.Color.WHITE
                            textAlign = android.graphics.Paint.Align.CENTER
                            typeface = android.graphics.Typeface.create(android.graphics.Typeface.SERIF, android.graphics.Typeface.ITALIC)
                            textSize = dotRadius * 0.58f
                            textSkewX = -0.1f
                        }
                        canvas.nativeCanvas.drawText("Leica", dotX, dotY + dotRadius * 0.18f, logoPaint)
                        detailPaint.textAlign = android.graphics.Paint.Align.LEFT
                        canvas.nativeCanvas.drawText("LEICA CAMERA", dotX + dotRadius * 1.7f, size.height - footer * 0.52f, detailPaint)
                        canvas.nativeCanvas.drawText("200mm f/2.8  ISO 100", dotX + dotRadius * 1.7f, size.height - footer * 0.28f, detailPaint)
                    }
                    WatermarkStyle.AppleMinimal -> {
                        detailPaint.textAlign = android.graphics.Paint.Align.LEFT
                        detailPaint.color = android.graphics.Color.rgb(18, 18, 18)
                        detailPaint.typeface = android.graphics.Typeface.create(android.graphics.Typeface.SANS_SERIF, android.graphics.Typeface.BOLD)
                        canvas.nativeCanvas.drawText("Apple", pad * 1.6f, size.height - footer * 0.42f, detailPaint)
                        detailPaint.color = android.graphics.Color.rgb(96, 96, 96)
                        detailPaint.typeface = android.graphics.Typeface.create(android.graphics.Typeface.SANS_SERIF, android.graphics.Typeface.NORMAL)
                        canvas.nativeCanvas.drawText("iPhone Pro   200mm f/2.8 ISO 100", size.width * 0.38f, size.height - footer * 0.42f, detailPaint)
                    }
                    WatermarkStyle.None -> Unit
                }
            }
        }
    }
}
