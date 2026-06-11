# lut-shop iOS App Direction

Recommended production path:

1. Create a SwiftUI app under `apps/ios/`.
2. Build `core/` as a static C++ library with CMake or Xcode integration.
3. Add an Objective-C++ facade, for example `LutShopCoreBridge.mm`.
4. Convert Swift DTOs to C++ `lutshop::Photo`, `lutshop::Lut`, and `lutshop::ExportSettings`.
5. Keep Photos, Files, Core Image, Metal, and Core ML code on the iOS side.

Swift should not own duplicate business rules for selection, ratings, export state, or LUT recommendations. Those should call the C++ Core through the bridge.

## Current UI Skeleton

The SwiftUI shell now lives in `apps/ios/LutShop`.

- `Models.swift`: shared mobile DTOs matching the C++ core concepts.
- `Core/LutShopCoreBridge.swift`: bridge protocol plus mock implementation. Replace this with Objective-C++ calls later.
- `AppState.swift`: UI state and workflow actions.
- `Views/*View.swift`: Gallery, Preview, LUT Library, and Export screens based on the provided mobile reference image.

`swiftc -parse` passes for the current Swift files. The next iOS step is adding an Xcode project target that includes these files and links the C++ core bridge.

## Xcode

Open `apps/ios/LutShop.xcodeproj` in Xcode and run the `LutShop` scheme on an iPhone simulator.

The project currently builds the SwiftUI mock app only. The future Objective-C++ bridge target should link `../../core` once the UI flow is stable.

## Localization

Translation resources are in `LutShop/Resources/Localizable.xcstrings`.

Current locales:

- `en`
- `zh-Hans`

SwiftUI literal `Text` and `Button` labels can resolve through this catalog. Dynamic mock data is still stored as plain strings and should be converted to stable localization keys when the data layer is finalized.
