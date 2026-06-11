# lut-shop Mobile C++ Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first portable C++ Core for `lut-shop` so iOS and Android can share photo/LUT workflow logic while native apps own UI and platform integration.

**Architecture:** Put app-independent behavior in `core/`: photo/session/LUT models, filtering, selection, ratings, mock CV LUT recommendations, and export job state. Keep image pixel processing as an interface in this phase so the app can later choose CPU, Metal/Core Image, OpenGL/Vulkan, or platform-native accelerators without changing product logic.

**Tech Stack:** C++20, CMake, simple assert-based test executable, future Objective-C++ bridge for iOS, future JNI bridge for Android.

---

## File Structure

- Create `CMakeLists.txt`: root CMake entry.
- Create `core/CMakeLists.txt`: static library and test executable.
- Create `core/include/lutshop/types.hpp`: portable domain types.
- Create `core/include/lutshop/workflow.hpp`: workflow API.
- Create `core/include/lutshop/recommendation.hpp`: CV recommendation abstraction.
- Create `core/src/workflow.cpp`: workflow implementation.
- Create `core/src/recommendation.cpp`: mock recommendation implementation.
- Create `core/tests/workflow_tests.cpp`: C++ tests for shared behavior.
- Create `apps/ios/README.md`: iOS bridge direction.
- Create `apps/android/README.md`: Android bridge direction.
- Create `docs/architecture/mobile-cpp-core.md`: production architecture notes.

## Task 1: C++ Project Skeleton

**Files:**
- Create: `CMakeLists.txt`
- Create: `core/CMakeLists.txt`
- Create: `core/include/lutshop/types.hpp`
- Create: `core/tests/workflow_tests.cpp`

- [ ] **Step 1: Write failing C++ test skeleton**

Create `core/tests/workflow_tests.cpp` with an include for `lutshop/types.hpp` and a simple model construction test.

- [ ] **Step 2: Run CMake build to verify RED**

Run:

```bash
cmake -S . -B build
cmake --build build
```

Expected: fails until the headers and CMake targets exist.

- [ ] **Step 3: Implement minimal CMake and types**

Add root and core CMake files, create `Photo`, `Lut`, `LutRecommendation`, `ExportSettings`, and enum types.

- [ ] **Step 4: Run build/test to verify GREEN**

Run:

```bash
cmake -S . -B build
cmake --build build
./build/core/lutshop_core_tests
```

Expected: test executable prints passing checks and exits 0.

## Task 2: Workflow Logic

**Files:**
- Create: `core/include/lutshop/workflow.hpp`
- Create: `core/src/workflow.cpp`
- Modify: `core/tests/workflow_tests.cpp`

- [ ] **Step 1: Write failing workflow tests**

Cover filtering by status/search, selecting photos, toggling favorites, applying LUTs, rating photos, and marking export completion.

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
cmake --build build
./build/core/lutshop_core_tests
```

Expected: build fails or tests fail until workflow functions exist.

- [ ] **Step 3: Implement workflow API**

Add pure C++ functions:

- `filterPhotos`
- `togglePhotoSelection`
- `toggleFavorite`
- `applyLutToPhotos`
- `ratePhotos`
- `markPhotosExported`

- [ ] **Step 4: Run tests to verify GREEN**

Run:

```bash
cmake --build build
./build/core/lutshop_core_tests
```

Expected: all workflow checks pass.

## Task 3: Mock CV Recommendation Adapter

**Files:**
- Create: `core/include/lutshop/recommendation.hpp`
- Create: `core/src/recommendation.cpp`
- Modify: `core/tests/workflow_tests.cpp`

- [ ] **Step 1: Write failing recommendation tests**

Cover recommendations for portrait, landscape, and fallback photos using `analysisTags`.

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
cmake --build build
./build/core/lutshop_core_tests
```

Expected: missing recommendation API causes failure.

- [ ] **Step 3: Implement mock recommender**

Add an interface-like `LutRecommender` base class and `MockLutRecommender` implementation returning LUT IDs, confidence, and reason tags.

- [ ] **Step 4: Run tests to verify GREEN**

Run:

```bash
cmake --build build
./build/core/lutshop_core_tests
```

Expected: all recommendation checks pass.

## Task 4: Mobile Integration Notes

**Files:**
- Create: `docs/architecture/mobile-cpp-core.md`
- Create: `apps/ios/README.md`
- Create: `apps/android/README.md`

- [ ] **Step 1: Document production architecture**

Describe C++ Core boundaries, Objective-C++ bridge for iOS, JNI bridge for Android, image pipeline options, and CV model integration options.

- [ ] **Step 2: Add platform bridge README files**

Add short, concrete next steps for iOS and Android app shells.

- [ ] **Step 3: Verify docs and build**

Run:

```bash
cmake --build build
./build/core/lutshop_core_tests
```

Expected: C++ core remains green after docs are added.

## Task 5: Repository Cleanup

**Files:**
- Modify: `.gitignore`
- Remove or leave clearly marked: web prototype scaffold if it exists.

- [ ] **Step 1: Remove accidental web scaffold if not needed**

If `package.json`, `src/main.tsx`, or Vite config exists from the aborted web prototype, either remove them or mark them as separate disposable prototype files.

- [ ] **Step 2: Verify repository status**

Run:

```bash
git status --short
```

Expected: only intentional C++ Core, docs, and reference assets are uncommitted.

## Self-Review

- Spec coverage: C++ Core covers shared workflow logic, LUT application state, export state, and mock CV recommendation data. UI implementation remains a later iOS/Android shell step.
- Placeholder scan: no TODO/TBD placeholders are used.
- Type consistency: `Photo`, `Lut`, and `LutRecommendation` mirror the product spec and can be bridged to Swift/Kotlin DTOs.

## SwiftUI Migration Next Steps

Track one UI feature at a time against the design spec. Keep each step scoped to the smallest relevant SwiftUI files and run the iOS Xcode build after editing.

- [x] Preview before/after comparison overlay slider
  - Files: `apps/ios/LutShop/Views/PreviewView.swift`, `apps/ios/LutShop/AppState.swift`
  - Behavior: show Before/After as an image overlay with a draggable divider and a compare toggle.
- [x] Preview 1-5 star rating interaction
  - Files: `apps/ios/LutShop/Views/PreviewView.swift`, `apps/ios/LutShop/AppState.swift`
  - Behavior: make the preview rating stars tappable and call the existing `rateCurrentPhoto(_:)` state action.
- [x] Gallery multi-select and filter workflow polish
  - Files: `apps/ios/LutShop/Views/GalleryView.swift`, `apps/ios/LutShop/Views/Components.swift`, `apps/ios/LutShop/AppState.swift`
  - Behavior: support explicit multi-select mode, selection clearing, batch rating, and quick navigation to LUT/export flows.
- [x] LUT management interactions
  - Files: `apps/ios/LutShop/Views/LutsView.swift`, `apps/ios/LutShop/AppState.swift`
  - Behavior: support category/search filtering, favorite toggles, detail/edit sheet, rename, delete confirmation, and mock import feedback.
- [x] Export settings and progress flow
  - Files: `apps/ios/LutShop/Views/ExportView.swift`, `apps/ios/LutShop/AppState.swift`
  - Behavior: support empty selection state, settings controls, export progress, completion feedback, and marking selected photos exported.
- [x] Bridge/API reservation for future C++ and CV integration
  - Files: `apps/ios/LutShop/Core/LutShopCoreBridge.swift`, `apps/ios/LutShop/AppState.swift`
  - Behavior: keep UI state routed through app-state actions and bridge-facing methods so native C++/CV implementations can replace the mock bridge later.
