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
    Export(R.string.export)
}

enum class LutCategory(val labelRes: Int) {
    Portrait(R.string.category_portrait),
    Landscape(R.string.category_landscape),
    Film(R.string.category_film),
    BlackWhite(R.string.category_black_white),
    Commercial(R.string.category_commercial),
    Custom(R.string.category_custom)
}

data class Photo(
    val id: String,
    val fileName: String,
    val sessionName: String,
    val status: PhotoStatus,
    val isFavorite: Boolean,
    val isSelected: Boolean,
    val rating: Int,
    val appliedLutId: String?,
    val lutIntensity: Float,
    val recommendedLutIds: List<String>,
    val palette: List<Color>
)

data class LutPreset(
    val id: String,
    val name: String,
    val category: LutCategory,
    val tags: List<String>,
    val previewColors: List<Color>,
    val isFavorite: Boolean,
    val usageCount: Int,
    val confidence: Int?
)

data class ExportSettings(
    val format: String = "JPG",
    val size: String = "2048px",
    val quality: String = "High",
    val preserveExif: Boolean = true
)
