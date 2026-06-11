package com.lutshop.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
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
import com.lutshop.Photo
import com.lutshop.PhotoStatus
import com.lutshop.R
import androidx.compose.ui.res.stringResource

@Composable
fun GalleryScreen(state: LutShopAppState) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color.Black, Color(0xFF0C1112))))
            .padding(horizontal = 14.dp, vertical = 24.dp)
            .padding(bottom = 142.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("lut-shop", color = Color.White, fontSize = 38.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.weight(1f))
            Row(
                modifier = Modifier
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.08f))
                    .padding(horizontal = 12.dp, vertical = 9.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(Color(0xFF53D06D))
                )
                Text("Canon R5 · Connected", color = Color.White.copy(alpha = 0.7f), fontSize = 13.sp)
            }
        }

        Row(Modifier.padding(top = 18.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedTextField(
                value = state.searchText,
                onValueChange = { state.searchText = it },
                leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = stringResource(R.string.search), tint = Color.White.copy(alpha = 0.62f)) },
                placeholder = { Text(stringResource(R.string.search), color = Color.White.copy(alpha = 0.46f)) },
                modifier = Modifier.weight(1f),
                singleLine = true
            )
            Icon(Icons.Outlined.FilterList, contentDescription = "Filter", tint = Color.White, modifier = Modifier.padding(top = 15.dp))
            Icon(Icons.Outlined.StarBorder, contentDescription = "Favorite", tint = Color.White, modifier = Modifier.padding(top = 15.dp))
        }

        Row(
            modifier = Modifier
                .padding(top = 14.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(Color.White.copy(alpha = 0.08f))
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Outlined.CalendarMonth, contentDescription = null, tint = Color.White.copy(alpha = 0.78f))
            Column(Modifier.padding(start = 12.dp)) {
                Text(stringResource(R.string.session), color = Color.White.copy(alpha = 0.48f), fontSize = 11.sp)
                Text("2026-06-08  Studio Shoot", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.weight(1f))
            Text("142 photos", color = Color.White.copy(alpha = 0.66f), fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        }

        Row(Modifier.padding(top = 14.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            FilterTab(stringResource(R.string.all), null, state)
            FilterTab(stringResource(R.string.new_photos), PhotoStatus.Raw, state)
            FilterTab(stringResource(R.string.edited), PhotoStatus.Edited, state)
            FilterTab(stringResource(R.string.favorites), null, state)
            FilterTab(stringResource(R.string.exported), PhotoStatus.Exported, state)
        }

        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            modifier = Modifier.padding(top = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            items(state.filteredPhotos) { photo ->
                PhotoTile(state, photo)
            }
        }
    }
}

@Composable
private fun FilterTab(label: String, status: PhotoStatus?, state: LutShopAppState) {
    val selected = state.activeFilter == status
    Text(
        label,
        color = if (selected) Color.White else Color.White.copy(alpha = 0.62f),
        fontSize = 14.sp,
        fontWeight = FontWeight.Medium,
        modifier = Modifier.clickable { state.activeFilter = status }
    )
}

@Composable
private fun PhotoTile(state: LutShopAppState, photo: Photo) {
    Box(
        modifier = Modifier
            .aspectRatio(0.82f)
            .clip(RoundedCornerShape(8.dp))
            .background(Brush.linearGradient(photo.palette))
            .clickable { state.openPhoto(photo.id) }
            .padding(7.dp)
    ) {
        Text(
            stringResource(photo.status.labelRes),
            color = Color.White,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .align(Alignment.TopStart)
                .clip(RoundedCornerShape(5.dp))
                .background(Color.Black.copy(alpha = 0.45f))
                .padding(horizontal = 6.dp, vertical = 4.dp)
        )
        Icon(
            imageVector = when {
                photo.isSelected -> Icons.Outlined.CheckCircle
                photo.isFavorite -> Icons.Outlined.Star
                else -> Icons.Outlined.StarBorder
            },
            contentDescription = null,
            tint = if (photo.isSelected) AccentGreen else if (photo.isFavorite) Color.Yellow else Color.White.copy(alpha = 0.78f),
            modifier = Modifier.align(Alignment.TopEnd)
        )
        Text(photo.fileName, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Medium, modifier = Modifier.align(Alignment.BottomStart))
    }
}
