package com.lutshop

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import com.lutshop.core.LutShopCoreBridge
import com.lutshop.core.MockLutShopCoreBridge

class LutShopAppState(
    private val bridge: LutShopCoreBridge = MockLutShopCoreBridge()
) : ViewModel() {
    var selectedTab by mutableStateOf(MainTab.Gallery)
    var activeFilter by mutableStateOf<PhotoStatus?>(null)
    var searchText by mutableStateOf("")
    var selectedPhotoId by mutableStateOf<String?>(null)
    var activeLutId by mutableStateOf<String?>(null)
    var lutIntensity by mutableFloatStateOf(0.72f)
    var exportSettings by mutableStateOf(ExportSettings())
    var photos by mutableStateOf(bridge.loadInitialPhotos())
        private set
    var luts by mutableStateOf(bridge.loadLuts())
        private set

    init {
        selectedPhotoId = photos.firstOrNull()?.id
        activeLutId = luts.firstOrNull()?.id
    }

    val filteredPhotos: List<Photo>
        get() = photos.filter {
            val matchesFilter = activeFilter == null || it.status == activeFilter
            val matchesSearch = searchText.isBlank()
                || it.fileName.contains(searchText, ignoreCase = true)
                || it.sessionName.contains(searchText, ignoreCase = true)
            matchesFilter && matchesSearch
        }

    val selectedPhotos: List<Photo>
        get() = photos.filter { it.isSelected }

    val currentPhoto: Photo?
        get() = photos.firstOrNull { it.id == selectedPhotoId } ?: photos.firstOrNull()

    val activeLut: LutPreset?
        get() = luts.firstOrNull { it.id == activeLutId } ?: luts.firstOrNull()

    val recommendedLuts: List<LutPreset>
        get() = currentPhoto?.let { bridge.recommendLuts(it, luts) }.orEmpty()

    fun openPhoto(id: String) {
        selectedPhotoId = id
        selectedTab = MainTab.Preview
    }

    fun toggleSelection(id: String) {
        photos = photos.map { if (it.id == id) it.copy(isSelected = !it.isSelected) else it }
        selectedPhotoId = id
    }

    fun toggleFavorite(id: String) {
        photos = photos.map { if (it.id == id) it.copy(isFavorite = !it.isFavorite) else it }
    }

    fun rateCurrentPhoto(rating: Int) {
        val id = currentPhoto?.id ?: return
        photos = photos.map { if (it.id == id) it.copy(rating = rating.coerceIn(0, 5)) else it }
    }

    fun applyActiveLutToCurrentPhoto() {
        val photo = currentPhoto ?: return
        val lut = activeLut ?: return
        val edited = bridge.applyLut(lut, lutIntensity, listOf(photo)).first()
        photos = photos.map { if (it.id == edited.id) edited else it }
    }

    fun applyActiveLutToSelection() {
        val lut = activeLut ?: return
        val editedById = bridge.applyLut(lut, lutIntensity, selectedPhotos).associateBy { it.id }
        photos = photos.map { editedById[it.id] ?: it }
    }

    fun markSelectionExported() {
        val exportedById = bridge.markExported(selectedPhotos, exportSettings).associateBy { it.id }
        photos = photos.map { exportedById[it.id] ?: it }
    }
}
