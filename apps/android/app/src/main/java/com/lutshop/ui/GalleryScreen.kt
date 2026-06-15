package com.lutshop.ui

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.SelectAll
import androidx.compose.material.icons.outlined.Sort
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lutshop.LutShopAppState
import com.lutshop.Photo
import com.lutshop.PhotoSortOption
import com.lutshop.PhotoStatus
import com.lutshop.R

@Composable
fun GalleryScreen(state: LutShopAppState) {
    val context = LocalContext.current
    var showSortMenu by remember { mutableStateOf(false) }
    var showSessionMenu by remember { mutableStateOf(false) }
    var showImportMenu by remember { mutableStateOf(false) }
    val pickerLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia()
    ) { uris ->
        if (uris.isNotEmpty()) state.importPhotoUris(context, uris)
    }
    val fileLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenMultipleDocuments()
    ) { uris: List<Uri> ->
        if (uris.isNotEmpty()) state.importPhotoUris(context, uris)
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color.Black, Color(0xFF0C1112))))
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 14.dp, vertical = 16.dp)
                .padding(bottom = 76.dp)
        ) {
            // Header
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("lut-shop", color = Color.White, fontSize = 38.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.weight(1f))
                if (state.isSelectionMode) {
                    val count = state.selectedPhotos.size
                    Text(
                        if (count > 0) stringResource(R.string.select_n, count) else stringResource(R.string.select),
                        color = AccentGreen,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.clickable { state.isSelectionMode = false }
                    )
                } else {
                    IconButton(onClick = { state.showCameraImportPanel = true }) {
                        Icon(Icons.Outlined.CameraAlt, contentDescription = stringResource(R.string.camera_receive), tint = Color.White)
                    }
                    Text(
                        stringResource(R.string.select),
                        color = Color.White.copy(alpha = 0.7f),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.clickable { state.isSelectionMode = true }
                    )
                }
            }

            if (state.isFtpReceiverRunning || state.ftpReceivedCount > 0) {
                CameraReceiveBanner(
                    state = state,
                    onClick = { state.showCameraImportPanel = true },
                    modifier = Modifier.padding(top = 10.dp)
                )
            }

            // Selection toolbar
            if (state.isSelectionMode) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 10.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        stringResource(R.string.selected_count_lower, state.selectedPhotos.size),
                        color = Color.White,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium
                    )
                    Spacer(Modifier.weight(1f))
                    IconButton(onClick = { state.selectAllFilteredPhotos() }) {
                        Icon(Icons.Outlined.SelectAll, contentDescription = stringResource(R.string.select_all), tint = Color.White)
                    }
                    IconButton(onClick = { state.clearSelection() }) {
                        Icon(Icons.Outlined.FilterList, contentDescription = stringResource(R.string.clear_selection), tint = Color.White)
                    }
                    IconButton(onClick = { state.deleteSelectedPhotos() }) {
                        Icon(Icons.Outlined.Delete, contentDescription = stringResource(R.string.delete), tint = Color(0xFFFF6B6B))
                    }
                }
            }

            // Search, sort, favorites (hidden in selection mode)
            if (!state.isSelectionMode) {
                Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(
                        value = state.searchText,
                        onValueChange = { state.searchText = it },
                        leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = stringResource(R.string.search), tint = Color.White.copy(alpha = 0.62f)) },
                        placeholder = { Text(stringResource(R.string.search), color = Color.White.copy(alpha = 0.46f)) },
                        modifier = Modifier.weight(1f),
                        singleLine = true
                    )
                    Box {
                        IconButton(onClick = { showSortMenu = true }, modifier = Modifier.padding(top = 8.dp)) {
                            Icon(Icons.Outlined.Sort, contentDescription = stringResource(R.string.sort), tint = Color.White)
                        }
                        DropdownMenu(
                            expanded = showSortMenu,
                            onDismissRequest = { showSortMenu = false }
                        ) {
                            PhotoSortOption.entries.forEach { option ->
                                DropdownMenuItem(
                                    text = { Text(stringResource(option.labelRes), color = if (state.photoSortOption == option) AccentGreen else Color.White) },
                                    onClick = { state.photoSortOption = option; showSortMenu = false }
                                )
                            }
                        }
                    }
                    IconButton(onClick = { state.showFavoritesOnly = !state.showFavoritesOnly }, modifier = Modifier.padding(top = 8.dp)) {
                        Icon(
                            if (state.showFavoritesOnly) Icons.Outlined.Star else Icons.Outlined.StarBorder,
                            contentDescription = stringResource(R.string.favorites),
                            tint = if (state.showFavoritesOnly) Color.Yellow else Color.White
                        )
                    }
                }
            }

            // Session bar with dropdown
            if (!state.isSelectionMode && state.sessions.isNotEmpty()) {
                Box {
                    Row(
                        modifier = Modifier
                            .padding(top = 12.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(Color.White.copy(alpha = 0.08f))
                            .clickable { showSessionMenu = true }
                            .padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Outlined.CalendarMonth, contentDescription = null, tint = Color.White.copy(alpha = 0.78f))
                        Column(Modifier.padding(start = 12.dp)) {
                            Text(stringResource(R.string.session), color = Color.White.copy(alpha = 0.48f), fontSize = 11.sp)
                            Text(
                                state.selectedSessionName ?: stringResource(R.string.all_sessions),
                                color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold
                            )
                        }
                        Spacer(Modifier.weight(1f))
                        val count = if (state.selectedSessionName != null) {
                            state.photos.count { it.sessionName == state.selectedSessionName }
                        } else state.photos.size
                        Text(stringResource(R.string.n_photos, count), color = Color.White.copy(alpha = 0.66f), fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    }
                    DropdownMenu(
                        expanded = showSessionMenu,
                        onDismissRequest = { showSessionMenu = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.all_sessions), color = if (state.selectedSessionName == null) AccentGreen else Color.White) },
                            onClick = { state.selectedSessionName = null; showSessionMenu = false }
                        )
                        state.sessions.forEach { session ->
                            DropdownMenuItem(
                                text = {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text(session, color = if (state.selectedSessionName == session) AccentGreen else Color.White, modifier = Modifier.weight(1f))
                                        Text(
                                            stringResource(R.string.n_photos_in_session, state.photos.count { it.sessionName == session }),
                                            color = Color.White.copy(alpha = 0.5f),
                                            fontSize = 12.sp
                                        )
                                    }
                                },
                                onClick = { state.selectedSessionName = session; showSessionMenu = false }
                            )
                        }
                    }
                }
            }

            // Filter tabs
            Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                FilterTab(stringResource(R.string.all), null, state)
                FilterTab(stringResource(R.string.new_photos), PhotoStatus.Raw, state)
                FilterTab(stringResource(R.string.edited), PhotoStatus.Edited, state)
                FilterTabFavorites(state)
                FilterTab(stringResource(R.string.exported), PhotoStatus.Exported, state)
            }

            // Photo grid
            if (state.filteredPhotos.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize().padding(top = 48.dp),
                    contentAlignment = Alignment.TopCenter
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(stringResource(R.string.no_photos), color = Color.White.copy(alpha = 0.5f), fontSize = 16.sp)
                        Text(stringResource(R.string.import_photos_hint), color = Color.White.copy(alpha = 0.35f), fontSize = 13.sp, modifier = Modifier.padding(top = 6.dp))
                    }
                }
            } else {
                LazyVerticalGrid(
                    columns = GridCells.Fixed(3),
                    modifier = Modifier.fillMaxSize().padding(top = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    items(state.filteredPhotos) { photo ->
                        PhotoTile(state, photo)
                    }
                }
            }
        }

        // FAB + import menu
        if (!state.isSelectionMode) {
            Box(modifier = Modifier.align(Alignment.BottomEnd).padding(end = 16.dp, bottom = 90.dp)) {
                FloatingActionButton(
                    onClick = { showImportMenu = true },
                    containerColor = AccentGreen
                ) {
                    Icon(Icons.Outlined.Add, contentDescription = stringResource(R.string.import_photos), tint = Color.Black)
                }
                DropdownMenu(
                    expanded = showImportMenu,
                    onDismissRequest = { showImportMenu = false }
                ) {
                    DropdownMenuItem(
                        text = { Text(stringResource(R.string.import_photos)) },
                        onClick = {
                            showImportMenu = false
                            pickerLauncher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                        }
                    )
                    DropdownMenuItem(
                        text = { Text(stringResource(R.string.import_from_files)) },
                        onClick = {
                            showImportMenu = false
                            fileLauncher.launch(arrayOf("image/*", "application/octet-stream"))
                        }
                    )
                }
            }
        }

        // Camera import overlay
        if (state.showCameraImportPanel) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(bottom = 76.dp)
                    .background(Color.Black.copy(alpha = 0.92f))
                    .clickable { /* consume click */ }
            ) {
                IconButton(
                    onClick = { state.showCameraImportPanel = false },
                    modifier = Modifier.align(Alignment.TopEnd).padding(16.dp)
                ) {
                    Icon(Icons.Outlined.Close, contentDescription = "Close", tint = Color.White)
                }
                CameraImportScreen(state, onBackToGallery = { state.showCameraImportPanel = false })
            }
        }
    }
}

