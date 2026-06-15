package com.lutshop.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.FolderOpen
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lutshop.LutCategory
import com.lutshop.LutCategoryGroup
import com.lutshop.LutPreset
import com.lutshop.LutShopAppState
import com.lutshop.MainTab
import com.lutshop.R

@Composable
fun LutsScreen(state: LutShopAppState) {
    var category by remember { mutableStateOf<LutCategory?>(null) }
    var query by remember { mutableStateOf("") }
    var showAddDialog by remember { mutableStateOf(false) }
    var showGroupManager by remember { mutableStateOf(false) }
    var editingLut by remember { mutableStateOf<LutPreset?>(null) }
    val visible = state.luts.filter {
        (category == null || it.category == category) && (query.isBlank() || it.name.contains(query, ignoreCase = true))
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(horizontal = 14.dp, vertical = 16.dp)
            .padding(bottom = 76.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.lut_library), color = Color.White, fontSize = 32.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.weight(1f))
            IconButton(onClick = { showGroupManager = true }) {
                Icon(Icons.Outlined.FolderOpen, contentDescription = stringResource(R.string.manage_groups), tint = Color.White)
            }
            IconButton(onClick = { showAddDialog = true }) {
                Icon(Icons.Outlined.Add, contentDescription = stringResource(R.string.add_lut), tint = AccentGreen)
            }
        }

        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            placeholder = { Text(stringResource(R.string.search_lut)) },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        // Category filter - hide Custom, show user groups instead
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            CategoryChip(stringResource(R.string.all), category == null) { category = null }
            LutCategory.entries.filter { it != LutCategory.Custom }.forEach { item ->
                CategoryChip(stringResource(item.labelRes), category == item) { category = item }
            }
        }

        LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(visible) { lut ->
                LutRow(lut = lut, state = state, onEdit = { editingLut = lut })
            }
        }
    }

    if (showAddDialog) {
        AddLutDialog(
            onDismiss = { showAddDialog = false },
            onAdd = { name, path, cat ->
                state.addLut(name, path, cat)
                showAddDialog = false
            }
        )
    }

    if (showGroupManager) {
        LutGroupManagerDialog(
            state = state,
            onDismiss = { showGroupManager = false }
        )
    }

    editingLut?.let { lut ->
        LutDetailDialog(
            lut = lut,
            state = state,
            onDismiss = { editingLut = null }
        )
    }
}

@Composable
private fun LutRow(lut: LutPreset, state: LutShopAppState, onEdit: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .clickable {
                state.activeLutId = lut.id
                state.selectedTab = MainTab.Preview
            }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        LutStrip(lut.previewColors, Modifier.fillMaxWidth(0.22f))
        Column(Modifier.padding(start = 12.dp).weight(1f)) {
            Text(lut.name, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            if (lut.sourceFileName != null) {
                Text(lut.sourceFileName, color = Color.White.copy(alpha = 0.4f), fontSize = 11.sp)
            }
            Text(
                stringResource(R.string.category_usage_count, getCategoryLabel(lut.category), lut.usageCount),
                color = Color.White.copy(alpha = 0.56f),
                fontSize = 12.sp
            )
        }
        IconButton(onClick = { state.toggleLutFavorite(lut.id) }, modifier = Modifier.size(24.dp)) {
            Icon(
                if (lut.isFavorite) Icons.Outlined.Star else Icons.Outlined.StarBorder,
                contentDescription = null,
                tint = if (lut.isFavorite) Color.Yellow else Color.White.copy(alpha = 0.5f),
                modifier = Modifier.size(20.dp)
            )
        }
        Spacer(Modifier.width(4.dp))
        IconButton(onClick = onEdit, modifier = Modifier.size(24.dp)) {
            Icon(Icons.Outlined.Info, contentDescription = null, tint = Color.White.copy(alpha = 0.5f), modifier = Modifier.size(20.dp))
        }
    }
}

private fun getCategoryLabel(cat: LutCategory): String {
    return when (cat) {
        LutCategory.Portrait -> "Portrait"
        LutCategory.Landscape -> "Landscape"
        LutCategory.Film -> "Film"
        LutCategory.BlackWhite -> "B&W"
        LutCategory.Commercial -> "Commercial"
        LutCategory.Custom -> "Custom"
    }
}

@Composable
private fun AddLutDialog(onDismiss: () -> Unit, onAdd: (String, String, LutCategory) -> Unit) {
    var name by remember { mutableStateOf("") }
    var path by remember { mutableStateOf("") }
    var category by remember { mutableStateOf(LutCategory.Portrait) }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF1A1D20),
        title = { Text(stringResource(R.string.add_lut), color = Color.White) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text(stringResource(R.string.lut_name)) }, singleLine = true)
                OutlinedTextField(value = path, onValueChange = { path = it }, label = { Text(stringResource(R.string.lut_path)) }, singleLine = true)
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    LutCategory.entries.filter { it != LutCategory.Custom }.forEach { cat ->
                        CategoryChip(stringResource(cat.labelRes), category == cat) { category = cat }
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = { onAdd(name, path, category) }) { Text(stringResource(R.string.add), color = AccentGreen) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel), color = Color.White.copy(alpha = 0.6f)) } }
    )
}

