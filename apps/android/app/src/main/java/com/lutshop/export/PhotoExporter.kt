package com.lutshop.export

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.provider.MediaStore
import com.lutshop.ExportSettings
import com.lutshop.Photo
import com.lutshop.WatermarkStyle
import com.lutshop.core.LutRenderer
import java.io.File

object PhotoExporter {

    private const val QUALITY_HIGH = 94
    private const val QUALITY_MEDIUM = 82
    private const val QUALITY_LOW = 62

    fun exportPhoto(
        context: Context,
        photo: Photo,
        settings: ExportSettings,
        cubeText: String?,
        onProgress: (Float) -> Unit
    ): Boolean {
        val sourcePath = photo.renderedImagePath ?: photo.localPath ?: return false
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) return false

        onProgress(0.1f)

        // Load source bitmap
        val bitmap = BitmapFactory.decodeFile(sourcePath) ?: return false
        onProgress(0.3f)

        // Resize if needed
        val resized = resizeBitmap(bitmap, settings)
        if (resized !== bitmap) bitmap.recycle()
        onProgress(0.5f)

        // If we have a LUT to apply and no pre-rendered image, render now
        val finalBitmap = if (cubeText != null && photo.renderedImagePath == null && photo.appliedLutId != null) {
            renderLutOnBitmap(context, resized, cubeText, photo.lutIntensity) ?: resized
        } else {
            resized
        }
        onProgress(0.7f)

        val outputBitmap = if (settings.watermarkStyle != WatermarkStyle.None) {
            WatermarkRenderer.render(finalBitmap, photo, settings.watermarkStyle)
        } else {
            finalBitmap
        }

        // Determine output format
        val isPng = settings.format == "PNG"
        val ext = if (isPng) "png" else "jpg"
        val mimeType = if (isPng) "image/png" else "image/jpeg"
        val compressFormat = if (isPng) Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG
        val quality = when (settings.quality) {
            "Low" -> QUALITY_LOW
            "Medium" -> QUALITY_MEDIUM
            else -> QUALITY_HIGH
        }

        val outputName = "${photo.fileName.substringBeforeLast('.')}_lutshop.$ext"

        val contentValues = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, outputName)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/lut-shop")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }

        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
            ?: return false

        return try {
            onProgress(0.85f)
            resolver.openOutputStream(uri)?.use { stream ->
                outputBitmap.compress(compressFormat, quality, stream)
            }
            onProgress(0.95f)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentValues.clear()
                contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)
            }

            onProgress(1f)
            true
        } catch (_: Exception) {
            resolver.delete(uri, null, null)
            false
        } finally {
            if (outputBitmap !== finalBitmap) outputBitmap.recycle()
            if (finalBitmap !== resized) finalBitmap.recycle()
            resized.recycle()
        }
    }

    private fun resizeBitmap(bitmap: Bitmap, settings: ExportSettings): Bitmap {
        val maxDim = when (settings.size) {
            "1080px" -> 1080
            "2048px" -> 2048
            else -> return bitmap // Original
        }
        val w = bitmap.width
        val h = bitmap.height
        if (w <= maxDim && h <= maxDim) return bitmap

        val scale = if (w > h) maxDim.toFloat() / w else maxDim.toFloat() / h
        val newW = (w * scale).toInt()
        val newH = (h * scale).toInt()
        return Bitmap.createScaledBitmap(bitmap, newW, newH, true)
    }

    private fun renderLutOnBitmap(
        context: Context,
        bitmap: Bitmap,
        cubeText: String,
        intensity: Float
    ): Bitmap? {
        val mutable = bitmap.copy(Bitmap.Config.ARGB_8888, true) ?: return null
        val w = mutable.width
        val h = mutable.height
        val pixels = IntArray(w * h)
        mutable.getPixels(pixels, 0, w, 0, 0, w, h)

        val result = com.lutshop.core.NativeLutShopCore.nativeApplyLut(cubeText, pixels, w, h, w * 4, intensity)
        if (result != 0) {
            mutable.recycle()
            return null
        }

        mutable.setPixels(pixels, 0, w, 0, 0, w, h)
        return mutable
    }
}
