package com.lutshop.data

import android.content.Context
import com.lutshop.LutCategory
import com.lutshop.LutCategoryGroup
import com.lutshop.LutPreset
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import androidx.compose.ui.graphics.Color
import java.io.File
import java.util.UUID

@Serializable
data class PersistedLutLibrary(
    val userLuts: List<PersistedLut>,
    val userCategories: List<String>
)

@Serializable
data class PersistedLut(
    val id: String,
    val name: String,
    val categoryName: String,
    val userPath: String?,
    val isFavorite: Boolean
)

class LutLibraryStore(private val context: Context) {
    private val json = Json { ignoreUnknownKeys = true; prettyPrint = true }
    private val file: File
        get() = File(context.filesDir, "LutLibraryIndex.json")

    fun load(): Pair<List<LutPreset>, List<String>>? {
        if (!file.exists()) return null
        val payload = json.decodeFromString<PersistedLutLibrary>(file.readText())
        val userLuts = payload.userLuts.map { item ->
            LutPreset(
                id = item.id,
                name = item.name,
                category = LutCategory.entries.firstOrNull { it.name == item.categoryName } ?: LutCategory.Custom,
                tags = emptyList(),
                previewColors = listOf(Color(0xFF888888), Color(0xFF444444), Color.Black),
                isFavorite = item.isFavorite,
                usageCount = 0,
                confidence = null,
                sourceFileName = null,
                isBundled = false,
                userPath = item.userPath
            )
        }
        return userLuts to payload.userCategories
    }

    fun save(userLuts: List<LutPreset>, userCategories: List<String>) {
        val payload = PersistedLutLibrary(
            userLuts = userLuts.map {
                PersistedLut(
                    id = it.id,
                    name = it.name,
                    categoryName = it.category.name,
                    userPath = it.userPath,
                    isFavorite = it.isFavorite
                )
            },
            userCategories = userCategories
        )
        file.writeText(json.encodeToString(payload))
    }
}
