# lut-shop MVP Design Spec

Date: 2026-06-11

## Goal

Build a mobile-first interactive MVP prototype for `lut-shop`, a professional photography LUT/preset management and batch photo workflow app.

The first screen must match the provided visual reference:

- Reference image: `docs/assets/lut-shop-gallery-reference.png`
- Primary direction: dark professional gallery and culling workspace
- Secondary direction: LUT library and preset management built into the workflow
- Future extension: CV-based visual analysis for automatic LUT recommendations

The app opens directly into the gallery workspace. It must not include a landing page, marketing hero, or social editing feed.

## Product Scope

The MVP includes four bottom tabs:

1. Gallery
2. Preview
3. LUTs
4. Export

The prototype should use realistic mock data and functional UI state. It does not need native photo import, real RAW decoding, GPU LUT processing, file-system export, or a real CV model yet.

## Visual Direction

Use the downloaded reference image as the source of truth.

Key visual traits:

- Dark mode first, near-black background with slightly raised control surfaces.
- Professional camera-workflow feel, similar to Lightroom or Darkroom rather than a casual social photo app.
- Green accent for selected photos, active tab, connected device state, and success/export states.
- White and gray typography with restrained contrast.
- Rounded search fields, filter buttons, icon buttons, and photo tiles.
- Three-column photo grid on mobile.
- Dense but readable controls.
- Photo content should dominate the screen.

The top of the Gallery screen includes:

- iOS-style status area in the reference can be approximated or omitted depending on web viewport constraints.
- `lut-shop` title.
- Camera connection pill such as `Canon R5 · Connected`.
- Cloud/import button and more menu button.
- Search field.
- Filter, favorite, and sort/action icon buttons.
- Session selector row with date/session title and photo count.
- Status filters: All, New, Edited, Favorites, Exported.

The bottom includes:

- A contextual selection bar when photos are selected.
- Actions: Apply LUT, Rate, Export.
- Persistent 4-tab navigation.

## Data Model

### Photo

```ts
type Photo = {
  id: string
  fileName: string
  uri: string
  importedAt: string
  sessionId?: string
  isFavorite: boolean
  isSelected: boolean
  rating: number
  appliedLutId?: string
  lutIntensity: number
  status: 'raw' | 'edited' | 'exported'
  analysisTags?: string[]
  recommendedLutIds?: string[]
}
```

### LUT

```ts
type Lut = {
  id: string
  name: string
  category: 'portrait' | 'landscape' | 'film' | 'bw' | 'commercial' | 'custom'
  tags: string[]
  previewColors: string[]
  isFavorite: boolean
  usageCount: number
}
```

### CV Recommendation

```ts
type LutRecommendation = {
  photoId: string
  lutId: string
  confidence: number
  reasons: string[]
}
```

For MVP, recommendations are static mock data. The UI should make the future CV capability visible without claiming real image analysis is running.

## Screens

### Gallery

Purpose: import, browse, filter, search, select, and start the editing/export flow.

Required interactions:

- Search filters photos by file name or session name.
- Filter tabs switch between All, New, Edited, Favorites, and Exported.
- Photo tiles toggle selection.
- Favorite star toggles favorite state.
- Session row opens a lightweight session menu or simulated selection state.
- Import buttons show a loading or success feedback state.
- Apply LUT action opens or switches to LUT selection context.
- Rate action applies a rating to selected photos.
- Export action switches to Export tab with selected photos.

### Preview

Purpose: inspect one selected photo and apply a LUT.

Required interactions:

- Show selected/current photo large.
- Toggle before/after comparison.
- Change active LUT.
- Adjust LUT intensity from 0% to 100%.
- Favorite and rate current photo.
- Save current adjustment state.
- Undo current LUT effect.

### LUTs

Purpose: manage presets and choose/apply LUTs.

Required interactions:

- Search LUTs by name.
- Filter by category.
- Favorite a LUT.
- Rename/delete actions can use local modal or confirmation UI.
- Import LUT button shows feedback.
- Applying a LUT updates selected/current photo mock state.

### Export

Purpose: batch export selected/edited photos.

Required interactions:

- Show selected photo count and list.
- Choose export format: JPG or PNG.
- Choose size: Original, 2048px, or 1080px.
- Choose quality: High, Medium, or Low.
- Toggle EXIF preservation.
- Start export progress.
- Show completion state and mark photos exported.

## CV Recommendation Flow

The first iteration should include a restrained `Smart LUT` or `Auto Match` entry point.

Recommended placement:

- Gallery: small chip or action in contextual selected-photo bar, not a large first-screen panel.
- Preview: recommendation panel with suggested LUTs, confidence, and reason tags.
- LUTs: optional `Recommended for current photo` section.

MVP behavior:

- When a photo is selected, mock recommendations appear.
- Each recommendation shows LUT name, category/tags, confidence, and an Apply action.
- Applying a recommended LUT behaves like applying any other LUT.

Future integration path:

- Replace mock `LutRecommendation` generation with image analysis output.
- Add async states: analyzing, recommended, failed, stale.
- Add user controls for accepting, dismissing, or retraining recommendation preferences.

## Architecture

The production product should use a shared C++ Core for cross-platform image and LUT processing, with iOS and Android providing platform UI, file access, photo-library integration, and native bridge code.

Recommended production split:

- C++ Core: LUT parsing/application, image pipeline orchestration, batch-processing rules, metadata models, export job state, and future CV recommendation adapters.
- iOS shell: Swift/SwiftUI or UIKit UI, Photos/File access, Metal/Core Image acceleration bridge where useful, and C++ interop through Objective-C++.
- Android shell: Kotlin/Jetpack Compose UI, MediaStore/File access, Bitmap/ImageReader integration, and C++ interop through JNI/NDK.
- CV layer: model-specific adapter behind a stable C++ recommendation interface so the app can use Core ML on iOS, NNAPI/TFLite on Android, or a shared ONNX/TFLite runtime later.

For the current workspace, a web prototype may still be useful for validating the UI reference and interactions quickly. That prototype should be treated as disposable UX validation, not as the final app architecture.

Suggested future production structure:

- `core/include/lutshop/`: public C++ headers and stable app-facing APIs.
- `core/src/`: C++ image workflow, LUT, recommendation, export, and session logic.
- `core/tests/`: portable C++ tests for shared behavior.
- `apps/ios/`: iOS app and Objective-C++ bridge.
- `apps/android/`: Android app, Kotlin UI, and JNI bridge.

Suggested web prototype structure, if kept:

- `src/data/`: mock photos, LUTs, recommendations.
- `src/types/`: TypeScript models mirroring C++ DTOs.
- `src/components/`: reusable UI pieces such as photo grid, bottom nav, toolbar, LUT rows, export settings.
- `src/screens/`: Gallery, Preview, LUTs, Export.
- `src/App.tsx`: app state and screen routing.

No backend is required for MVP.

## Testing

Because this is an interactive prototype, test at two levels:

- Unit tests for filtering photos, applying LUTs, exporting state changes, and recommendation selection.
- Manual/browser verification for mobile layout, tab switching, selection bar, slider behavior, modals, and export progress.

Before handoff:

- Run available unit/build checks.
- Start the local app.
- Capture and compare the implementation against `docs/assets/lut-shop-gallery-reference.png`.
- Record design QA notes in `design-qa.md`.

## Open Decisions

No blocking decisions remain for MVP.

Implementation should prioritize matching the reference Gallery screen first, then fill out Preview, LUTs, and Export with the same visual language.
