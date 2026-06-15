# Android iOS Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Android app from early Compose mock prototype to functional parity with the current iOS first version.

**Architecture:** Android should mirror the iOS product behavior while keeping platform-specific responsibilities on Android: Photo Picker, MediaStore, permissions, Bitmap decode/encode, and foreground UI stay in Kotlin/Compose. Shared workflow and LUT parsing/rendering should move through the existing C++ core via JNI/NDK, using the C ABI in `core/include/lutshop/bridge_c.h` first, then expanding to coarse workflow APIs.

**Tech Stack:** Kotlin, Jetpack Compose, AndroidX Activity Result APIs, MediaStore, DataStore or JSON file persistence, Android NDK/CMake, JNI, shared C++ core, Android Studio/Gradle.

---

## Current Android Baseline

The Android app currently has:

- Compose shell with Gallery / Preview / LUT / Export tabs.
- Mock photos and mock LUTs in Kotlin.
- Basic dark UI.
- Basic search, filter, selection, preview slider, fake export progress.
- English and Simplified Chinese strings.

It does not yet have:

- Gradle wrapper.
- Real image import.
- Real image rendering.
- Persistent gallery index.
- Real LUT loading/rendering.
- JNI/NDK bridge to C++ core.
- LUT CRUD.
- Session management.
- Export to MediaStore.
- Sony/camera FTP receive.
- App icon and Android launcher polish.

## Target Behavior Matching iOS First Version

The Android app should support:

- Import from system photo picker and files.
- Persist imported photo index across app restarts.
- Gallery search, filtering, sorting, session display/management, rating, favorite, delete.
- Selection mode with select all, done preserving selection, white border for retained selection set, and clear selection.
- Preview with before/after comparison, LUT selection, LUT intensity, save, undo, toast, and sync current saved adjustment to other selected photos excluding current photo.
- LUT library with categories, user-created categories, add LUT by local or remote path, rename, delete, favorite, detail category switching.
- Export page without LUT picker; export reads each photo's saved adjustment and writes output to Android Photos/MediaStore.
- Bundled LUT files and real C++ LUT application.
- Basic Sony/camera receive entry and an Android-appropriate plan for FTP receiving.

---

## Phase 0: Make Android Build Reproducible

### Task 0.1: Add Gradle Wrapper

**Files:**
- Create: `apps/android/gradlew`
- Create: `apps/android/gradlew.bat`
- Create: `apps/android/gradle/wrapper/gradle-wrapper.jar`
- Create: `apps/android/gradle/wrapper/gradle-wrapper.properties`

- [ ] Run from `apps/android`:

```bash
gradle wrapper --gradle-version 8.10.2
```

- [ ] Verify:

```bash
cd apps/android
./gradlew :app:assembleDebug
```

Expected:

```text
BUILD SUCCESSFUL
```

- [ ] Commit:

```bash
git add apps/android/gradlew apps/android/gradlew.bat apps/android/gradle/wrapper
git commit -m "chore(android): add gradle wrapper"
```

### Task 0.2: Add Android Quick Start Script

**Files:**
- Create: `android.sh`
- Modify: `README.md`
- Modify: `apps/android/README.md`

- [ ] Create `android.sh` at repo root:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$ROOT_DIR/apps/android"

cd "$ANDROID_DIR"
./gradlew :app:assembleDebug

if command -v adb >/dev/null 2>&1; then
  APK="$ANDROID_DIR/app/build/outputs/apk/debug/app-debug.apk"
  adb install -r "$APK"
  adb shell monkey -p com.lutshop 1
else
  echo "Build complete. adb not found, skipping install."
fi
```

- [ ] Make it executable:

```bash
chmod +x android.sh
```

- [ ] Update README with:

```markdown
## Android 快速开始

```bash
./android.sh
```

