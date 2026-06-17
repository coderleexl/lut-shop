package com.lutshop.ui

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lutshop.LutShopAppState
import com.lutshop.R
import com.lutshop.core.LutRenderer
import com.lutshop.export.PhotoExporter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun ExportScreen(state: LutShopAppState) {
    var exporting by remember { mutableStateOf(false) }
    var progress by remember { mutableFloatStateOf(0f) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(horizontal = 14.dp, vertical = 16.dp)
            .padding(bottom = 76.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(stringResource(R.string.selected_count_title, state.selectedPhotos.size), color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Bold)
        Text(stringResource(R.string.batch_process_and_export), color = Color.White.copy(alpha = 0.56f))

        if (state.selectedPhotos.isEmpty()) {
            Text(stringResource(R.string.import_photos_hint), color = Color.White.copy(alpha = 0.4f), fontSize = 14.sp)
            return
        }

        // Thumbnail strip
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            state.selectedPhotos.forEach { photo ->
                Box(
                    modifier = Modifier
                        .width(88.dp)
                        .aspectRatio(0.78f)
                        .clip(RoundedCornerShape(10.dp))
                        .background(safeLinearGradient(photo.palette))
                        .padding(7.dp)
                ) {
                    Text(photo.fileName, color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                }
            }
        }

        // Export settings
        Column(
            modifier = Modifier
                .clip(RoundedCornerShape(16.dp))
                .background(Color.White.copy(alpha = 0.08f))
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Format
            SettingRow {
                SegmentedPicker(
                    options = listOf("JPG", "PNG"),
                    selected = state.exportSettings.format,
                    onSelect = { state.exportSettings = state.exportSettings.copy(format = it) }
                )
            }
            // Size
            SettingRow {
                SegmentedPicker(
                    options = listOf("Original", "2048px", "1080px"),
                    selected = state.exportSettings.size,
                    onSelect = { state.exportSettings = state.exportSettings.copy(size = it) }
                )
            }
            // Quality
            SettingRow {
                SegmentedPicker(
                    options = listOf("High", "Medium", "Low"),
                    selected = state.exportSettings.quality,
                    onSelect = { state.exportSettings = state.exportSettings.copy(quality = it) }
                )
            }
            // EXIF
            Row {
                Text(stringResource(R.string.preserve_exif), color = Color.White, modifier = Modifier.weight(1f))
                Switch(checked = state.exportSettings.preserveExif, onCheckedChange = {
                    state.exportSettings = state.exportSettings.copy(preserveExif = it)
                })
            }
        }

        if (exporting) {
            LinearProgressIndicator(progress = { progress }, color = AccentGreen, modifier = Modifier.fillMaxWidth())
            Text(
                if (progress >= 1f) stringResource(R.string.export_complete)
                else stringResource(R.string.exporting_percent, (progress * 100).toInt()),
                color = if (progress >= 1f) AccentGreen else Color.White.copy(alpha = 0.68f)
            )
        }

        Button(
            onClick = {
                exporting = true
                progress = 0f
                scope.launch {
                    val photos = state.selectedPhotos
                    val settings = state.exportSettings
                    var successCount = 0
                    photos.forEachIndexed { index, photo ->
                        // Load cube text if photo has LUT applied
                        val cubeText = photo.appliedLutId?.let { lutId ->
                            val lut = state.luts.firstOrNull { it.id == lutId }
                            lut?.sourceFileName?.let { fileName ->
                                LutRenderer.loadCubeText(context, "luts/$fileName.cube")
                            }
                        }
                        val result = withContext(Dispatchers.IO) {
                            PhotoExporter.exportPhoto(context, photo, settings, cubeText) { p ->
                                progress = (index + p) / photos.size
                            }
                        }
                        if (result) successCount++
                    }
                    state.markSelectionExported()
                    exporting = false
                    Toast.makeText(
                        context,
                        context.getString(R.string.export_done_count, successCount, photos.size),
                        Toast.LENGTH_LONG
                    ).show()
                }
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(stringResource(R.string.export_photos))
        }
    }
}

@Composable
private fun SettingRow(content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        content()
    }
}


@Composable
private fun SegmentedPicker(options: List<String>, selected: String, onSelect: (String) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        options.forEach { option ->
            val isSelected = option == selected
            Text(
                option,
                color = if (isSelected) Color.Black else Color.White.copy(alpha = 0.7f),
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (isSelected) AccentGreen else Color.Transparent)
                    .clickable { onSelect(option) }
                    .padding(vertical = 8.dp)
                    .then(
                        Modifier.padding(horizontal = 0.dp)
                    ),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center
            )
        }
    }
}
