package com.lutshop.core

import androidx.compose.ui.graphics.Color
import com.lutshop.ExportSettings
import com.lutshop.LutCategory
import com.lutshop.LutPreset
import com.lutshop.Photo
import com.lutshop.PhotoStatus

interface LutShopCoreBridge {
    fun loadInitialPhotos(): List<Photo>
    fun loadLuts(): List<LutPreset>
    fun recommendLuts(photo: Photo, luts: List<LutPreset>): List<LutPreset>
    fun applyLut(lut: LutPreset, intensity: Float, photos: List<Photo>): List<Photo>
    fun markExported(photos: List<Photo>, settings: ExportSettings): List<Photo>
}

class MockLutShopCoreBridge : LutShopCoreBridge {
    override fun loadInitialPhotos(): List<Photo> = listOf(
        photo("p1", "IMG_0123.CR3", PhotoStatus.Raw, true, false, 3, listOf("l1", "l3"), listOf(Color(0xFF6F7F3D), Color(0xFF2E3D1F), Color.Black)),
        photo("p2", "IMG_0124.CR3", PhotoStatus.Raw, false, true, 0, listOf("l2"), listOf(Color(0xFF4A6B89), Color(0xFF0F2933), Color.Black)),
        photo("p3", "IMG_0125.CR3", PhotoStatus.Raw, true, false, 5, listOf("l3"), listOf(Color(0xFFD18B4D), Color(0xFF62402C), Color.Black)),
        photo("p4", "IMG_0126.CR3", PhotoStatus.Raw, false, true, 0, listOf("l4"), listOf(Color(0xFF8C8B82), Color(0xFF3C352E), Color.Black)),
        photo("p5", "IMG_0127.CR3", PhotoStatus.Raw, false, true, 4, listOf("l1"), listOf(Color(0xFFB9B9B9), Color(0xFF252525), Color.Black)),
        photo("p6", "IMG_0128.CR3", PhotoStatus.Edited, false, false, 0, listOf("l2"), listOf(Color(0xFF9A633D), Color(0xFF2E1F18), Color.Black)),
        photo("p7", "IMG_0129.CR3", PhotoStatus.Raw, false, true, 0, listOf("l5"), listOf(Color.Black, Color(0xFF444444), Color(0xFF8C5E2B))),
        photo("p8", "IMG_0130.CR3", PhotoStatus.Raw, true, false, 5, listOf("l3"), listOf(Color(0xFFC19755), Color(0xFF392413), Color.Black)),
        photo("p9", "IMG_0131.CR3", PhotoStatus.Exported, false, false, 0, listOf("l2"), listOf(Color(0xFFD8B45B), Color(0xFF516F35), Color(0xFF1B1D1E))),
        photo("p10", "IMG_0132.CR3", PhotoStatus.Raw, false, true, 0, listOf("l4"), listOf(Color(0xFF617D9B), Color(0xFF23272A), Color.Black)),
        photo("p11", "IMG_0133.CR3", PhotoStatus.Raw, false, true, 0, listOf("l1"), listOf(Color(0xFFB5794E), Color(0xFF211411), Color.Black)),
        photo("p12", "IMG_0134.CR3", PhotoStatus.Raw, true, false, 0, listOf("l2"), listOf(Color(0xFFD89C48), Color(0xFFB86325), Color(0xFF3C2411)))
    )

    override fun loadLuts(): List<LutPreset> = listOf(
        LutPreset("l1", "Clean Portrait", LutCategory.Portrait, listOf("skin", "soft", "studio"), listOf(Color(0xFF8E6249), Color(0xFFE1A66D), Color.White), true, 68, 94),
        LutPreset("l2", "Alpine Teal", LutCategory.Landscape, listOf("mountain", "cool", "travel"), listOf(Color(0xFF426C86), Color(0xFF38A6A5), Color(0xFF5D7B43)), false, 41, 88),
        LutPreset("l3", "Gold Hour Film", LutCategory.Film, listOf("warm", "sunset", "grain"), listOf(Color(0xFFC77E36), Color(0xFFE5BE55), Color(0xFF5A3924)), true, 92, 91),
        LutPreset("l4", "Mono Contrast", LutCategory.BlackWhite, listOf("street", "mono", "contrast"), listOf(Color.Black, Color.Gray, Color.White), false, 23, null),
        LutPreset("l5", "Commercial Deep", LutCategory.Commercial, listOf("product", "car", "deep"), listOf(Color.Black, Color(0xFF4C4C4C), Color(0xFFC17729)), false, 36, null)
    )

    override fun recommendLuts(photo: Photo, luts: List<LutPreset>): List<LutPreset> {
        val ids = photo.recommendedLutIds.toSet()
        return luts.filter { it.id in ids }.sortedByDescending { it.confidence ?: 0 }
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

    private fun photo(
        id: String,
        fileName: String,
        status: PhotoStatus,
        selected: Boolean,
        favorite: Boolean,
        rating: Int,
        recommendations: List<String>,
        palette: List<Color>
    ) = Photo(
        id = id,
        fileName = fileName,
        sessionName = "2026-06-08 Studio Shoot",
        status = status,
        isFavorite = favorite,
        isSelected = selected,
        rating = rating,
        appliedLutId = null,
        lutIntensity = 0.72f,
        recommendedLutIds = recommendations,
        palette = palette
    )
}
