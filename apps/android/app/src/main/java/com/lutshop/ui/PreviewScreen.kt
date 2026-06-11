package com.lutshop.ui

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lutshop.LutShopAppState
import com.lutshop.MainTab
import com.lutshop.R
import androidx.compose.ui.res.stringResource

@Composable
fun PreviewScreen(state: LutShopAppState) {
    var showBefore by remember { mutableStateOf(false) }
    val photo = state.currentPhoto

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(horizontal = 14.dp, vertical = 24.dp)
            .padding(bottom = 76.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("<", color = Color.White, fontSize = 28.sp, modifier = Modifier.clickable { state.selectedTab = MainTab.Gallery })
            Column(Modifier.padding(start = 14.dp)) {
                Text(photo?.fileName ?: stringResource(R.string.preview), color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                Text(if (showBefore) stringResource(R.string.before) else stringResource(R.string.after_percent, (state.lutIntensity * 100).toInt()), color = Color.White.copy(alpha = 0.55f), fontSize = 12.sp)
            }
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(0.78f)
                .clip(RoundedCornerShape(18.dp))
                .background(Brush.linearGradient(if (showBefore) listOf(Color.Gray, Color.Black) else photo?.palette.orEmpty()))
                .padding(12.dp)
        ) {
            Text(
                if (showBefore) stringResource(R.string.original_raw) else state.activeLut?.name ?: stringResource(R.string.no_lut),
                color = Color.White,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .clip(RoundedCornerShape(99.dp))
                    .background(Color.Black.copy(alpha = 0.45f))
                    .padding(horizontal = 10.dp, vertical = 6.dp)
            )
        }

        Row(
            modifier = Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            (state.recommendedLuts + state.luts.filter { it !in state.recommendedLuts }).forEach { lut ->
                Column(
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(if (state.activeLutId == lut.id) Color.White.copy(alpha = 0.16f) else Color.White.copy(alpha = 0.08f))
                        .clickable { state.activeLutId = lut.id }
                        .padding(10.dp)
                ) {
                    LutStrip(lut.previewColors, Modifier.fillMaxWidth())
                    Text(lut.name, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 8.dp))
                    lut.confidence?.let {
                        Text(stringResource(R.string.cv_percent, it), color = AccentGreen, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }

        Column(
            modifier = Modifier
                .clip(RoundedCornerShape(16.dp))
                .background(Color.White.copy(alpha = 0.08f))
                .padding(14.dp)
        ) {
            Text(stringResource(R.string.lut_intensity_percent, (state.lutIntensity * 100).toInt()), color = Color.White, fontWeight = FontWeight.SemiBold)
            Slider(value = state.lutIntensity, onValueChange = { state.lutIntensity = it })
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(onClick = { showBefore = !showBefore }) { Text(if (showBefore) stringResource(R.string.show_after) else stringResource(R.string.before)) }
                Button(onClick = { state.lutIntensity = 0f }) { Text(stringResource(R.string.undo)) }
                Button(onClick = { state.applyActiveLutToCurrentPhoto() }) { Text(stringResource(R.string.save)) }
            }
        }
    }
}
