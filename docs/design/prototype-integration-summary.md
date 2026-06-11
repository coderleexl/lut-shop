# lut-shop Prototype Integration Summary

Source prototype:

`/Users/lixinglin/Documents/简历/lut-shop-prototype`

## What The Prototype Contains

- A static mobile Web prototype with four screens: Gallery, Preview, LUTs, and Export.
- A dark professional photography workstation style.
- Real bitmap photo assets for gallery tiles and preview imagery.
- Reference screenshots:
  - `assets/reference-gallery.png`
  - `assets/reference-preview.png`
- `design-qa.md`, which marks browser screenshot QA as blocked but confirms files and JavaScript syntax were checked.

## Useful Product Decisions

- The first screen should be the Gallery workspace, not a landing page.
- Gallery should prioritize real photos, dense scanning, and status overlays.
- Bottom navigation remains four tabs: Gallery, Preview, LUTs, Export.
- Gallery controls should include search, filter, favorite filtering, session context, and selected-photo actions.
- Preview should include before/after comparison, LUT strip, intensity slider, quick adjustments, undo/save/apply actions.
- LUT Library should support category chips and visible color swatches.
- Export should show selected photos, LUT intensity, format/size settings, EXIF option, and progress queue.

## Integrated Into Current Project

- Copied prototype photo assets into `apps/ios/LutShop/Resources/PrototypePhotos`.
- Added `Photo.imageName` to iOS mock data.
- Added `PhotoAssetView` for loading bundled prototype photos.
- Updated iOS Gallery, Preview, Export, and selected-photo bar to render real images instead of gradient placeholders.
- Copied reference screenshots into `docs/assets`:
  - `lut-shop-prototype-reference-gallery.png`
  - `lut-shop-prototype-reference-preview.png`

## Not Yet Integrated

- Web prototype quick adjustment controls: Exposure, Contrast, Highlights, Shadows, Warmth.
- Export queue row UI and progress states.
- Web prototype's LUT thumbnail imagery.
- Full screenshot-based visual QA against reference images.
- Android image asset integration.

## Migration Guidance

Keep the Web prototype as visual reference only. The production direction remains:

- iOS: SwiftUI shell + Objective-C++ bridge
- Android: Kotlin/Compose shell + JNI bridge
- Shared workflow/CV/LUT logic: C++ Core

Do not port the Web app as runtime code. Port its visual assets, screen composition, and interaction expectations into native screens.
