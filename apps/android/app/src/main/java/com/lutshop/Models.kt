package com.lutshop

import androidx.compose.ui.graphics.Color

enum class PhotoStatus(val labelRes: Int) {
    Raw(R.string.raw_status),
    Edited(R.string.edited),
    Exported(R.string.exported)
}

enum class MainTab(val labelRes: Int) {
    Gallery(R.string.gallery),
    Preview(R.string.preview),
    Luts(R.string.luts),
    Watermark(R.string.watermark),
    Export(R.string.export)
}

enum class PhotoSortOption(val labelRes: Int) {
    FileName(R.string.sort_filename),
    Newest(R.string.sort_newest),
    Rating(R.string.sort_rating)
}

enum class LutCategory(val labelRes: Int) {
    Portrait(R.string.category_portrait),
    Landscape(R.string.category_landscape),
    Film(R.string.category_film),
    BlackWhite(R.string.category_black_white),
    Commercial(R.string.category_commercial),
    Custom(R.string.category_custom)
}

enum class WatermarkStyle(val labelRes: Int) {
    None(R.string.no_watermark),
    FilmBorder(R.string.film_border),
    HasselbladMinimal(R.string.hasselblad_minimal),
    LeicaMinimal(R.string.leica_minimal),
    AppleMinimal(R.string.apple_minimal)
}

data class Photo(
    val id: String,
    val fileName: String,
    val uri: String,
    val localPath: String?,
    val importedAt: Long,
    val sessionName: String,
    val status: PhotoStatus,
    val isFavorite: Boolean,
    val isSelected: Boolean,
    val rating: Int,
    val appliedLutId: String?,
    val lutIntensity: Float,
    val recommendedLutIds: List<String>,
    val palette: List<Color>,
    val renderedImagePath: String? = null
) {
    val formatBadgeText: String
        get() {
            val ext = sequenceOf(fileName, localPath, uri)
                .mapNotNull { value -> value?.substringBefore('?')?.substringAfterLast('.', "")?.lowercase() }
                .firstOrNull { it.isNotBlank() }
                .orEmpty()
            return when (ext) {
                "raw", "dng", "arw", "cr2", "cr3", "nef", "nrw", "orf", "pef", "raf", "rw2", "srw" -> "RAW"
                "jpg", "jpeg" -> "JPG"
                "png" -> "PNG"
                "heic", "heif" -> "HEIC"
                "tif", "tiff" -> "TIFF"
                "" -> "IMG"
                else -> ext.uppercase()
            }
        }
}

data class LutPreset(
    val id: String,
    val name: String,
    val category: LutCategory,
    val tags: List<String>,
    val previewColors: List<Color>,
    val isFavorite: Boolean,
    val usageCount: Int,
    val confidence: Int?,
    val sourceFileName: String? = null,
    val isBundled: Boolean = false,
    val userPath: String? = null,
    val cubeSize: Int = 0,
    val cubeEntryCount: Int = 0
)

data class LutCategoryGroup(
    val name: String,
    val isSystem: Boolean
)

data class ExportSettings(
    val format: String = "JPG",
    val size: String = "2048px",
    val quality: String = "High",
    val preserveExif: Boolean = true,
    val watermarkStyle: WatermarkStyle = WatermarkStyle.None
)
