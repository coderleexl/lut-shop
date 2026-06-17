package com.lutshop.ui

import android.graphics.BitmapFactory
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lutshop.LutShopAppState
import com.lutshop.MainTab
import com.lutshop.R
import java.io.File

@Composable
fun PreviewScreen(state: LutShopAppState) {
    val photo = state.currentPhoto
    val context = LocalContext.current

    if (photo == null) {
        Box(Modifier.fillMaxSize().background(Color.Black), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(stringResource(R.string.no_photos), color = Color.White.copy(alpha = 0.5f), fontSize = 18.sp)
                Text(stringResource(R.string.import_photos_hint), color = Color.White.copy(alpha = 0.35f), fontSize = 14.sp, modifier = Modifier.padding(top = 8.dp))
            }
        }
        return
    }

    var compareMode by remember { mutableStateOf(false) }
    var splitPosition by remember { mutableFloatStateOf(0.5f) }
    var draftIntensity by remember(photo.id) { mutableFloatStateOf(state.lutIntensity) }
    val photoAspectRatio = remember(photo.id, photo.localPath, photo.renderedImagePath) {
        photoAspectRatio(photo.localPath ?: photo.renderedImagePath)
    }

    LaunchedEffect(state.lutIntensity, photo.id) {
        draftIntensity = state.lutIntensity
    }

    // Render when the selected LUT or photo changes. Slider changes render on release.
    LaunchedEffect(state.activeLutId, photo.id) {
        state.renderCurrentPreview()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(horizontal = 14.dp, vertical = 16.dp)
            .padding(bottom = 76.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // Header
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("<", color = Color.White, fontSize = 28.sp, modifier = Modifier.clickable { state.selectedTab = MainTab.Gallery })
            Column(Modifier.padding(start = 14.dp)) {
                Text(photo.fileName, color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                Text(
                    if (compareMode) stringResource(R.string.before) + " / " + stringResource(R.string.show_after)
                    else stringResource(R.string.after_percent, (draftIntensity * 100).toInt()),
                    color = Color.White.copy(alpha = 0.55f), fontSize = 12.sp
                )
            }
        }

        // Image preview area
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(photoAspectRatio)
                .clip(RoundedCornerShape(18.dp))
        ) {
            if (compareMode) {
                BeforeAfterCompare(
                    beforeImagePath = photo.localPath,
                    afterImagePath = photo.renderedImagePath,
                    splitPosition = splitPosition,
                    onSplitChange = { splitPosition = it }
                )
            } else {
                PhotoAsset(
                    uri = photo.uri,
                    localPath = photo.localPath,
                    fallbackColors = photo.palette,
                    modifier = Modifier.matchParentSize(),
                    renderedImagePath = photo.renderedImagePath,
                    contentScale = ContentScale.Fit
                )
            }
            // LUT name overlay
            Text(
                if (compareMode) stringResource(R.string.before) + " / " + stringResource(R.string.show_after)
                else state.activeLut?.name ?: stringResource(R.string.no_lut),
                color = Color.White,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(12.dp)
                    .clip(RoundedCornerShape(99.dp))
                    .background(Color.Black.copy(alpha = 0.45f))
                    .padding(horizontal = 10.dp, vertical = 6.dp)
            )
            // Rating overlay
            if (photo.rating > 0) {
                Text(
                    "★".repeat(photo.rating),
                    color = Color.Yellow,
                    fontSize = 18.sp,
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(12.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color.Black.copy(alpha = 0.45f))
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                )
            }
            // Loading indicator
            if (state.isRendering) {
                Box(
                    modifier = Modifier
                        .matchParentSize()
                        .background(Color.Black.copy(alpha = 0.4f))
                        .clickable { /* consume touch */ },
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(
                        color = AccentGreen,
                        modifier = Modifier.size(48.dp)
                    )
                }
            }
        }
        Row(
            modifier = Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            state.luts.forEach { lut ->
                Column(
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(if (state.activeLutId == lut.id) Color.White.copy(alpha = 0.16f) else Color.White.copy(alpha = 0.08f))
                        .clickable { state.activeLutId = lut.id }
                        .padding(10.dp)
                ) {
                    LutStrip(
                        lut.previewColors,
                        Modifier
                            .width((58 * photoAspectRatio).dp)
                            .height(58.dp)
                    )
                    Text(lut.name, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 8.dp))
                    lut.confidence?.let {
                        Text(stringResource(R.string.cv_percent, it), color = AccentGreen, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }

        // Adjustment panel
        Column(
            modifier = Modifier
                .clip(RoundedCornerShape(16.dp))
                .background(Color.White.copy(alpha = 0.08f))
                .padding(14.dp)
        ) {
            Text(stringResource(R.string.lut_intensity_percent, (draftIntensity * 100).toInt()), color = Color.White, fontWeight = FontWeight.SemiBold)
            Slider(
                value = draftIntensity,
                onValueChange = { draftIntensity = it },
                onValueChangeFinished = {
                    state.lutIntensity = draftIntensity
                    state.renderCurrentPreview()
                }
            )
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(onClick = { compareMode = !compareMode }) {
                    Text(if (compareMode) stringResource(R.string.exit_compare) else stringResource(R.string.before))
                }
                Button(onClick = {
                    state.undoCurrentPhotoAdjustment()
                    Toast.makeText(context, context.getString(R.string.undone), Toast.LENGTH_SHORT).show()
                }) { Text(stringResource(R.string.undo)) }
                Button(onClick = {
                    state.applyActiveLutToCurrentPhoto()
                    Toast.makeText(context, context.getString(R.string.saved), Toast.LENGTH_SHORT).show()
                }) { Text(stringResource(R.string.save)) }
            }
            if (state.selectedPhotosExcludingCurrentCount > 0) {
                Button(
                    onClick = {
                        state.syncCurrentAdjustmentToOtherSelectedPhotos()
                        Toast.makeText(context, context.getString(R.string.synced), Toast.LENGTH_SHORT).show()
                    },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = AccentGreen)
                ) {
                    Text(
                        stringResource(R.string.sync_to_selected, state.selectedPhotosExcludingCurrentCount),
                        color = Color.Black
                    )
                }
            }
        }
    }
}

