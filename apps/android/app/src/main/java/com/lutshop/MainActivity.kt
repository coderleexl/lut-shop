package com.lutshop

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import com.lutshop.ui.LutShopApp

class MainActivity : ComponentActivity() {
    private val state by viewModels<LutShopAppState>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            LutShopApp(state)
        }
    }
}