The script builds the debug APK and installs it with adb when an Android device or emulator is connected.
```

- [ ] Verify:

```bash
./android.sh
```

Expected:

```text
BUILD SUCCESSFUL
```

- [ ] Commit:

```bash
git add android.sh README.md apps/android/README.md
git commit -m "docs(android): add quick start"
```

---

## Phase 1: Replace Mock Gallery With Real Import And Persistence

### Task 1.1: Expand Android Data Models

**Files:**
- Modify: `apps/android/app/src/main/java/com/lutshop/Models.kt`

- [ ] Replace `Photo` with fields needed for real import:

```kotlin
data class Photo(
    val id: String,
    val fileName: String,
    val uri: String,
    val localPath: String?,
    val importedAt: Long,
    val sessionName: String,
    val status: PhotoStatus,
    val isFavorite: Boolean,
    val isSelected: Boolean,
    val rating: Int,
    val appliedLutId: String?,
    val lutIntensity: Float,
    val recommendedLutIds: List<String>,
    val palette: List<Color>
) {
    val formatBadgeText: String
        get() {
            val ext = fileName.substringAfterLast('.', "").lowercase()
            return when (ext) {
                "raw", "dng", "arw", "cr2", "cr3", "nef", "nrw", "orf", "pef", "raf", "rw2", "srw" -> "RAW"
                "jpg", "jpeg" -> "JPG"
                "" -> "IMG"
                else -> ext.uppercase()
            }
        }
}
```

- [ ] Update `MockLutShopCoreBridge.photo(...)` to provide `uri`, `localPath`, and `importedAt`.

- [ ] Build:

```bash
cd apps/android
./gradlew :app:assembleDebug
```

- [ ] Commit:

```bash
git add apps/android/app/src/main/java/com/lutshop/Models.kt apps/android/app/src/main/java/com/lutshop/core/LutShopCoreBridge.kt
git commit -m "feat(android): expand photo model"
```

### Task 1.2: Add Photo Index Persistence

**Files:**
- Create: `apps/android/app/src/main/java/com/lutshop/data/PhotoLibraryStore.kt`
- Modify: `apps/android/app/build.gradle.kts`
- Modify: `apps/android/app/src/main/java/com/lutshop/AppState.kt`

- [ ] Add Kotlin serialization dependency:

```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization") version "1.9.25"
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
}
```

- [ ] Create `PhotoLibraryStore.kt`:

```kotlin
package com.lutshop.data

import android.content.Context
import com.lutshop.Photo
import com.lutshop.PhotoStatus
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import androidx.compose.ui.graphics.Color
import java.io.File

@Serializable
data class PersistedPhotoLibrary(
    val photos: List<PersistedPhoto>,
    val sessions: List<String>
)

@Serializable
data class PersistedPhoto(
    val id: String,
    val fileName: String,
    val uri: String,
    val localPath: String?,
    val importedAt: Long,
    val sessionName: String,
    val status: String,
    val isFavorite: Boolean,
    val rating: Int,
    val appliedLutId: String?,
    val lutIntensity: Float,
    val recommendedLutIds: List<String>
)

class PhotoLibraryStore(private val context: Context) {
    private val json = Json { ignoreUnknownKeys = true; prettyPrint = true }
    private val file: File
        get() = File(context.filesDir, "PhotoLibraryIndex.json")

    fun load(): Pair<List<Photo>, List<String>>? {
        if (!file.exists()) return null
        val payload = json.decodeFromString<PersistedPhotoLibrary>(file.readText())
        val photos = payload.photos.mapNotNull { item ->
            if (item.localPath != null && !File(item.localPath).exists()) return@mapNotNull null
            Photo(
                id = item.id,
                fileName = item.fileName,
                uri = item.uri,
                localPath = item.localPath,
                importedAt = item.importedAt,
                sessionName = item.sessionName,
                status = PhotoStatus.valueOf(item.status),
                isFavorite = item.isFavorite,
                isSelected = false,
                rating = item.rating,
                appliedLutId = item.appliedLutId,
                lutIntensity = item.lutIntensity,
                recommendedLutIds = item.recommendedLutIds,
                palette = listOf(Color.Gray, Color.Black)
            )
        }
        val sessions = (payload.sessions + photos.map { it.sessionName }).filter { it.isNotBlank() }.distinct().sorted()
        return photos to sessions
    }

