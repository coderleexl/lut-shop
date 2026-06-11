# lut-shop Android App Direction

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

The Gradle files are included for Android Studio import, but this environment does not currently have `gradle` installed, so Android compilation has not been run here.
