# Preview Sync Selected Adjustment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Preview detail action that syncs the current photo's saved LUT adjustment to other selected photos, excluding the current photo.

**Architecture:** Keep export as a pure render/output step. Store adjustment state per `Photo` using existing `appliedLutId` and `lutIntensity`, and add one `AppState` method for copying those values to selected photos other than `currentPhoto`.

**Tech Stack:** SwiftUI, `LutShopAppState`, existing `Photo` model, Xcode iOS simulator build.

---

### Task 1: State Sync Method

**Files:**
- Modify: `apps/ios/LutShop/AppState.swift`

- [ ] Add `selectedPhotosExcludingCurrentCount` so the UI can disable the action when fewer than one target exists.
- [ ] Add `syncCurrentAdjustmentToOtherSelectedPhotos()` that requires a current photo with `appliedLutId`, copies `appliedLutId`, `lutIntensity`, and `.edited` status to selected photos whose id is not the current photo id, persists, and shows a localized success/failure message.

### Task 2: Preview UI Action

**Files:**
- Modify: `apps/ios/LutShop/Views/PreviewView.swift`

- [ ] Add a secondary button in the adjustment panel labeled `Sync to Selected`.
- [ ] Disable it when no other selected photos exist.
- [ ] Keep the existing Save button as the user's explicit way to save the current photo adjustment before syncing.

### Task 3: Localization

**Files:**
- Modify: `apps/ios/LutShop/Resources/Localizable.xcstrings`

- [ ] Add Chinese strings for `Sync to Selected`, `Synced adjustment to %d selected photo(s)`, and `Save an adjustment before syncing`.

### Task 4: Verify

**Files:**
- No source edits.

- [ ] Run `xcodebuild -project apps/ios/LutShop.xcodeproj -scheme LutShop -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData build`.
- [ ] Cover-install and relaunch the simulator app without uninstalling or clearing data.