    fun save(photos: List<Photo>, sessions: List<String>) {
        val payload = PersistedPhotoLibrary(
            photos = photos.map {
                PersistedPhoto(
                    id = it.id,
                    fileName = it.fileName,
                    uri = it.uri,
                    localPath = it.localPath,
                    importedAt = it.importedAt,
                    sessionName = it.sessionName,
                    status = it.status.name,
                    isFavorite = it.isFavorite,
                    rating = it.rating,
                    appliedLutId = it.appliedLutId,
                    lutIntensity = it.lutIntensity,
                    recommendedLutIds = it.recommendedLutIds
                )
            },
            sessions = sessions
        )
        file.writeText(json.encodeToString(payload))
    }
}
```

- [ ] In `AppState.kt`, add constructor dependency `private val photoStore: PhotoLibraryStore? = null`, load persisted photos when present, and call `photoStore?.save(photos, sessions)` after favorite/rating/apply/export/delete/import changes.

- [ ] Build:

```bash
cd apps/android
./gradlew :app:assembleDebug
```

- [ ] Commit:

```bash
git add apps/android
git commit -m "feat(android): persist gallery index"
```

### Task 1.3: Add Real Photo Picker Import

**Files:**
- Modify: `apps/android/app/src/main/java/com/lutshop/MainActivity.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/AppState.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/ui/GalleryScreen.kt`
- Modify: `apps/android/app/src/main/res/values/strings.xml`
- Modify: `apps/android/app/src/main/res/values-zh-rCN/strings.xml`

- [ ] In `MainActivity.kt`, create `PhotoLibraryStore(applicationContext)` and pass it to `LutShopAppState` using a `ViewModelProvider.Factory`.

- [ ] Add `importPhotoUris(context: Context, uris: List<Uri>)` to `AppState.kt`. It must copy each URI to `context.filesDir/ImportedPhotos`, create `Photo` records, insert them at the front, and persist.

- [ ] In `GalleryScreen.kt`, add `rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia())`, and wire an import button to launch:

```kotlin
launcher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
```

- [ ] Verify manually:
  - Launch Android emulator.
  - Tap Import.
  - Pick 2 images.
  - Confirm gallery shows real thumbnails.
  - Restart app.
  - Confirm imported images remain.

- [ ] Commit:

```bash
git add apps/android
git commit -m "feat(android): import photos from picker"
```

---

## Phase 2: Real Image Rendering And Gallery Parity

### Task 2.1: Add Photo Thumbnail Component

**Files:**
- Create: `apps/android/app/src/main/java/com/lutshop/ui/PhotoAsset.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/ui/GalleryScreen.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/ui/PreviewScreen.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/ui/ExportScreen.kt`

- [ ] Create `PhotoAsset.kt`:

```kotlin
package com.lutshop.ui

import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import coil.compose.AsyncImage
import java.io.File

@Composable
fun PhotoAsset(
    uri: String,
    localPath: String?,
    fallbackColors: List<Color>,
    modifier: Modifier = Modifier
) {
    val model: Any? = when {
        !localPath.isNullOrBlank() && File(localPath).exists() -> File(localPath)
        uri.isNotBlank() -> Uri.parse(uri)
        else -> null
    }
    if (model != null) {
        AsyncImage(model = model, contentDescription = null, contentScale = ContentScale.Crop, modifier = modifier)
    } else {
        Box(modifier.background(Brush.linearGradient(fallbackColors)))
    }
}
```

- [ ] Add Coil dependency:

```kotlin
implementation("io.coil-kt:coil-compose:2.7.0")
```

- [ ] Replace gradient-only photo boxes with `PhotoAsset`.

- [ ] Build and manually verify thumbnails.

- [ ] Commit:

```bash
git add apps/android
git commit -m "feat(android): render imported photos"
```

### Task 2.2: Match iOS Selection Set Behavior

**Files:**
- Modify: `apps/android/app/src/main/java/com/lutshop/AppState.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/ui/GalleryScreen.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/ui/Components.kt`
- Modify: Android string resources.

- [ ] Add state:

```kotlin
var isSelectionMode by mutableStateOf(false)
val selectedPhotosExcludingCurrentCount: Int
    get() = selectedPhotos.count { it.id != currentPhoto?.id }
```

- [ ] Add actions:

```kotlin
fun openOrTogglePhoto(id: String) {
    if (isSelectionMode) toggleSelection(id) else openPhoto(id)
}

fun selectAllFilteredPhotos() {
    val ids = filteredPhotos.map { it.id }.toSet()
    photos = photos.map { if (it.id in ids) it.copy(isSelected = true) else it }
    selectedPhotoId = filteredPhotos.firstOrNull()?.id ?: selectedPhotoId
    isSelectionMode = true
}

