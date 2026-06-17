package com.lutshop.ui

import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import coil.compose.AsyncImage
import java.io.File

@Composable
fun PhotoAsset(
    uri: String,
    localPath: String?,
    fallbackColors: List<Color>,
    modifier: Modifier = Modifier,
    renderedImagePath: String? = null,
    contentScale: ContentScale = ContentScale.Crop
) {
    val model: Any? = when {
        !renderedImagePath.isNullOrBlank() && File(renderedImagePath).exists() -> File(renderedImagePath)
        !localPath.isNullOrBlank() && File(localPath).exists() -> File(localPath)
        uri.isNotBlank() -> Uri.parse(uri)
        else -> null
    }
    if (model != null) {
        AsyncImage(model = model, contentDescription = null, contentScale = contentScale, modifier = modifier)
    } else {
        Box(modifier.background(safeLinearGradient(fallbackColors)))
    }
}
