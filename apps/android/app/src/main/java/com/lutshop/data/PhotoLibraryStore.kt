package com.lutshop.data

import android.content.Context
import com.lutshop.Photo
import com.lutshop.PhotoStatus
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import androidx.compose.ui.graphics.Color
import java.io.File

@Serializable
data class PersistedPhotoLibrary(
    val photos: List<PersistedPhoto>,
    val sessions: List<String>
)

@Serializable
data class PersistedPhoto(
    val id: String,
    val fileName: String,
    val uri: String,
    val localPath: String?,
    val importedAt: Long,
    val sessionName: String,
    val status: String,
    val isFavorite: Boolean,
    val rating: Int,
    val appliedLutId: String?,
    val lutIntensity: Float,
    val recommendedLutIds: List<String>,
    val renderedImagePath: String? = null
)

class PhotoLibraryStore(private val context: Context) {
    private val json = Json { ignoreUnknownKeys = true; prettyPrint = true }
    private val file: File
        get() = File(context.filesDir, "PhotoLibraryIndex.json")

    fun load(): Pair<List<Photo>, List<String>>? {
        if (!file.exists()) return null
        val payload = json.decodeFromString<PersistedPhotoLibrary>(file.readText())
        val photos = payload.photos.mapNotNull { item ->
            if (item.localPath != null && !File(item.localPath).exists()) return@mapNotNull null
            Photo(
                id = item.id,
                fileName = item.fileName,
                uri = item.uri,
                localPath = item.localPath,
                importedAt = item.importedAt,
                sessionName = item.sessionName,
                status = PhotoStatus.valueOf(item.status),
                isFavorite = item.isFavorite,
                isSelected = false,
                rating = item.rating,
                appliedLutId = item.appliedLutId,
                lutIntensity = item.lutIntensity,
                recommendedLutIds = item.recommendedLutIds,
                palette = listOf(Color.Gray, Color.Black),
                renderedImagePath = item.renderedImagePath
            )
        }
        val sessions = (payload.sessions + photos.map { it.sessionName }).filter { it.isNotBlank() }.distinct().sorted()
        return photos to sessions
    }

    fun save(photos: List<Photo>, sessions: List<String>) {
        val payload = PersistedPhotoLibrary(
            photos = photos.map {
                PersistedPhoto(
                    id = it.id,
                    fileName = it.fileName,
                    uri = it.uri,
                    localPath = it.localPath,
                    importedAt = it.importedAt,
                    sessionName = it.sessionName,
                    status = it.status.name,
                    isFavorite = it.isFavorite,
                    rating = it.rating,
                    appliedLutId = it.appliedLutId,
                    lutIntensity = it.lutIntensity,
                    recommendedLutIds = it.recommendedLutIds,
                    renderedImagePath = it.renderedImagePath
                )
            },
            sessions = sessions
        )
        file.writeText(json.encodeToString(payload))
    }
}