fun clearSelection() {
    photos = photos.map { it.copy(isSelected = false) }
    isSelectionMode = false
}
```

- [ ] Gallery behavior:
  - Selection button shows `Select`, `Done`, or `Select (n)`.
  - Done only sets `isSelectionMode = false`.
  - Selection toolbar shows selected count, Select All, Clear, Delete.
  - Non-selection selected thumbnails show white border.
  - Selection-mode selected thumbnails show green border and check icon.

- [ ] Verify:
  - Select photos.
  - Tap Done.
  - White border remains.
  - Re-enter selection mode and count is retained.
  - Clear removes borders.

- [ ] Commit:

```bash
git add apps/android
git commit -m "feat(android): preserve gallery selection set"
```

### Task 2.3: Add Rating, Favorite, Delete, Sort, Session Controls

**Files:**
- Modify: `apps/android/app/src/main/java/com/lutshop/AppState.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/ui/GalleryScreen.kt`
- Modify: Android string resources.

- [ ] Add `PhotoSortOption` enum with `FileName`, `Newest`, `Rating`.
- [ ] Add `showFavoritesOnly`, `photoSortOption`, `selectedSessionName`, `sessions`.
- [ ] Add `deleteSelectedPhotos()`, `createSession(name)`, `renameSession(old, new)`, `deleteSession(name)`.
- [ ] Match iOS rules:
  - Delete selected removes local files.
  - Sessions with photos cannot be deleted.
  - Filters include All, Favorites, Edited, Raw.
  - Search matches fileName and sessionName.

- [ ] Verify manually.

- [ ] Commit:

```bash
git add apps/android
git commit -m "feat(android): add gallery management"
```

---

## Phase 3: C++ Core And Real LUT Runtime

### Task 3.1: Add NDK/CMake Link To Shared Core

**Files:**
- Modify: `apps/android/app/build.gradle.kts`
- Create: `apps/android/app/src/main/cpp/CMakeLists.txt`
- Create: `apps/android/app/src/main/cpp/lutshop_core_jni.cpp`
- Modify: `apps/android/app/src/main/java/com/lutshop/core/LutShopCoreBridge.kt`

- [ ] Add NDK config:

```kotlin
android {
    defaultConfig {
        externalNativeBuild {
            cmake {
                cppFlags += "-std=c++20"
            }
        }
    }
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }
}
```

- [ ] Add `CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.22.1)
project(lutshop_android)

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../../../../../core ${CMAKE_CURRENT_BINARY_DIR}/lutshop_core)

add_library(lutshop_jni SHARED lutshop_core_jni.cpp)
target_link_libraries(lutshop_jni PRIVATE lutshop_core log)
target_include_directories(lutshop_jni PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../core/include)
```

- [ ] Add JNI smoke function:

```cpp
#include <jni.h>
#include "lutshop/bridge_c.h"