@Composable
private fun CameraReceiveBanner(
    state: LutShopAppState,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Box(
            modifier = Modifier
                .size(9.dp)
                .clip(CircleShape)
                .background(if (state.isFtpReceiverRunning) AccentGreen else Color.White.copy(alpha = 0.45f))
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                if (state.isFtpReceiverRunning) stringResource(R.string.ftp_receiver_running) else stringResource(R.string.ftp_receiver_stopped),
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                "${state.ftpConfiguration.host}:${state.ftpConfiguration.port} · ${stringResource(R.string.ftp_received)} ${state.ftpReceivedCount}",
                color = Color.White.copy(alpha = 0.58f),
                fontSize = 12.sp
            )
        }
        Text(
            state.ftpCurrentFileName.ifBlank { state.ftpLastFileName },
            color = Color.White.copy(alpha = 0.72f),
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            maxLines = 1
        )
    }
}

@Composable
private fun FilterTab(label: String, status: PhotoStatus?, state: LutShopAppState) {
    val selected = !state.showFavoritesOnly && state.activeFilter == status
    Text(
        label,
        color = if (selected) Color.White else Color.White.copy(alpha = 0.62f),
        fontSize = 14.sp,
        fontWeight = FontWeight.Medium,
        modifier = Modifier.clickable {
            state.showFavoritesOnly = false
            state.activeFilter = status
        }
    )
}

