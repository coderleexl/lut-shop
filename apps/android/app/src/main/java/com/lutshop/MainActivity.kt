package com.lutshop

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.lifecycle.ViewModelProvider
import com.lutshop.data.LutLibraryStore
import com.lutshop.data.PhotoLibraryStore
import com.lutshop.ui.LutShopApp

class MainActivity : ComponentActivity() {
    private val photoStore by lazy { PhotoLibraryStore(applicationContext) }
    private val lutStore by lazy { LutLibraryStore(applicationContext) }
    private val state by lazy {
        ViewModelProvider(this, LutShopAppState.Factory(application, photoStore, lutStore))[LutShopAppState::class.java]
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            LutShopApp(state)
        }
    }
}
