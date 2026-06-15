package com.lutshop.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.lutshop.LutShopAppState
import com.lutshop.MainTab

val AccentGreen = Color(0xFF8FCC56)

@Composable
fun LutShopApp(state: LutShopAppState) {
    MaterialTheme {
        Surface(color = Color.Black) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black)
                    .windowInsetsPadding(WindowInsets.systemBars)
            ) {
                when (state.selectedTab) {
                    MainTab.Gallery -> GalleryScreen(state)
                    MainTab.Preview -> PreviewScreen(state)
                    MainTab.Luts -> LutsScreen(state)
                    MainTab.Watermark -> WatermarkScreen(state)
                    MainTab.Export -> ExportScreen(state)
                }
                BottomChrome(state)
            }
        }
    }
}
