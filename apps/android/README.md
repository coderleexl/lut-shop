# lut-shop Android App Direction

## Quick Start

From the repository root:

```bash
./android.sh
```

The script builds the debug APK with the checked-in Gradle Wrapper. If `adb` can see an Android device or emulator, it also installs and launches `com.lutshop`; otherwise it leaves the APK at `apps/android/app/build/outputs/apk/debug/app-debug.apk`.

Manual build:

```bash
cd apps/android
./gradlew :app:assembleDebug
```

Recommended production path:

1. Create a Kotlin + Jetpack Compose app under `apps/android/`.
2. Build `core/` through the Android NDK/CMake toolchain.
3. Add a JNI facade, for example `lutshop_core_jni.cpp`.
4. Convert Kotlin DTOs to C++ `lutshop::Photo`, `lutshop::Lut`, and `lutshop::ExportSettings`.
5. Keep MediaStore, system picker, Bitmap/ImageReader, TFLite, and NNAPI code on the Android side.

Kotlin should not duplicate shared workflow rules. The JNI facade should expose coarse operations such as filter photos, apply LUT state, rate selected photos, and get recommendations.

## Current UI Skeleton

The native Compose shell now lives in `apps/android/app/src/main/java/com/lutshop`.

- `Models.kt`: shared mobile DTOs matching the C++ core concepts.
- `core/LutShopCoreBridge.kt`: bridge interface plus mock implementation. Replace this with JNI calls later.
- `AppState.kt`: UI state and workflow actions.
- `ui/*Screen.kt`: Gallery, Preview, LUT Library, and Export screens based on the provided mobile reference image.

The Gradle Wrapper is included for Android Studio import and command-line builds.

The next JNI smoke test should link the NDK build to `../../core` and call the C ABI in `core/include/lutshop/bridge_c.h`:

- `lutshop_core_version()` to verify the shared library loads.
- `lutshop_import_photo_count(...)` to validate Kotlin -> JNI -> C++ import plumbing.

After that, wrap `lutshop::LutShopCore` from `core/include/lutshop/core.hpp` for session, import, sorting, LUT catalog, and recommendation operations.