private fun photoAspectRatio(path: String?): Float {
    if (path.isNullOrBlank()) return 1f
    val file = File(path)
    if (!file.exists()) return 1f
    val options = BitmapFactory.Options().apply {
        inJustDecodeBounds = true
    }
    BitmapFactory.decodeFile(path, options)
    val width = options.outWidth
    val height = options.outHeight
    if (width <= 1 || height <= 1) return 1f
    return (width.toFloat() / height.toFloat()).coerceIn(0.62f, 1.58f)
}

@Composable
private fun BeforeAfterCompare(
    beforeImagePath: String?,
    afterImagePath: String?,
    splitPosition: Float,
    onSplitChange: (Float) -> Unit
) {
    var containerSize by remember { mutableStateOf(IntSize.Zero) }
    val density = LocalDensity.current

    Box(
        modifier = Modifier
            .fillMaxSize()
            .onSizeChanged { containerSize = it }
            .pointerInput(Unit) {
                detectDragGestures { change, _ ->
                    change.consume()
                    val newPos = (change.position.x / containerSize.width).coerceIn(0.1f, 0.9f)
                    onSplitChange(newPos)
                }
            }
    ) {
        // After (full width, behind)
        PhotoAsset(
            uri = "",
            localPath = afterImagePath,
            fallbackColors = emptyList(),
            modifier = Modifier.matchParentSize(),
            renderedImagePath = afterImagePath,
            contentScale = ContentScale.Fit
        )
        // Before (clipped to left of split)
        val clipWidthDp = with(density) { (containerSize.width * splitPosition).toDp() }
        val fullWidthDp = with(density) { containerSize.width.toDp() }
        val fullHeightDp = with(density) { containerSize.height.toDp() }
        Box(modifier = Modifier
            .width(clipWidthDp)
            .height(fullHeightDp)
            .clipToBounds()
        ) {
            PhotoAsset(
                uri = "",
                localPath = beforeImagePath,
                fallbackColors = emptyList(),
                modifier = Modifier.requiredSize(fullWidthDp, fullHeightDp),
                renderedImagePath = null,
                contentScale = ContentScale.Fit
            )
        }
        // Divider line
        val dividerX = with(density) { (containerSize.width * splitPosition).toDp() }
        Box(
            modifier = Modifier
                .offset(x = dividerX - 1.5.dp)
                .width(3.dp)
                .height(with(density) { containerSize.height.toDp() })
                .background(Color.White)
        )
        // Before/After labels
        Text(
            stringResource(R.string.before),
            color = Color.White,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(start = dividerX - 60.dp, top = 8.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(Color.Black.copy(alpha = 0.6f))
                .padding(horizontal = 6.dp, vertical = 2.dp)
        )
        Text(
            stringResource(R.string.show_after),
            color = Color.White,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(end = 8.dp, top = 8.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(Color.Black.copy(alpha = 0.6f))
                .padding(horizontal = 6.dp, vertical = 2.dp)
        )
    }
}
