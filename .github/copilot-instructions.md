# Nudge — Copilot Instructions

## Product intent
- iOS 17+ SwiftUI app for ADHD-friendly task management.
- Core UX rule: one card at a time — avoid lists when a single card view will do.

## Targets + data sharing
- Targets: `Nudge` (main), `NudgeShareExtension`, `NudgeWidgetExtension` (Live Activity).
- Shared data uses App Group `group.com.nudge.app` (see `AppGroupID` in `Nudge/Services/NudgeRepository.swift`).
- Share flow: `NudgeShareExtension/ShareViewController.swift` writes `[ShareExtensionPayload]` JSON to App Group `UserDefaults` key `pendingShareItems`; main app ingests via `NudgeRepository.ingestFromShareExtension()` on launch + foreground (`Nudge/NudgeApp.swift`).
- Keep duplicated types in sync:
  - `ShareExtensionPayload` exists in both targets (`NudgeRepository.swift` + `ShareViewController.swift`).
  - Live Activity types are duplicated in the widget target (see `NudgeWidgetExtension/NudgeLiveActivityWidget.swift`).

## App entry points (start here)
- `Nudge/NudgeApp.swift`: SwiftData `ModelContainer` (falls back to in-memory on corruption), bootstraps services, calls `NudgyEngine.shared.bootstrap(penguinState:)`, then ingests share items + resurfaces expired snoozes.
- `Nudge/ContentView.swift`: central router for `NotificationCenter` + deep links, owns Brain Dump overlay + Quick Add sheet, and syncs Live Activity with the active queue.
- `AppSettings` is `@Observable` backed by `UserDefaults` and injected via `.environment(appSettings)`; for two-way bindings use the local rebinding pattern: `@Bindable var settings = settings`.

## Data layer rules (SwiftData)
- Views should not query `ModelContext` directly. Create `NudgeRepository(modelContext:)` and use it for CRUD/fetching.
- Enums are stored as raw strings on models (e.g. `statusRaw`). In `#Predicate`, compare raw strings:
  - ✅ `#Predicate<NudgeItem> { $0.statusRaw == "active" }`
  - ❌ `#Predicate<NudgeItem> { $0.status == .active }`
- Avoid unwrapping optionals inside `#Predicate` (SwiftData limitation). Fetch broader sets, then filter in-memory (see `fetchCompletedToday()` / `resurfaceExpiredSnoozes()` in `NudgeRepository.swift`).

## Nudgy AI architecture
- `Nudge/NudgyEngine/NudgyEngine.swift` is the facade and the only entry point for AI/chat/reactions/extraction/TTS.
- Don’t call sub-engines directly from views; call `NudgyEngine.shared.*`.
- Always handle “AI unavailable”: check `NudgyEngine.shared.isAvailable` and follow existing on-device fallbacks (`AIService`).
- OpenAI keys come from `Nudge/Secrets.xcconfig` → `Info.plist` (don’t hardcode or commit keys).

## UI conventions that matter here
- Dark-first UI: root flows generally apply `.preferredColorScheme(.dark)`.
- Design system: use `DesignTokens` from `Nudge/Core/Constants.swift` for colors/spacing; avoid new ad-hoc palettes.
- Accessibility is required on custom views via `Nudge/Core/Accessibility/VoiceOverHelpers.swift`:
  - `.nudgeAccessibility(...)`, `.nudgeAccessibilityElement(...)`, `.nudgeAccessibilityAction(...)`.

## Cross-component communication
- Navigation + actions use `NotificationCenter` events defined on `Notification.Name`:
  - `Nudge/Services/ActionService.swift`: `.nudgeOpenBrainDump`, `.nudgeOpenQuickAdd`, `.nudgeOpenChat`, `.nudgeComposeMessage`, `.nudgeDataChanged`, `.nudgeNeedsContactPicker`.
  - `Nudge/Services/NotificationService.swift`: `.nudgeNotificationAction`.

## Localization
- User-facing strings use `String(localized:)`.

## Common CLI workflows
- Build (Simulator): `cd Nudge && xcodebuild -scheme Nudge -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`
- Test (Simulator): `cd Nudge && xcodebuild -scheme Nudge -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test`
