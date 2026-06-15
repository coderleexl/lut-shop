package com.lutshop.core

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.ui.graphics.Color
import com.lutshop.ExportSettings
import com.lutshop.LutCategory
import com.lutshop.LutCategoryGroup
import com.lutshop.LutPreset
import com.lutshop.Photo
import com.lutshop.PhotoStatus
import java.io.File
import java.io.FileOutputStream

object NativeLutShopCore {
    init { System.loadLibrary("lutshop_jni") }

    @JvmStatic external fun nativeVersion(): String

    @JvmStatic external fun nativeApplyLut(
        cubeText: String,
        pixels: IntArray,
        width: Int,
        height: Int,
        stride: Int,
        intensity: Float
    ): Int

    @JvmStatic external fun nativeParseCubeTitle(cubeText: String): String

    @JvmStatic external fun nativeParseCubeMetadata(cubeText: String): IntArray
}

object LutRenderer {
    fun applyLutToImage(
        context: Context,
        imagePath: String,
        cubeText: String,
        intensity: Float,
        outputPath: String
    ): Boolean {
        val options = BitmapFactory.Options().apply { inMutable = true }
        val bitmap = BitmapFactory.decodeFile(imagePath, options) ?: return false

        val width = bitmap.width
        val height = bitmap.height
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        val result = NativeLutShopCore.nativeApplyLut(cubeText, pixels, width, height, width * 4, intensity)
        if (result != 0) {
            bitmap.recycle()
            return false
        }

        bitmap.setPixels(pixels, 0, width, 0, 0, width, height)

        val outFile = File(outputPath)
        outFile.parentFile?.mkdirs()
        FileOutputStream(outFile).use { stream ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 92, stream)
        }
        bitmap.recycle()
        return true
    }

    fun loadCubeText(context: Context, assetPath: String): String? {
        return try {
            context.assets.open(assetPath).bufferedReader().readText()
        } catch (_: Exception) {
            null
        }
    }
}

interface LutShopCoreBridge {
    fun loadBundledLuts(context: Context): List<LutPreset>
    fun applyLut(lut: LutPreset, intensity: Float, photos: List<Photo>): List<Photo>
    fun markExported(photos: List<Photo>, settings: ExportSettings): List<Photo>
    fun getSystemGroups(): List<LutCategoryGroup>
}

private val PRESET_COLORS = listOf(
    listOf(Color(0xFF8E6249), Color(0xFFE1A66D), Color.White),
    listOf(Color(0xFF426C86), Color(0xFF38A6A5), Color(0xFF5D7B43)),
    listOf(Color(0xFFC77E36), Color(0xFFE5BE55), Color(0xFF5A3924))
)

class CoreBridge : LutShopCoreBridge {
    override fun getSystemGroups(): List<LutCategoryGroup> = listOf(
        LutCategoryGroup("Portrait", isSystem = true),
        LutCategoryGroup("Landscape", isSystem = true),
        LutCategoryGroup("Film", isSystem = true),
        LutCategoryGroup("B&W", isSystem = true),
        LutCategoryGroup("Commercial", isSystem = true)
    )

    override fun loadBundledLuts(context: Context): List<LutPreset> {
        val assetDir = "luts"
        val cubeFiles = try {
            context.assets.list(assetDir)?.filter { it.endsWith(".cube") } ?: emptyList()
        } catch (_: Exception) {
            emptyList()
        }

        if (cubeFiles.isEmpty()) return emptyList()

        return cubeFiles.mapIndexed { index, fileName ->
            val cubeText = LutRenderer.loadCubeText(context, "$assetDir/$fileName") ?: return@mapIndexed null
            val title = NativeLutShopCore.nativeParseCubeTitle(cubeText)
            val name = title.ifBlank { fileName.removeSuffix(".cube") }
            val sourceFileName = fileName.removeSuffix(".cube")
            val colors = PRESET_COLORS.getOrElse(index) { PRESET_COLORS[0] }

            // Parse cube metadata
            val meta = NativeLutShopCore.nativeParseCubeMetadata(cubeText)
            val cubeSize = if (meta.size >= 3) meta[1] else 0
            val entryCount = if (meta.size >= 3) meta[2] else 0

            LutPreset(
                id = "bundled_${index + 1}",
                name = name,
                category = LutCategory.entries[index % 5],
                tags = emptyList(),
                previewColors = colors,
                isFavorite = false,
                usageCount = 0,
                confidence = null,
                sourceFileName = sourceFileName,
                isBundled = true,
                cubeSize = cubeSize,
                cubeEntryCount = entryCount
            )
        }.filterNotNull()
    }

    override fun applyLut(lut: LutPreset, intensity: Float, photos: List<Photo>): List<Photo> =
        photos.map {
            it.copy(
                status = PhotoStatus.Edited,
                appliedLutId = lut.id,
                lutIntensity = intensity.coerceIn(0f, 1f)
            )
        }

    override fun markExported(photos: List<Photo>, settings: ExportSettings): List<Photo> =
        photos.map { it.copy(status = PhotoStatus.Exported) }
}
