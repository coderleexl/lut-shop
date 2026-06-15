package com.lutshop.export

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.media.ExifInterface
import com.lutshop.Photo
import com.lutshop.WatermarkStyle
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

object WatermarkRenderer {
    fun render(image: Bitmap, photo: Photo, style: WatermarkStyle): Bitmap {
        val exif = ExifSummary.fromPhoto(photo)
        return when (style) {
            WatermarkStyle.None -> image
            WatermarkStyle.FilmBorder -> renderFilmBorder(image, exif)
            WatermarkStyle.HasselbladMinimal -> renderHasselblad(image, exif)
            WatermarkStyle.LeicaMinimal -> renderLeica(image, exif)
            WatermarkStyle.AppleMinimal -> renderApple(image, exif)
        }
    }

    private fun renderFilmBorder(image: Bitmap, exif: ExifSummary): Bitmap {
        return renderFramed(image, WatermarkStyle.FilmBorder) { canvas, rect, isPortrait ->
            drawFilmFooter(canvas, rect, exif, isPortrait)
        }
    }

    private fun renderHasselblad(image: Bitmap, exif: ExifSummary): Bitmap {
        return renderFramed(image, WatermarkStyle.HasselbladMinimal) { canvas, rect, isPortrait ->
            drawHasselbladFooter(canvas, rect, exif, isPortrait)
        }
    }

    private fun renderLeica(image: Bitmap, exif: ExifSummary): Bitmap {
        return renderFramed(image, WatermarkStyle.LeicaMinimal) { canvas, rect, isPortrait ->
            drawLeicaFooter(canvas, rect, exif, isPortrait)
        }
    }

    private fun renderApple(image: Bitmap, exif: ExifSummary): Bitmap {
        return renderFramed(image, WatermarkStyle.AppleMinimal) { canvas, rect, _ ->
            drawAppleFooter(canvas, rect, exif)
        }
    }