extern "C" JNIEXPORT jstring JNICALL
Java_com_lutshop_core_NativeLutShopCore_version(JNIEnv* env, jobject) {
  return env->NewStringUTF(lutshop_core_version());
}
```

- [ ] Add Kotlin native wrapper:

```kotlin
object NativeLutShopCore {
    init { System.loadLibrary("lutshop_jni") }
    external fun version(): String
}
```

- [ ] Display version in gallery debug banner or logcat.

- [ ] Verify:

```bash
cd apps/android
./gradlew :app:assembleDebug
```

- [ ] Commit:

```bash
git add apps/android
git commit -m "feat(android): add c++ core jni smoke test"
```

### Task 3.2: Bundle LUT Files On Android

**Files:**
- Create: `apps/android/app/src/main/assets/luts/AA2_COLOR_V.cube`
- Create: `apps/android/app/src/main/assets/luts/SL3SG3CtoTealOR_709.cube`
- Create: `apps/android/app/src/main/assets/luts/SL3SG3CtoWarm_709.cube`
- Modify: `apps/android/app/src/main/java/com/lutshop/core/LutShopCoreBridge.kt`

- [ ] Copy the three iOS bundled LUT files from:

```text
apps/ios/LutShop/Resources/BundledLuts/
```

to:

```text
apps/android/app/src/main/assets/luts/
```

- [ ] Update Android mock `loadLuts()` so bundled presets have stable IDs and `sourceFileName`.

- [ ] Extend `LutPreset` with:

```kotlin
val sourceFileName: String?,
val isBundled: Boolean,
val userPath: String?
```

- [ ] Build and commit:

```bash
git add apps/android
git commit -m "feat(android): bundle starter LUTs"
```

### Task 3.3: Implement Native LUT Preview Rendering

**Files:**
- Modify: `apps/android/app/src/main/cpp/lutshop_core_jni.cpp`
- Create: `apps/android/app/src/main/java/com/lutshop/core/LutRenderer.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/ui/PhotoAsset.kt`

- [ ] Add Kotlin API:

```kotlin
object LutRenderer {
    external fun applyBundledLut(
        imagePath: String,
        lutAssetPath: String,
        intensity: Float,
        outputPath: String
    ): Boolean
}
```

- [ ] JNI implementation should:
  - Decode bitmap path on Kotlin side first if easier.
  - Or initially implement file passthrough and return false until C++ image pipeline exists.
  - Do not fake success. If native LUT render is not implemented, UI must fall back to original image.

- [ ] Preferred implementation:
  - Decode image with Android `BitmapFactory`.
  - Pass pixels to native.
  - Parse `.cube` with `lutshop::parseCube`.
  - Apply LUT.
  - Return processed bitmap or write output file.

- [ ] Verify with one imported JPG and one bundled LUT.

- [ ] Commit:

```bash
git add apps/android
git commit -m "feat(android): render lut previews"
```

---

## Phase 4: Preview, LUT Library, And Export Parity

### Task 4.1: Preview Page Parity

**Files:**
- Modify: `apps/android/app/src/main/java/com/lutshop/AppState.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/ui/PreviewScreen.kt`
- Modify: Android string resources.

- [ ] When opening a photo, sync global preview controls from that photo:

```kotlin
fun syncPreviewAdjustmentState(photo: Photo) {
    activeLutId = photo.appliedLutId ?: activeLutId
    lutIntensity = photo.lutIntensity.coerceIn(0f, 1f)
}
```

- [ ] Add before/after overlay slider rather than only showBefore toggle.
- [ ] Add Save toast.
- [ ] Add Undo that clears current photo adjustment.
- [ ] Add Sync to Selected excluding current photo:

```kotlin
fun syncCurrentAdjustmentToOtherSelectedPhotos() {
    val current = currentPhoto ?: return
    val lutId = current.appliedLutId ?: return
    photos = photos.map {
        if (it.isSelected && it.id != current.id) {
            it.copy(appliedLutId = lutId, lutIntensity = current.lutIntensity, status = PhotoStatus.Edited)
        } else it
    }
    persist()
}
```

- [ ] Commit:

```bash
git add apps/android
git commit -m "feat(android): match preview adjustment flow"
```

### Task 4.2: LUT Library CRUD

**Files:**
- Modify: `apps/android/app/src/main/java/com/lutshop/Models.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/AppState.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/ui/LutsScreen.kt`
- Create: `apps/android/app/src/main/java/com/lutshop/data/LutLibraryStore.kt`
- Modify: Android string resources.

- [ ] Add `LutCategoryGroup`.
- [ ] Add persisted LUT store matching iOS concepts:
  - system categories
  - user categories
  - user LUT name/path/category/tags
- [ ] UI requirements:
  - Search LUT.
  - Filter by category group.
  - Add LUT dialog with name, path, category.
  - Category manager dialog.
  - LUT detail dialog with rename, category switch, delete, favorite.
  - No default custom category until user creates one.

- [ ] Commit:

```bash
git add apps/android
git commit -m "feat(android): add lut library management"
```

### Task 4.3: Export To MediaStore

**Files:**
- Create: `apps/android/app/src/main/java/com/lutshop/export/PhotoExporter.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/AppState.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/ui/ExportScreen.kt`
- Modify: `apps/android/app/src/main/AndroidManifest.xml`

- [ ] Export must not show or choose LUT.
- [ ] Export must render each photo with its own saved `appliedLutId` and `lutIntensity`.
- [ ] If no LUT is saved, export original.
- [ ] Save to MediaStore:

```kotlin
val values = ContentValues().apply {
    put(MediaStore.Images.Media.DISPLAY_NAME, outputName)
    put(MediaStore.Images.Media.MIME_TYPE, mimeType)
    put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/lut-shop")
}
```

- [ ] Write JPEG/PNG with selected quality and size.
- [ ] Mark exported only after write succeeds.
- [ ] Show progress and completion toast.

- [ ] Verify:
  - Export one original and one LUT-edited image.
  - Open Android Photos/Gallery.
  - Confirm images appear under Pictures/lut-shop.

- [ ] Commit:

```bash
git add apps/android
git commit -m "feat(android): export saved edits to media store"
```

---

## Phase 5: Camera Receive Parity

### Task 5.1: Add Camera Import UI Placeholder

**Files:**
- Create: `apps/android/app/src/main/java/com/lutshop/ui/CameraImportScreen.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/ui/GalleryScreen.kt`
- Modify: `apps/android/app/src/main/java/com/lutshop/AppState.kt`
- Modify: Android string resources.

- [ ] Add camera connection entry in gallery header.
- [ ] Show Android hotspot/FTP receiver info:
  - Host IP
  - Port
  - Username
  - Password
  - Current receive status
- [ ] Do not fake discovery. Display manual setup instructions.

- [ ] Commit:

```bash
git add apps/android
git commit -m "feat(android): add camera receive setup screen"
```

### Task 5.2: Implement Android FTP Receiver

**Files:**
- Create: `apps/android/app/src/main/java/com/lutshop/camera/FtpReceiveService.kt`
- Modify: `apps/android/app/src/main/AndroidManifest.xml`
- Modify: `apps/android/app/src/main/java/com/lutshop/AppState.kt`
- Modify: `apps/android/app/build.gradle.kts`

- [ ] Add the first implementation as an Android foreground service wrapping an embedded FTP server dependency. Start with Apache FtpServer because it supports real FTP server semantics and can be tested with a desktop FTP client:

```kotlin
dependencies {
    implementation("org.apache.ftpserver:ftpserver-core:1.2.0")
}
```

- [ ] If Apache FtpServer does not compile or run on Android because of unsupported Java APIs, stop this task after recording the exact build/runtime failure in `docs/android-ftp-receiver-spike.md`. Do not fake camera receive. Continue with the rest of Android parity and split a custom passive FTP receiver into a separate plan.

- [ ] App must import received files into current camera session.
- [ ] App must show received count and last file name.
- [ ] Add foreground service declaration and notification permission handling:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.INTERNET" />
```