@Composable
private fun LutDetailDialog(
    lut: LutPreset,
    state: LutShopAppState,
    onDismiss: () -> Unit
) {
    var editName by remember { mutableStateOf(lut.name) }
    var showCategoryPicker by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF1A1D20),
        title = { Text(lut.name, color = Color.White) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                LutStrip(lut.previewColors, Modifier.fillMaxWidth())

                OutlinedTextField(
                    value = editName,
                    onValueChange = { editName = it },
                    label = { Text(stringResource(R.string.lut_name)) },
                    singleLine = true
                )

                if (lut.sourceFileName != null) {
                    Text("File: ${lut.sourceFileName}.cube", color = Color.White.copy(alpha = 0.5f), fontSize = 12.sp)
                }
                if (lut.cubeSize > 0) {
                    Text(stringResource(R.string.cube_size, lut.cubeSize), color = Color.White.copy(alpha = 0.5f), fontSize = 12.sp)
                }
                if (lut.cubeEntryCount > 0) {
                    Text(stringResource(R.string.cube_entries, lut.cubeEntryCount), color = Color.White.copy(alpha = 0.5f), fontSize = 12.sp)
                }

                OutlinedButton(onClick = { showCategoryPicker = !showCategoryPicker }) {
                    Text(
                        stringResource(R.string.category_label, getCategoryLabel(lut.category)),
                        color = Color.White
                    )
                }
                if (showCategoryPicker) {
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        LutCategory.entries.filter { it != LutCategory.Custom }.forEach { cat ->
                            CategoryChip(stringResource(cat.labelRes), lut.category == cat) {
                                state.changeLutCategory(lut.id, cat)
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            Row {
                if (!lut.isBundled) {
                    TextButton(onClick = {
                        state.deleteLut(lut.id)
                        onDismiss()
                    }) {
                        Text(stringResource(R.string.delete), color = Color(0xFFFF6B6B))
                    }
                }
                Spacer(Modifier.weight(1f))
                TextButton(onClick = onDismiss) {
                    Text(stringResource(R.string.cancel), color = Color.White.copy(alpha = 0.6f))
                }
                TextButton(onClick = {
                    state.renameLut(lut.id, editName)
                    onDismiss()
                }) {
                    Text(stringResource(R.string.save), color = AccentGreen)
                }
            }
        }
    )
}

@Composable
private fun LutGroupManagerDialog(
    state: LutShopAppState,
    onDismiss: () -> Unit
) {
    var newGroupName by remember { mutableStateOf("") }
    var editingGroup by remember { mutableStateOf<String?>(null) }
    var editGroupName by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF1A1D20),
        title = { Text(stringResource(R.string.manage_groups), color = Color.White) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                // Add new group
                Row(verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(
                        value = newGroupName,
                        onValueChange = { newGroupName = it },
                        label = { Text(stringResource(R.string.new_group)) },
                        singleLine = true,
                        modifier = Modifier.weight(1f)
                    )
                    Spacer(Modifier.width(8.dp))
                    TextButton(onClick = {
                        state.addUserCategory(newGroupName)
                        newGroupName = ""
                    }) {
                        Text(stringResource(R.string.add), color = AccentGreen)
                    }
                }

                // Group list
                state.lutGroups.forEach { group ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(Color.White.copy(alpha = 0.06f))
                            .padding(horizontal = 12.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        if (editingGroup == group.name) {
                            OutlinedTextField(
                                value = editGroupName,
                                onValueChange = { editGroupName = it },
                                singleLine = true,
                                modifier = Modifier.weight(1f)
                            )
                            TextButton(onClick = {
                                state.renameUserCategory(group.name, editGroupName)
                                editingGroup = null
                            }) {
                                Text(stringResource(R.string.save), color = AccentGreen)
                            }
                            TextButton(onClick = { editingGroup = null }) {
                                Text(stringResource(R.string.cancel), color = Color.White.copy(alpha = 0.6f))
                            }
                        } else {
                            Column(Modifier.weight(1f)) {
                                Text(group.name, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Medium)
                                Text(
                                    if (group.isSystem) stringResource(R.string.system_group) else stringResource(R.string.custom_group),
                                    color = Color.White.copy(alpha = 0.4f),
                                    fontSize = 11.sp
                                )
                            }
                            if (!group.isSystem) {
                                IconButton(onClick = {
                                    editGroupName = group.name
                                    editingGroup = group.name
                                }, modifier = Modifier.size(24.dp)) {
                                    Icon(Icons.Outlined.Edit, contentDescription = stringResource(R.string.rename), tint = Color.White.copy(alpha = 0.6f), modifier = Modifier.size(18.dp))
                                }
                                Spacer(Modifier.width(4.dp))
                                IconButton(onClick = {
                                    state.deleteUserCategory(group.name)
                                }, modifier = Modifier.size(24.dp)) {
                                    Icon(Icons.Outlined.Delete, contentDescription = stringResource(R.string.delete), tint = Color(0xFFFF6B6B), modifier = Modifier.size(18.dp))
                                }
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.done), color = AccentGreen)
            }
        }
    )
}

@Composable
private fun CategoryChip(label: String, selected: Boolean, action: () -> Unit) {
    Text(
        label,
        color = if (selected) AccentGreen else Color.White.copy(alpha = 0.72f),
        fontWeight = FontWeight.SemiBold,
        fontSize = 13.sp,
        modifier = Modifier
            .clip(CircleShape)
            .background(if (selected) AccentGreen.copy(alpha = 0.25f) else Color.White.copy(alpha = 0.08f))
            .clickable(onClick = action)
            .padding(horizontal = 13.dp, vertical = 9.dp)
    )
}