    private fun renderFramed(
        image: Bitmap,
        style: WatermarkStyle,
        drawFooter: (Canvas, RectF, Boolean) -> Unit
    ): Bitmap {
        val imageWidth = image.width
        val imageHeight = image.height
        val shortSide = min(imageWidth, imageHeight).toFloat()
        val isPortrait = imageHeight >= imageWidth
        val padding = outerPadding(style, shortSide)
        val footerHeight = footerHeight(style, imageWidth.toFloat(), isPortrait)
        val radius = (shortSide * 0.095f * 0.22f).coerceIn(0f, shortSide * 0.08f)

        val outputWidth = (imageWidth + padding * 2f).toInt()
        val outputHeight = (imageHeight + padding + footerHeight).toInt()
        val output = Bitmap.createBitmap(outputWidth, outputHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        canvas.drawColor(backgroundColor(style))

        val imageRect = RectF(padding, padding, padding + imageWidth, padding + imageHeight)
        val imagePath = Path().apply {
            addRoundRect(imageRect, radius, radius, Path.Direction.CW)
        }
        canvas.save()
        canvas.clipPath(imagePath)
        canvas.drawBitmap(image, null, imageRect, Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
        canvas.restore()

        drawFooter(canvas, RectF(padding, padding + imageHeight, padding + imageWidth, padding + imageHeight + footerHeight), isPortrait)

        return output
    }

    private fun outerPadding(style: WatermarkStyle, shortSide: Float): Float {
        return when (style) {
            WatermarkStyle.None -> 0f
            WatermarkStyle.FilmBorder -> (shortSide * 0.018f).coerceIn(10f, 42f)
            WatermarkStyle.HasselbladMinimal -> (shortSide * 0.045f).coerceIn(22f, 86f)
            WatermarkStyle.LeicaMinimal -> (shortSide * 0.04f).coerceIn(20f, 78f)
            WatermarkStyle.AppleMinimal -> (shortSide * 0.026f).coerceIn(14f, 52f)
        }
    }

    private fun footerHeight(style: WatermarkStyle, imageWidth: Float, isPortrait: Boolean): Float {
        return when (style) {
            WatermarkStyle.None -> 0f
            WatermarkStyle.FilmBorder -> (imageWidth * if (isPortrait) 0.17f else 0.095f).coerceIn(92f, 260f)
            WatermarkStyle.HasselbladMinimal -> (imageWidth * if (isPortrait) 0.2f else 0.12f).coerceIn(110f, 310f)
            WatermarkStyle.LeicaMinimal -> (imageWidth * if (isPortrait) 0.18f else 0.1f).coerceIn(96f, 280f)
            WatermarkStyle.AppleMinimal -> (imageWidth * if (isPortrait) 0.13f else 0.075f).coerceIn(70f, 190f)
        }
    }

    private fun backgroundColor(style: WatermarkStyle): Int {
        return when (style) {
            WatermarkStyle.None,
            WatermarkStyle.FilmBorder,
            WatermarkStyle.HasselbladMinimal,
            WatermarkStyle.LeicaMinimal -> Color.WHITE
            WatermarkStyle.AppleMinimal -> Color.rgb(248, 248, 245)
        }
    }

    private fun drawHasselbladFooter(canvas: Canvas, rect: RectF, exif: ExifSummary, isPortrait: Boolean) {
        val brandPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(18, 18, 18)
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.SERIF, Typeface.ITALIC)
            textSize = (rect.height() * if (isPortrait) 0.22f else 0.25f).coerceIn(28f, 76f)
            letterSpacing = 0.04f
            textSkewX = -0.08f
        }
        val detailPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(86, 86, 86)
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL)
            textSize = (rect.height() * if (isPortrait) 0.12f else 0.14f).coerceIn(18f, 36f)
            letterSpacing = 0.03f
        }

        val centerX = rect.centerX()
        canvas.drawText(exif.camera, centerX, rect.top + rect.height() * 0.36f, brandPaint)

        val detail = exif.detail
        drawFittedText(
            canvas = canvas,
            text = detail,
            rect = RectF(rect.left + rect.width() * 0.07f, rect.top + rect.height() * 0.58f, rect.right - rect.width() * 0.07f, rect.top + rect.height() * 0.82f),
            paint = detailPaint
        )
    }

    private fun drawFilmFooter(canvas: Canvas, rect: RectF, exif: ExifSummary, isPortrait: Boolean) {
        val contentTop = rect.top + rect.height() * 0.14f
        val contentHeight = rect.height() * 0.68f
        val gap = (rect.width() * 0.02f).coerceIn(12f, 46f)
        val logoSize = (contentHeight * 0.96f).coerceIn(42f, rect.width() * 0.13f)
        val rightWidth = (rect.width() * 0.31f).coerceIn(rect.width() * 0.25f, rect.width() * 0.38f)
        val rightX = rect.right - rightWidth
        val separatorX = rightX - gap * 0.72f
        val logoRect = RectF(separatorX - gap - logoSize, contentTop + (contentHeight - logoSize) / 2f, separatorX - gap, contentTop + (contentHeight + logoSize) / 2f)
        val leftWidth = (logoRect.left - rect.left - gap).coerceAtLeast(1f)

        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(30, 0, 0, 0)
        }.also {
            canvas.drawRoundRect(RectF(separatorX, contentTop + contentHeight * 0.08f, separatorX + 2f, contentTop + contentHeight * 0.92f), 1f, 1f, it)
        }

        val logoPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(32, 32, 32)
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
            textSize = logoSize * 0.22f
            letterSpacing = 0.04f
        }
        drawFittedText(canvas, exif.logoText.uppercase(), logoRect, logoPaint)

        val topPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(28, 28, 28)
            textAlign = Paint.Align.LEFT
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
            textSize = (rect.height() * if (isPortrait) 0.18f else 0.2f).coerceIn(14f, 34f)
        }
        val bottomPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(82, 82, 82)
            textAlign = Paint.Align.LEFT
            textSize = (rect.height() * if (isPortrait) 0.13f else 0.15f).coerceIn(10f, 25f)
        }
        drawFittedText(canvas, exif.camera, RectF(rect.left, contentTop + contentHeight * 0.08f, rect.left + leftWidth, contentTop + contentHeight * 0.44f), topPaint, Paint.Align.LEFT)
        drawFittedText(canvas, exif.lens, RectF(rect.left, contentTop + contentHeight * 0.54f, rect.left + leftWidth, contentTop + contentHeight * 0.84f), bottomPaint, Paint.Align.LEFT)

        val rightTopPaint = Paint(topPaint).apply { textAlign = Paint.Align.RIGHT }
        val rightBottomPaint = Paint(bottomPaint).apply { textAlign = Paint.Align.RIGHT }
        drawFittedText(canvas, exif.exposure, RectF(rightX, contentTop + contentHeight * 0.08f, rect.right, contentTop + contentHeight * 0.44f), rightTopPaint, Paint.Align.RIGHT)
        drawFittedText(canvas, exif.date, RectF(rightX, contentTop + contentHeight * 0.54f, rect.right, contentTop + contentHeight * 0.84f), rightBottomPaint, Paint.Align.RIGHT)
    }

    private fun drawLeicaFooter(canvas: Canvas, rect: RectF, exif: ExifSummary, isPortrait: Boolean) {
        val dotSize = (rect.height() * 0.42f).coerceIn(34f, 74f)
        val dotRadius = dotSize / 2f
        val dotRect = RectF(rect.left, rect.centerY() - dotRadius, rect.left + dotSize, rect.centerY() + dotRadius)
        val dotCenter = OffsetCompat(dotRect.centerX(), dotRect.centerY())
        val redPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(220, 0, 18) }
        canvas.drawCircle(dotCenter.x, dotCenter.y, dotRadius, redPaint)
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.SERIF, Typeface.ITALIC)
            textSize = dotSize * 0.22f
            textSkewX = -0.1f
        }.also {
            drawFittedText(
                canvas = canvas,
                text = exif.logoText.uppercase(),
                rect = RectF(
                    dotRect.left + dotSize * 0.12f,
                    dotRect.top + dotSize * 0.28f,
                    dotRect.right - dotSize * 0.12f,
                    dotRect.bottom - dotSize * 0.28f
                ),
                paint = it
            )
        }

        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(18, 18, 18)
            textAlign = Paint.Align.LEFT
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
            textSize = (rect.height() * if (isPortrait) 0.16f else 0.18f).coerceIn(13f, 30f)
            letterSpacing = 0.04f
        }
        val detailPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(86, 86, 86)
            textAlign = Paint.Align.LEFT
            textSize = (rect.height() * if (isPortrait) 0.11f else 0.13f).coerceIn(9f, 21f)
        }
        val textLeft = dotRect.right + (rect.width() * 0.025f).coerceIn(12f, 34f)
        val title = exif.camera.uppercase()
        drawFittedText(
            canvas,
            title,
            RectF(textLeft, rect.top + rect.height() * 0.25f, rect.right, rect.top + rect.height() * 0.5f),
            titlePaint,
            Paint.Align.LEFT
        )
        drawFittedText(
            canvas,
            exif.detail,
            RectF(textLeft, rect.top + rect.height() * 0.53f, rect.right, rect.top + rect.height() * 0.77f),
            detailPaint,
            Paint.Align.LEFT
        )
    }

    private fun drawAppleFooter(canvas: Canvas, rect: RectF, exif: ExifSummary) {
        val markPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(18, 18, 18)
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
            textSize = (rect.height() * 0.18f).coerceIn(12f, 26f)
        }
        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(18, 18, 18)
            textAlign = Paint.Align.LEFT
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
            textSize = (rect.height() * 0.18f).coerceIn(12f, 26f)
        }
        val detailPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(96, 96, 96)
            textAlign = Paint.Align.LEFT
            textSize = (rect.height() * 0.13f).coerceIn(9f, 18f)
        }
        val logoSize = (rect.height() * 0.32f).coerceIn(18f, 42f)
        val logoRect = RectF(rect.left, rect.top + rect.height() * 0.34f, rect.left + logoSize, rect.top + rect.height() * 0.34f + logoSize)
        drawFittedText(canvas, exif.logoText.uppercase(), logoRect, markPaint)

        val textLeft = logoRect.right + (rect.width() * 0.018f).coerceIn(8f, 22f)
        drawFittedText(
            canvas,
            exif.camera,
            RectF(textLeft, rect.top + rect.height() * 0.27f, rect.right, rect.top + rect.height() * 0.51f),
            titlePaint,
            Paint.Align.LEFT
        )
        drawFittedText(
            canvas,
            exif.detail,
            RectF(textLeft, rect.top + rect.height() * 0.53f, rect.right, rect.top + rect.height() * 0.75f),
            detailPaint,
            Paint.Align.LEFT
        )
    }

    private fun drawFittedText(canvas: Canvas, text: String, rect: RectF, paint: Paint, align: Paint.Align = Paint.Align.CENTER) {
        val fittedPaint = Paint(paint)
        fittedPaint.textAlign = align
        while (fittedPaint.textSize > 10f && fittedPaint.measureText(text) > rect.width()) {
            fittedPaint.textSize -= 1f
        }
        val fontMetrics = fittedPaint.fontMetrics
        val baseline = rect.centerY() - (fontMetrics.ascent + fontMetrics.descent) / 2f
        val x = when (align) {
            Paint.Align.LEFT -> rect.left
            Paint.Align.RIGHT -> rect.right
            else -> rect.centerX()
        }
        canvas.drawText(ellipsizeMiddle(text, fittedPaint, rect.width()), x, baseline, fittedPaint)
    }

    private fun ellipsizeMiddle(text: String, paint: Paint, maxWidth: Float): String {
        if (paint.measureText(text) <= maxWidth) return text
        val ellipsis = "..."
        var leftCount = text.length / 2
        var rightStart = text.length / 2
        while (leftCount > 4 && rightStart < text.length - 4) {
            val candidate = text.take(leftCount) + ellipsis + text.drop(rightStart)
            if (paint.measureText(candidate) <= maxWidth) return candidate
            leftCount -= 1
            rightStart += 1
        }
        return text.take(max(1, min(text.length, 12))) + ellipsis
    }

    private data class OffsetCompat(val x: Float, val y: Float)

    private data class ExifSummary(
        val make: String,
        val model: String,
        val lens: String,
        val exposure: String,
        val date: String
    ) {
        val camera: String = listOf(make, model).filter { it.isNotBlank() }.distinct().joinToString(" ").ifBlank { "SONY ILCE-7M4" }
        val logoText: String = make.ifBlank { camera.substringBefore(" ") }.take(5)
        val detail: String = listOf(lens, exposure, date).filter { it.isNotBlank() }.joinToString("   ")

        companion object {
            fun fromPhoto(photo: Photo): ExifSummary {
                val fallbackDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(photo.importedAt))
                val fallback = ExifSummary(
                    make = "SONY",
                    model = "ILCE-7M4",
                    lens = "FE 70-200mm F2.8 GM OSS II",
                    exposure = "200mm f/2.8 1/250s ISO 100",
                    date = fallbackDate
                )
                val path = photo.localPath ?: return fallback
                return runCatching {
                    val exif = ExifInterface(path)
                    val make = exif.getAttribute(ExifInterface.TAG_MAKE).orEmpty().trim()
                    val model = exif.getAttribute(ExifInterface.TAG_MODEL).orEmpty().trim()
                    val lens = exif.getAttribute("LensModel").orEmpty().trim()
                    val focal = exif.getAttributeDouble(ExifInterface.TAG_FOCAL_LENGTH, Double.NaN)
                        .takeUnless { it.isNaN() }
                        ?.let { "${it.toInt()}mm" }
                        .orEmpty()
                    val aperture = exif.getAttributeDouble(ExifInterface.TAG_F_NUMBER, Double.NaN)
                        .takeUnless { it.isNaN() }
                        ?.let { "f/${String.format(Locale.US, "%.1f", it)}" }
                        .orEmpty()
                    val exposureTime = exif.getAttributeDouble(ExifInterface.TAG_EXPOSURE_TIME, Double.NaN)
                        .takeUnless { it.isNaN() }
                        ?.let { if (it > 0 && it < 1) "1/${(1 / it).toInt()}s" else "${String.format(Locale.US, "%.1f", it)}s" }
                        .orEmpty()
                    val iso = (exif.getAttribute("PhotographicSensitivity") ?: exif.getAttribute("ISOSpeedRatings"))
                        ?.let { "ISO $it" }
                        .orEmpty()
                    val date = exif.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL)
                        ?.take(10)
                        ?.replace(':', '-')
                        ?: fallbackDate
                    val exposure = listOf(focal, aperture, exposureTime, iso).filter { it.isNotBlank() }.joinToString(" ")
                    ExifSummary(
                        make = make.ifBlank { fallback.make },
                        model = model.ifBlank { fallback.model },
                        lens = lens.ifBlank { fallback.lens },
                        exposure = exposure.ifBlank { fallback.exposure },
                        date = date
                    )
                }.getOrDefault(fallback)
            }
        }
    }
}
