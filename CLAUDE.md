# CLAUDE.md

## Build

- iOS: `./mac.sh` (requires Xcode + iOS Simulator)
- Android: `./android.sh` (requires Android SDK + JDK 17)
- iOS build-only: `./mac.sh --build-only`

## Architecture

- iOS SwiftUI app: `apps/ios/`
- Android Compose app: `apps/android/`
- Shared C++ core: `core/` (LUT parsing/rendering, bridged via ObjC++ on iOS, JNI on Android)

## Conventions

- Dark photography workstation UI theme
- Bilingual: English + Simplified Chinese
- Export reads saved per-photo LUT adjustments (no LUT picker on export)
- Gallery selection set persists across mode toggles (white border = selected outside selection mode)