- [ ] Add service declaration:

```xml
<service
    android:name=".camera.FtpReceiveService"
    android:exported="false"
    android:foregroundServiceType="dataSync" />
```

- [ ] Verify with Sony camera or a desktop FTP client:

```bash
ftp <android-device-ip> <port>
put sample.jpg
```

- [ ] Commit:

```bash
git add apps/android
git commit -m "feat(android): receive camera photos over ftp"
```

---

## Phase 6: Polish And Release Gate

### Task 6.1: App Icon And Theme

**Files:**
- Create: `apps/android/app/src/main/res/mipmap-*`
- Modify: `apps/android/app/src/main/AndroidManifest.xml`
- Modify: `apps/android/app/src/main/res/values/styles.xml`

- [ ] Generate Android launcher icons from the iOS icon source or current PNG.
- [ ] Set `android:icon` and `android:roundIcon`.
- [ ] Confirm icon appears on emulator launcher.

- [ ] Commit:

```bash
git add apps/android
git commit -m "feat(android): add launcher icon"
```

### Task 6.2: Android README And QA Checklist

**Files:**
- Modify: `apps/android/README.md`
- Create: `docs/android-qa-checklist.md`

- [ ] README must include:
  - `./android.sh`
  - Android Studio import path
  - emulator requirements
  - photo import behavior
  - export destination
  - current limitations

- [ ] QA checklist must include:
  - import JPG
  - restart persistence
  - apply LUT and save
  - sync to selected
  - export to Photos
  - delete selected
  - add LUT
  - create category
  - camera receive smoke test

- [ ] Commit:

```bash
git add apps/android/README.md docs/android-qa-checklist.md
git commit -m "docs(android): add qa checklist"
```

---

## Recommended Execution Order

1. Phase 0: make Android build reliably.
2. Phase 1: remove fake gallery data and persist real imported photos.
3. Phase 2: make the gallery feel like iOS, especially selection set behavior.
4. Phase 4.1: preview save/sync behavior.
5. Phase 4.3: real export to MediaStore.
6. Phase 3: C++/JNI LUT runtime.
7. Phase 4.2: LUT CRUD.
8. Phase 5: camera receive.
9. Phase 6: release polish.

This order gives a useful Android app early, even before the full native LUT renderer is complete.

## Acceptance Criteria For Android First Usable Version

- `./android.sh` builds the APK.
- App installs and opens on an Android emulator.
- User can import photos from the system picker.
- Imported photos survive app restart.
- User can select multiple photos, finish selection, and see retained white borders.
- User can edit one photo, save adjustment, and sync it to other selected photos.
- Export page does not show LUT selection.
- Export writes images to Android Photos/MediaStore.
- No mock photos appear after real import mode is enabled.

## Acceptance Criteria For iOS Parity Version

- All first usable criteria pass.
- Android uses bundled `.cube` LUTs.
- Android applies LUTs to thumbnails/preview/export through native runtime.
- LUT library supports add, rename, delete, favorite, categories, and detail category switching.
- Session management works.
- Selected photo deletion removes local files and index entries.
- Camera receive can accept at least one image from a test FTP client or Sony camera.
- English and Chinese strings exist for all visible UI text.
