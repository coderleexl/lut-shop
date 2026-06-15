package com.lutshop.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.FileUpload
import androidx.compose.material.icons.outlined.GridView
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material.icons.outlined.Title
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import com.lutshop.Photo
import com.lutshop.R
import androidx.compose.ui.res.stringResource

fun safeLinearGradient(colors: List<Color>): Brush {
    val safeColors = when {
        colors.size >= 2 -> colors
        colors.size == 1 -> listOf(colors.first(), colors.first().copy(alpha = 0.72f))
        else -> listOf(Color(0xFF777777), Color(0xFF111111))
    }
    return Brush.linearGradient(safeColors)
}

@Composable
fun BottomChrome(state: LutShopAppState) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.Bottom
    ) {
        Spacer(modifier = Modifier.weight(1f))
        if (state.selectedTab == MainTab.Gallery && state.selectedPhotos.isNotEmpty()) {
            SelectionBar(state, state.selectedPhotos.first())
        }
        BottomTabs(state)
    }
}

@Composable
fun SelectionBar(state: LutShopAppState, photo: Photo) {
    Row(
        modifier = Modifier
            .padding(horizontal = 6.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Color(0xEE1A1D20))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(safeLinearGradient(photo.palette))
        )
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(stringResource(R.string.selected_count_lower, state.selectedPhotos.size), color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            Text(photo.fileName, color = Color.White.copy(alpha = 0.6f), fontSize = 14.sp)
        }
        SelectionAction(stringResource(R.string.apply_lut), Icons.Outlined.AutoAwesome) { state.applyActiveLutToSelection() }
        SelectionAction(stringResource(R.string.rate), Icons.Outlined.StarBorder) { state.rateCurrentPhoto(5) }
        SelectionAction(stringResource(R.string.export), Icons.Outlined.FileUpload) { state.selectedTab = MainTab.Export }
    }
}

@Composable
fun SelectionAction(label: String, icon: androidx.compose.ui.graphics.vector.ImageVector, action: () -> Unit) {
    Column(
        modifier = Modifier
            .width(62.dp)
            .clickable(onClick = action),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(icon, contentDescription = label, tint = Color.White, modifier = Modifier.size(22.dp))
        Text(label, color = Color.White, fontSize = 11.sp)
    }
}

@Composable
fun BottomTabs(state: LutShopAppState) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0xEE050607))
            .padding(horizontal = 8.dp, vertical = 8.dp)
    ) {
        MainTab.entries.forEach { tab ->
            val selected = state.selectedTab == tab
            Column(
                modifier = Modifier
                    .weight(1f)
                    .height(58.dp)
                    .clickable {
                        state.showCameraImportPanel = false
                        state.selectedTab = tab
                    },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                val icon = when (tab) {
                    MainTab.Gallery -> Icons.Outlined.PhotoLibrary
                    MainTab.Preview -> Icons.Outlined.GridView
                    MainTab.Luts -> Icons.Outlined.AutoAwesome
                    MainTab.Watermark -> Icons.Outlined.Title
                    MainTab.Export -> Icons.Outlined.FileUpload
                }
                Icon(icon, contentDescription = stringResource(tab.labelRes), tint = if (selected) AccentGreen else Color.White.copy(alpha = 0.62f))
                Text(stringResource(tab.labelRes), color = if (selected) AccentGreen else Color.White.copy(alpha = 0.62f), fontSize = 12.sp)
            }
        }
    }
}

@Composable
fun LutStrip(colors: List<Color>, modifier: Modifier = Modifier) {
    Row(modifier = modifier.clip(CircleShape)) {
        colors.forEach { color ->
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(34.dp)
                    .background(color)
            )
        }
    }
}
