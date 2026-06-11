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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lutshop.LutCategory
import com.lutshop.LutShopAppState
import com.lutshop.MainTab
import com.lutshop.R
import androidx.compose.ui.res.stringResource

@Composable
fun LutsScreen(state: LutShopAppState) {
    var category by remember { mutableStateOf<LutCategory?>(null) }
    var query by remember { mutableStateOf("") }
    val visible = state.luts.filter {
        (category == null || it.category == category) && (query.isBlank() || it.name.contains(query, ignoreCase = true))
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(horizontal = 14.dp, vertical = 24.dp)
            .padding(bottom = 76.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text(stringResource(R.string.lut_library), color = Color.White, fontSize = 32.sp, fontWeight = FontWeight.Bold)
        OutlinedTextField(value = query, onValueChange = { query = it }, placeholder = { Text(stringResource(R.string.search_lut)) }, modifier = Modifier.fillMaxWidth(), singleLine = true)

        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            CategoryChip(stringResource(R.string.all), category == null) { category = null }
            LutCategory.entries.forEach { item ->
                CategoryChip(stringResource(item.labelRes), category == item) { category = item }
            }
        }

        LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(visible) { lut ->
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(14.dp))
                        .background(Color.White.copy(alpha = 0.08f))
                        .clickable {
                            state.activeLutId = lut.id
                            state.selectedTab = MainTab.Preview
                        }
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    LutStrip(lut.previewColors, Modifier.fillMaxWidth(0.24f))
                    Column(Modifier.padding(start = 12.dp)) {
                        Text(lut.name, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                        Text(stringResource(R.string.category_usage_count, stringResource(lut.category.labelRes), lut.usageCount), color = Color.White.copy(alpha = 0.56f), fontSize = 12.sp)
                    }
                    Spacer(Modifier.weight(1f))
                    if (lut.isFavorite) Text("★", color = Color.Yellow)
                }
            }
        }
    }
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
