# Sony Hotspot Receive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reframe the iOS camera connection flow around Sony hotspot + FTP receive and show the phone's current server address in-app.

**Architecture:** Keep the existing camera connection entry point, but replace LAN discovery as the primary workflow with a fixed FTP receiver model. Derive a best-effort current local IPv4 address at runtime and expose fixed FTP credentials plus Sony setup instructions in the UI.

**Tech Stack:** SwiftUI, Foundation, UIKit, Darwin networking APIs

---

### Task 1: Receiver State Model

**Files:**
- Modify: `apps/ios/LutShop/Models.swift`
- Modify: `apps/ios/LutShop/AppState.swift`

- [x] Add a small FTP receiver configuration model with fixed port/user/password defaults and optional current address text.
- [x] Add app-state helpers for receiver summary text and current server address refresh.
- [x] Remove camera discovery as the primary title/message path.

### Task 2: Sony Hotspot UI

**Files:**
- Modify: `apps/ios/LutShop/Views/CameraImportView.swift`

- [x] Replace discovery/device list UI with hotspot guidance and Sony FTP setup instructions.
- [x] Show fixed FTP credentials and dynamic current address.
- [x] Keep start/stop receive actions and current session status.

### Task 3: Verification

**Files:**
- Modify: none

- [x] Run iOS Xcode build for `LutShop`.
- [x] Report changed files and the resulting user-facing behavior.
