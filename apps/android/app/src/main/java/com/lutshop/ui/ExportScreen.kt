package com.lutshop.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lutshop.LutShopAppState
import com.lutshop.R
import androidx.compose.ui.res.stringResource
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun ExportScreen(state: LutShopAppState) {
    var exporting by remember { mutableStateOf(false) }
    var progress by remember { mutableFloatStateOf(0f) }
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(horizontal = 14.dp, vertical = 24.dp)
            .padding(bottom = 76.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(stringResource(R.string.selected_count_title, state.selectedPhotos.size), color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Bold)
        Text(stringResource(R.string.batch_process_and_export), color = Color.White.copy(alpha = 0.56f))

        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            state.selectedPhotos.forEach { photo ->
                Box(
                    modifier = Modifier
                        .width(88.dp)
                        .aspectRatio(0.78f)
                        .clip(RoundedCornerShape(10.dp))
                        .background(Brush.linearGradient(photo.palette))
                        .padding(7.dp)
                ) {
                    Text(photo.fileName, color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                }
            }
        }

        Column(
            modifier = Modifier
                .clip(RoundedCornerShape(16.dp))
                .background(Color.White.copy(alpha = 0.08f))
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(stringResource(R.string.format_value, state.exportSettings.format), color = Color.White)
            Text(stringResource(R.string.size_value, state.exportSettings.size), color = Color.White)
            Text(stringResource(R.string.quality_value, state.exportSettings.quality), color = Color.White)
            Row {
                Text(stringResource(R.string.preserve_exif), color = Color.White, modifier = Modifier.weight(1f))
                Switch(checked = state.exportSettings.preserveExif, onCheckedChange = {
                    state.exportSettings = state.exportSettings.copy(preserveExif = it)
                })
            }
        }

        if (exporting) {
            LinearProgressIndicator(progress = { progress }, color = AccentGreen)
            Text(if (progress >= 1f) stringResource(R.string.export_complete) else stringResource(R.string.exporting_percent, (progress * 100).toInt()), color = if (progress >= 1f) AccentGreen else Color.White.copy(alpha = 0.68f))
        }

        Button(
            onClick = {
                exporting = true
                progress = 0f
                scope.launch {
                    repeat(10) {
                        delay(120)
                        progress = (it + 1) / 10f
                    }
                    state.markSelectionExported()
                }
            }
        ) {
            Text(stringResource(R.string.export_photos))
        }
    }
}
