# lut-shop Mobile C++ Core Architecture

## Why C++ Core

`lut-shop` targets both iOS and Android. The expensive and correctness-sensitive parts should not be duplicated in Swift and Kotlin:

- photo/session/LUT workflow state
- LUT application rules
- batch export job state
- rating, favorite, filtering, and selection behavior
- future CV-based LUT recommendation logic
- future image pipeline orchestration

The UI remains native on each platform. The shared C++ Core owns portable product logic and exposes stable DTO-style APIs.

## Layers

### C++ Core

Path: `core/`

Responsibilities:

- Domain models: `Photo`, `Session`, `Lut`, `LutRecommendation`, `ExportSettings`
- Workflow functions: filter, sort, select, favorite, rate, apply LUT state, mark exported
- Session functions: create, rename, delete empty sessions, assign photos to session
- Import functions: normalize platform-provided import items into portable `Photo` DTOs
- LUT catalog functions: import metadata, rename, delete, favorite
- Recommendation interface: `LutRecommender`
- Mock recommendation implementation for MVP
- `LutShopCore` facade for mobile bridge callers
- C ABI smoke-test bridge in `bridge_c.h`
- Minimal `.cube` parser for title, 3D size, and entry data

Not responsible yet:

- Native photo-library permissions
- RAW decoding
- GPU pixel processing
- Writing files to platform storage
- Real ML inference runtime

### iOS App

Recommended stack:

- SwiftUI for app UI
- Objective-C++ bridge files with `.mm` extension
- C++ static library from `core/`
- Photos framework for library access
- Core Image or Metal for future image processing acceleration
- Core ML for future iOS CV recommendation models

Swift should call a small Objective-C++ facade, not raw C++ classes directly.

The first bridge smoke test should call `lutshop_core_version()` and `lutshop_import_photo_count(...)` from `core/include/lutshop/bridge_c.h`. Once that is wired, Objective-C++ can wrap `lutshop::LutShopCore`.

### Android App

Recommended stack:

- Kotlin + Jetpack Compose for app UI
- Android NDK builds `lutshop_core`
- JNI facade for bridge calls
- MediaStore and system picker for photo access
- Bitmap/ImageReader or GPU path for image buffers
- TFLite or NNAPI for future Android CV recommendation models

Kotlin should call a small JNI facade, not mirror every C++ function one by one.

The first JNI smoke test should call `lutshop_core_version()` and `lutshop_import_photo_count(...)` from `core/include/lutshop/bridge_c.h`. Once that is wired, JNI can wrap `lutshop::LutShopCore`.

## CV Recommendation Path

The current implementation uses `MockLutRecommender`.

Future production implementations can keep the same interface:

```cpp
class LutRecommender {
 public:
  virtual ~LutRecommender() = default;
  virtual std::vector<LutRecommendation> recommend(const Photo& photo,
                                                   std::size_t limit) const = 0;
};
```

Possible adapters:

- `CoreMlLutRecommender` for iOS
- `TfLiteLutRecommender` for Android
- `OnnxLutRecommender` if a shared runtime is preferred

The recommendation output should stay product-oriented: LUT ID, confidence, and reason tags. The UI should not depend on model-specific tensors or labels.

## Image Pipeline Direction

Keep two separate concepts:

- Workflow state: C++ Core decides what operation should happen.
- Pixel execution: platform-specific code decides how pixels are decoded, processed, and written.

This avoids forcing one slow portable CPU path for every platform. Later, the C++ Core can expose a `LutProcessor` interface while iOS/Android provide optimized implementations.

## Current Build

```bash
cmake -S . -B build
cmake --build build
./build/core/lutshop_core_tests
```

Expected output:

```text
lutshop_core_tests passed
```
