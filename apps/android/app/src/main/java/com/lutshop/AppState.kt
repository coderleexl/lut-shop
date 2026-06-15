package com.lutshop

import android.app.Application
import android.content.Context
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.lutshop.core.CoreBridge
import com.lutshop.core.LutShopCoreBridge
import com.lutshop.core.LutRenderer
import com.lutshop.data.AndroidFtpReceiveService
import com.lutshop.data.CameraReceivedFile
import com.lutshop.data.FtpReceiverConfiguration
import com.lutshop.data.LutLibraryStore
import com.lutshop.data.PhotoLibraryStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID

class LutShopAppState(
    private val appContext: Context,
    private val bridge: LutShopCoreBridge = CoreBridge(),
    private val photoStore: PhotoLibraryStore? = null,
    private val lutStore: LutLibraryStore? = null
) : ViewModel() {
    var selectedTab by mutableStateOf(MainTab.Gallery)
    var showCameraImportPanel by mutableStateOf(false)
    var isSelectionMode by mutableStateOf(false)
    var activeFilter by mutableStateOf<PhotoStatus?>(null)
    var showFavoritesOnly by mutableStateOf(false)
    var photoSortOption by mutableStateOf(PhotoSortOption.Newest)
    var selectedSessionName by mutableStateOf<String?>(null)
    var searchText by mutableStateOf("")
    var selectedPhotoId by mutableStateOf<String?>(null)
    var activeLutId by mutableStateOf<String?>(null)
    var lutIntensity by mutableFloatStateOf(0.72f)
    var exportSettings by mutableStateOf(ExportSettings())
    var photos by mutableStateOf(loadPhotos())
        private set
    var sessions by mutableStateOf(loadSessions())
        private set
    var luts by mutableStateOf(emptyList<LutPreset>())
        private set
    var userCategories by mutableStateOf(loadUserCategories())
        private set
    var lutGroups by mutableStateOf(loadLutGroups())
        private set
    var isRendering by mutableStateOf(false)
        private set
    var ftpConfiguration by mutableStateOf(
        FtpReceiverConfiguration(host = AndroidFtpReceiveService.localIPv4Address())
    )
        private set
    var isFtpReceiverRunning by mutableStateOf(false)
        private set
    var ftpReceivedCount by mutableStateOf(0)
        private set
    var ftpCurrentFileName by mutableStateOf("")
        private set
    var ftpLastFileName by mutableStateOf("")
        private set
    var ftpStatusMessage by mutableStateOf("")
        private set
    private var renderJob: Job? = null
    private val viewModelScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val ftpReceiveService = AndroidFtpReceiveService(
        context = appContext,
        scope = viewModelScope,
        onTransferStarted = { fileName ->
            viewModelScope.launch {
                ftpCurrentFileName = fileName
                ftpStatusMessage = appContext.getString(R.string.ftp_receiving_file, fileName)
            }
        },
        onFileReceived = { file ->
            viewModelScope.launch {
                importCameraReceivedFile(file)
                ftpReceivedCount += 1
                ftpLastFileName = file.originalFileName
                ftpCurrentFileName = ""
                ftpStatusMessage = appContext.getString(R.string.ftp_received_count, ftpReceivedCount)
            }
        },
        onError = { message ->
            isFtpReceiverRunning = false
            ftpStatusMessage = message
        }
    )

    init {
        luts = loadLuts()
        selectedPhotoId = photos.firstOrNull()?.id
        activeLutId = luts.firstOrNull()?.id
    }

    override fun onCleared() {
        ftpReceiveService.stop()
        renderJob?.cancel()
        viewModelScope.cancel()
        super.onCleared()
    }

    fun refreshFtpHost() {
        ftpConfiguration = ftpConfiguration.copy(host = AndroidFtpReceiveService.localIPv4Address())
    }

    fun startFtpReceiver() {
        refreshFtpHost()
        ftpReceiveService.start(ftpConfiguration)
        isFtpReceiverRunning = true
        ftpCurrentFileName = ""
        ftpStatusMessage = appContext.getString(R.string.ftp_receiver_running)
    }

    fun stopFtpReceiver() {
        ftpReceiveService.stop()
        isFtpReceiverRunning = false
        ftpCurrentFileName = ""
        ftpStatusMessage = appContext.getString(R.string.ftp_receiver_stopped)
    }

    private fun loadLuts(): List<LutPreset> {
        val persisted = lutStore?.load()
        val userLuts = persisted?.first ?: emptyList()
        val bundled = bridge.loadBundledLuts(appContext)
        return bundled + userLuts
    }

    private fun loadUserCategories(): List<String> {
        return lutStore?.load()?.second ?: emptyList()
    }

    private fun loadLutGroups(): List<LutCategoryGroup> {
        val systemGroups = bridge.getSystemGroups()
        val customGroupNames = userCategories.filter { catName ->
            systemGroups.none { it.name == catName }
        }
        val customGroups = customGroupNames.map { LutCategoryGroup(it, isSystem = false) }
        return systemGroups + customGroups
    }

    fun refreshGroups() {
        lutGroups = loadLutGroups()
    }

    private fun persistLuts() {
        val userLuts = luts.filter { !it.isBundled }
        lutStore?.save(userLuts, userCategories)
    }

    private fun loadPhotos(): List<Photo> {
        val persisted = photoStore?.load()
        return persisted?.first ?: emptyList()
    }

    private fun loadSessions(): List<String> {
        val persisted = photoStore?.load()
        return persisted?.second ?: emptyList()
    }

    private fun persist() {
        photoStore?.save(photos, sessions)
    }

    val filteredPhotos: List<Photo>
        get() = photos.filter {
            val matchesFilter = activeFilter == null || it.status == activeFilter
            val matchesFavorites = !showFavoritesOnly || it.isFavorite
            val matchesSession = selectedSessionName == null || it.sessionName == selectedSessionName
            val matchesSearch = searchText.isBlank()
                || it.fileName.contains(searchText, ignoreCase = true)
                || it.sessionName.contains(searchText, ignoreCase = true)
            matchesFilter && matchesFavorites && matchesSession && matchesSearch
        }.let { list ->
            when (photoSortOption) {
                PhotoSortOption.FileName -> list.sortedBy { it.fileName.lowercase() }
                PhotoSortOption.Newest -> list.sortedByDescending { it.importedAt }
                PhotoSortOption.Rating -> list.sortedByDescending { it.rating }
            }
        }

    val selectedPhotos: List<Photo>
        get() = photos.filter { it.isSelected }

    val selectedPhotosExcludingCurrentCount: Int
        get() = selectedPhotos.count { it.id != currentPhoto?.id }

    val currentPhoto: Photo?
        get() = photos.firstOrNull { it.id == selectedPhotoId } ?: photos.firstOrNull()

    val activeLut: LutPreset?
        get() = luts.firstOrNull { it.id == activeLutId } ?: luts.firstOrNull()

    val recommendedLuts: List<LutPreset>
        get() = emptyList()

    fun openPhoto(id: String) {
        selectedPhotoId = id
        val photo = photos.firstOrNull { it.id == id }
        if (photo != null) syncPreviewAdjustmentState(photo)
        selectedTab = MainTab.Preview
    }

    private fun syncPreviewAdjustmentState(photo: Photo) {
        activeLutId = photo.appliedLutId ?: activeLutId
        lutIntensity = photo.lutIntensity.coerceIn(0f, 1f)
    }

    fun undoCurrentPhotoAdjustment() {
        val id = currentPhoto?.id ?: return
        photos = photos.map {
            if (it.id == id) it.copy(appliedLutId = null, lutIntensity = 0.72f, status = PhotoStatus.Raw, renderedImagePath = null)
            else it
        }
        persist()
    }

    fun syncCurrentAdjustmentToOtherSelectedPhotos() {
        val current = currentPhoto ?: return
        val lutId = current.appliedLutId ?: return
        photos = photos.map {
            if (it.isSelected && it.id != current.id) {
                it.copy(appliedLutId = lutId, lutIntensity = current.lutIntensity, status = PhotoStatus.Edited)
            } else it
        }
        persist()
    }

    fun toggleSelection(id: String) {
        photos = photos.map { if (it.id == id) it.copy(isSelected = !it.isSelected) else it }
        selectedPhotoId = id
    }

    fun openOrTogglePhoto(id: String) {
        if (isSelectionMode) toggleSelection(id) else openPhoto(id)
    }

    fun selectAllFilteredPhotos() {
        val ids = filteredPhotos.map { it.id }.toSet()
        photos = photos.map { if (it.id in ids) it.copy(isSelected = true) else it }
        selectedPhotoId = filteredPhotos.firstOrNull()?.id ?: selectedPhotoId
        isSelectionMode = true
    }

    fun clearSelection() {
        photos = photos.map { it.copy(isSelected = false) }
        isSelectionMode = false
    }

    fun createSession(name: String) {
        if (name.isBlank() || name in sessions) return
        sessions = (sessions + name).sorted()
        persist()
    }

    fun renameSession(old: String, new: String) {
        if (new.isBlank() || old == new || new in sessions) return
        photos = photos.map { if (it.sessionName == old) it.copy(sessionName = new) else it }
        sessions = (sessions.filter { it != old } + new).sorted()
        if (selectedSessionName == old) selectedSessionName = new
        persist()
    }

    fun deleteSession(name: String) {
        if (photos.any { it.sessionName == name }) return
        sessions = sessions.filter { it != name }
        if (selectedSessionName == name) selectedSessionName = null
        persist()
    }

    fun addLut(name: String, path: String, category: LutCategory) {
        if (name.isBlank()) return
        val lut = LutPreset(
            id = UUID.randomUUID().toString(),
            name = name,
            category = category,
            tags = emptyList(),
            previewColors = listOf(Color(0xFF888888), Color(0xFF444444), Color.Black),
            isFavorite = false,
            usageCount = 0,
            confidence = null,
            sourceFileName = null,
            isBundled = false,
            userPath = path.ifBlank { null }
        )
        luts = luts + lut
        persistLuts()
    }

    fun renameLut(id: String, newName: String) {
        if (newName.isBlank()) return
        luts = luts.map { if (it.id == id) it.copy(name = newName) else it }
        persistLuts()
    }

    fun deleteLut(id: String) {
        val lut = luts.firstOrNull { it.id == id } ?: return
        if (lut.isBundled) return
        luts = luts.filter { it.id != id }
        if (activeLutId == id) activeLutId = luts.firstOrNull()?.id
        // Clear references from photos
        photos = photos.map { if (it.appliedLutId == id) it.copy(appliedLutId = null) else it }
        persistLuts()
        persist()
    }

    fun toggleLutFavorite(id: String) {
        luts = luts.map { if (it.id == id) it.copy(isFavorite = !it.isFavorite) else it }
        persistLuts()
    }

    fun changeLutCategory(id: String, category: LutCategory) {
        luts = luts.map { if (it.id == id) it.copy(category = category) else it }
        persistLuts()
    }

    fun addUserCategory(name: String) {
        if (name.isBlank() || name in userCategories) return
        userCategories = (userCategories + name).sorted()
        refreshGroups()
        persistLuts()
    }

    fun deleteUserCategory(name: String) {
        // Prevent deleting system groups
        if (bridge.getSystemGroups().any { it.name == name }) return
        userCategories = userCategories.filter { it != name }
        // Move LUTs in this category to Custom
        luts = luts.map { if (it.category == LutCategory.Custom) it else it }
        refreshGroups()
        persistLuts()
    }

    fun renameUserCategory(oldName: String, newName: String) {
        if (newName.isBlank() || oldName == newName) return
        if (bridge.getSystemGroups().any { it.name == oldName }) return
        userCategories = userCategories.map { if (it == oldName) newName else it }
        refreshGroups()
        persistLuts()
    }

    fun toggleFavorite(id: String) {
        photos = photos.map { if (it.id == id) it.copy(isFavorite = !it.isFavorite) else it }
        persist()
    }

    fun rateCurrentPhoto(rating: Int) {
        val id = currentPhoto?.id ?: return
        photos = photos.map { if (it.id == id) it.copy(rating = rating.coerceIn(0, 5)) else it }
        persist()
    }

    fun applyActiveLutToCurrentPhoto() {
        val photo = currentPhoto ?: return
        val lut = activeLut ?: return
        renderJob?.cancel()
        isRendering = true
        renderJob = CoroutineScope(Dispatchers.IO).launch {
            val renderedPath = renderLutToPath(photo, lut, lutIntensity)
            withContext(Dispatchers.Main) {
                val edited = bridge.applyLut(lut, lutIntensity, listOf(photo)).first()
                photos = photos.map {
                    if (it.id == edited.id) edited.copy(renderedImagePath = renderedPath ?: edited.renderedImagePath) else it
                }
                luts = luts.map { if (it.id == lut.id) it.copy(usageCount = it.usageCount + 1) else it }
                isRendering = false
                persist()
                persistLuts()
            }
        }
    }

    fun renderCurrentPreview() {
        val photo = currentPhoto ?: return
        val lut = activeLut ?: return
        if (photo.localPath == null || lut.sourceFileName == null) return
        renderJob?.cancel()
        renderJob = CoroutineScope(Dispatchers.IO).launch {
            delay(250) // debounce: wait for user to stop dragging
            val intensity = lutIntensity // capture current value after debounce
            withContext(Dispatchers.Main) { isRendering = true }
            val path = renderLutToPath(photo, lut, intensity)
            withContext(Dispatchers.Main) {
                if (path != null) {
                    photos = photos.map {
                        if (it.id == photo.id) it.copy(renderedImagePath = path) else it
                    }
                }
                isRendering = false
            }
        }
    }

    private fun renderLutToPath(photo: Photo, lut: LutPreset, intensity: Float): String? {
        val sourcePath = photo.localPath ?: return null
        val cubeFileName = lut.sourceFileName ?: return null
        val cubeText = LutRenderer.loadCubeText(appContext, "luts/$cubeFileName.cube")
            ?: return null
        val outputPath = File(appContext.filesDir, "Rendered/${photo.id}_${lut.id}.jpg").absolutePath
        val success = LutRenderer.applyLutToImage(appContext, sourcePath, cubeText, intensity, outputPath)
        return if (success) outputPath else null
    }

    fun applyActiveLutToSelection() {
        val lut = activeLut ?: return
        val editedById = bridge.applyLut(lut, lutIntensity, selectedPhotos).associateBy { it.id }
        photos = photos.map { editedById[it.id] ?: it }
        persist()
    }

    fun markSelectionExported() {
        val exportedById = bridge.markExported(selectedPhotos, exportSettings).associateBy { it.id }
        photos = photos.map { exportedById[it.id] ?: it }
        persist()
    }

    fun importPhotoUris(context: Context, uris: List<Uri>) {
        val importDir = File(context.filesDir, "ImportedPhotos").apply { mkdirs() }
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault())
            .format(java.util.Date())
        val newPhotos = uris.mapNotNull { uri ->
            val fileName = getFileName(context, uri) ?: "IMG_${System.currentTimeMillis()}.jpg"
            val dest = File(importDir, "${UUID.randomUUID()}_$fileName")
            try {
                context.contentResolver.openInputStream(uri)?.use { input ->
                    dest.outputStream().use { output -> input.copyTo(output) }
                } ?: return@mapNotNull null
            } catch (_: Exception) {
                return@mapNotNull null
            }
            Photo(
                id = UUID.randomUUID().toString(),
                fileName = fileName,
                uri = uri.toString(),
                localPath = dest.absolutePath,
                importedAt = System.currentTimeMillis(),
                sessionName = today,
                status = PhotoStatus.Raw,
                isFavorite = false,
                isSelected = false,
                rating = 0,
                appliedLutId = null,
                lutIntensity = 0.72f,
                recommendedLutIds = emptyList(),
                palette = listOf(Color(0xFF888888), Color(0xFF333333), Color.Black)
            )
        }
        if (newPhotos.isNotEmpty()) {
            photos = newPhotos + photos
            val newSessions = (sessions + newPhotos.map { it.sessionName }).distinct().sorted()
            sessions = newSessions
            persist()
        }
    }

    private fun importCameraReceivedFile(receivedFile: CameraReceivedFile) {
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault())
            .format(java.util.Date())
        val photo = Photo(
            id = UUID.randomUUID().toString(),
            fileName = receivedFile.originalFileName,
            uri = receivedFile.file.toURI().toString(),
            localPath = receivedFile.file.absolutePath,
            importedAt = System.currentTimeMillis(),
            sessionName = today,
            status = PhotoStatus.Raw,
            isFavorite = false,
            isSelected = false,
            rating = 0,
            appliedLutId = null,
            lutIntensity = 0.72f,
            recommendedLutIds = emptyList(),
            palette = listOf(Color(0xFF888888), Color(0xFF333333), Color.Black)
        )
        photos = listOf(photo) + photos
        sessions = (sessions + today).distinct().sorted()
        persist()
    }

    fun deleteSelectedPhotos() {
        val ids = selectedPhotos.map { it.id }.toSet()
        selectedPhotos.forEach { photo ->
            photo.localPath?.let { File(it).delete() }
        }
        photos = photos.filter { it.id !in ids }
        persist()
    }

    private fun getFileName(context: Context, uri: Uri): String? {
        context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val idx = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
            if (idx >= 0 && cursor.moveToFirst()) return cursor.getString(idx)
        }
        return uri.lastPathSegment
    }

    class Factory(
        private val application: Application,
        private val photoStore: PhotoLibraryStore,
        private val lutStore: LutLibraryStore
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            return LutShopAppState(
                appContext = application.applicationContext,
                photoStore = photoStore,
                lutStore = lutStore
            ) as T
        }
    }
}