@Composable
private fun FilterTabFavorites(state: LutShopAppState) {
    val selected = state.showFavoritesOnly
    Text(
        stringResource(R.string.favorites),
        color = if (selected) Color.White else Color.White.copy(alpha = 0.62f),
        fontSize = 14.sp,
        fontWeight = FontWeight.Medium,
        modifier = Modifier.clickable {
            state.showFavoritesOnly = !state.showFavoritesOnly
            if (state.showFavoritesOnly) state.activeFilter = null
        }
    )
}

@Composable
private fun PhotoTile(state: LutShopAppState, photo: Photo) {
    val borderColor = when {
        state.isSelectionMode && photo.isSelected -> AccentGreen
        !state.isSelectionMode && photo.isSelected -> Color.White
        else -> Color.Transparent
    }
    Box(
        modifier = Modifier
            .aspectRatio(0.82f)
            .clip(RoundedCornerShape(8.dp))
            .border(BorderStroke(2.dp, borderColor), RoundedCornerShape(8.dp))
            .clickable { state.openOrTogglePhoto(photo.id) }
    ) {
        PhotoAsset(
            uri = photo.uri,
            localPath = photo.localPath,
            fallbackColors = photo.palette,
            modifier = Modifier.matchParentSize(),
            renderedImagePath = photo.renderedImagePath
        )
        Box(modifier = Modifier.matchParentSize().padding(7.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(photo.status.labelRes),
                    color = Color.White,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .clip(RoundedCornerShape(5.dp))
                        .background(Color.Black.copy(alpha = 0.45f))
                        .padding(horizontal = 6.dp, vertical = 4.dp)
                )
                Spacer(Modifier.width(4.dp))
                Text(
                    photo.formatBadgeText,
                    color = Color.White.copy(alpha = 0.8f),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .clip(RoundedCornerShape(4.dp))
                        .background(Color.Black.copy(alpha = 0.35f))
                        .padding(horizontal = 5.dp, vertical = 3.dp)
                )
            }
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
            Column(modifier = Modifier.align(Alignment.BottomStart)) {
                Text(photo.fileName, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                if (photo.rating > 0) {
                    Text("★".repeat(photo.rating), color = Color.Yellow, fontSize = 10.sp)
                }
            }
        }
    }
}
