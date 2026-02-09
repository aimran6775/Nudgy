# Nudge — Copilot Instructions

## Architecture Overview

Nudge is a native iOS 17+ SwiftUI app for ADHD-friendly task management. It uses a single-screen "one card at a time" paradigm — never show lists when a single card will do.

**Targets:** `Nudge` (main app), `NudgeShareExtension` (Share Extension), `NudgeWidgetExtension` (Live Activity widget). All three share data via App Group `group.com.nudge.app`.

**Data flow:** Voice brain dump → `SpeechService` (on-device transcription) → `NudgyEngine` (OpenAI GPT-4o via REST API + on-device fallback) → `NudgeRepository` (SwiftData CRUD) → `OneThingView` (card display). Share Extension writes JSON to App Group UserDefaults; main app ingests on foreground via `NudgeRepository.ingestFromShareExtension()`.

**Key architectural rules:**
- Views never touch `ModelContext` directly — always go through `NudgeRepository`
- **NudgyEngine.shared** is the single entry point for all Nudgy AI functionality — conversation, reactions, greetings, task extraction, voice I/O. Views call `NudgyEngine.shared` methods, never sub-engines directly
- Most services are singletons via `.shared` (`HapticService.shared`, `NudgyEngine.shared`). **Exception:** `NudgeRepository` is NOT a singleton — it's instantiated per-use from a `ModelContext` (multiple independent instances coexist)
- `AppSettings` is `@Observable` backed by `UserDefaults` (not SwiftData) — injected via `.environment(appSettings)`. To get two-way bindings, views use the local rebinding pattern: `@Bindable var settings = settings`
- `AccentColorSystem` and `PenguinState` are also injected as environment objects at the root

## NudgyEngine — Conversational AI Architecture

All Nudgy AI functionality lives in the `NudgyEngine/` folder. NudgyEngine is a **facade** over modular sub-engines:

```
┌─────────────────────────────────────────────────┐
│                  NudgyEngine                     │
│  (facade — single entry point for all Nudgy)    │
├─────────────────────────────────────────────────┤
│  NudgyConversationManager  ← orchestrates chat  │
│    ├── NudgyLLMService     ← OpenAI API calls   │
│    ├── ConversationStore   ← message history     │
│    ├── NudgyToolExecutor   ← function calling    │
│    └── NudgyToolDefinitions ← tool schemas       │
│  NudgyMemory               ← persistent memory   │
│  NudgyPersonality          ← identity/prompts    │
│  NudgyDialogueEngine       ← one-liner gen      │
│  NudgyReactionEngine       ← two-tier reactions  │
│  NudgyTaskExtractor        ← task parsing        │
│  NudgyVoiceInput           ← speech-to-text      │
│  NudgyVoiceOutput          ← text-to-speech      │
│  NudgyEmotionMapper        ← text → expression   │
│  NudgyStateAdapter         ← → PenguinState      │
│  NudgyConfig               ← all settings        │
└─────────────────────────────────────────────────┘
```

**Key NudgyEngine rules:**
- **Bootstrap once** at app launch: `NudgyEngine.shared.bootstrap(penguinState:)` in `NudgeApp.swift`
- **Never call sub-engines directly from views.** Always go through `NudgyEngine.shared.chat()`, `.greet()`, `.reactToCompletion()`, etc.
- **NudgyStateAdapter** bridges NudgyEngine → `PenguinState` for view reactivity. Views observe `PenguinState` via environment; NudgyEngine drives its state
- **PenguinState** methods like `sendChat()`, `smartGreet()`, `handleTap()`, `reactToCompletion()` now delegate to `NudgyEngine.shared` — they are thin wrappers
- **Two-tier dialogue pattern:** `NudgyReactionEngine` returns curated text synchronously for instant display, then fires an async AI call that upgrades the text when ready. Always provide a curated fallback
- **Memory is persistent:** `NudgyMemory` stores user facts and conversation summaries as JSON in the app's documents directory. Memory context is injected into every OpenAI system prompt
- **OpenAI function calling:** Nudgy can look up tasks, mark them done, snooze them, and create new ones via tool calls (`NudgyToolDefinitions` → `NudgyToolExecutor`). Tool call loops are capped at 3 iterations

### LLM Configuration

- **Primary:** OpenAI GPT-4o via REST API (`/v1/chat/completions`) — requires API key in `Secrets.xcconfig`
- **Fallback:** Apple Foundation Models (`AIService`) — on-device, no key required
- API key flows: `Secrets.xcconfig` → `Info.plist` → `NudgyConfig.OpenAI.apiKey`
- Chat model: `gpt-4o-mini` (conversation). Extraction model: `gpt-4o-mini` (task parsing)
- Streaming uses Server-Sent Events (SSE) parsing in `NudgyLLMService`
- Temperature: 0.85 for conversation, 0.3 for extraction
- Always check `NudgyEngine.shared.isAvailable` — fall back gracefully

### Voice I/O

- **TTS (NudgyVoiceOutput):** Dual backend — AVSpeechSynthesizer (on-device, free) or OpenAI TTS API (`tts-1`, voice "nova"). Controlled by `NudgyConfig.Voice.useOpenAITTS`
- **STT (NudgyVoiceInput):** Wraps `SpeechService` (SFSpeechRecognizer, on-device)
- Voice toggle in YouView maps to `NudgyVoiceOutput.shared.isEnabled`

## Data Layer

- **Persistence:** SwiftData with two `@Model` classes: `NudgeItem` and `BrainDump` (1-to-many). `BrainDump` declares `@Relationship(deleteRule: .nullify, inverse: \NudgeItem.brainDump)`
- **Enum storage pattern:** SwiftData models store enums as raw strings (`statusRaw`, `sourceTypeRaw`, `actionTypeRaw`) with computed property wrappers for type-safe access. `#Predicate` requires raw string comparisons — never use computed enum properties inside predicates:
  ```swift
  // ✅ Correct
  let predicate = #Predicate<NudgeItem> { $0.statusRaw == "active" }
  // ❌ Wrong — won't compile
  let predicate = #Predicate<NudgeItem> { $0.status == .active }
  ```
- **Optional date filtering:** Optional `Date?` fields cannot be safely unwrapped inside `#Predicate`. Fetch the broader set, then filter in-memory:
  ```swift
  let snoozed = try modelContext.fetch(descriptor)
  let expired = snoozed.filter { $0.snoozedUntil.map { $0 <= now } ?? false }
  ```
- **Resilient ModelContainer:** `NudgeApp` tries persistent storage first, falls back to in-memory on corruption — the app must always launch
- **Free tier limits** are in `FreeTierLimits` enum in `Nudge/Core/Constants.swift`: 3 brain dumps/day, 5 saved items

## View & ViewModel Patterns

- **No ViewModel for most views** — `OneThingView`, `SettingsView`, `SnoozePickerView` work directly with `NudgeRepository` + `@State`. Only `BrainDumpView` has a dedicated ViewModel
- **`BrainDumpViewModel`** is `@Observable`, created as `@State private var viewModel = BrainDumpViewModel()` (not injected). It uses a `Phase` enum with associated values as a state machine. Since such enums aren't `Equatable`, it exposes a `.tag: String` computed property for `.onChange()` observation
- **The ViewModel is decoupled from data:** `saveTasks()` receives `ModelContext` and `AppSettings` as parameters — it doesn't hold references
- **Sheet presentation:** Brain dump → `.fullScreenCover`. All other sheets → `.sheet` with `.presentationDetents([.medium])` + `.presentationDragIndicator(.visible)` + `.presentationBackground(DesignTokens.cardSurface)`
- **`.preferredColorScheme(.dark)`** on every root view and every sheet
- **Deep links:** `nudge://brainDump`, `nudge://quickAdd`, `nudge://viewTask`, `nudge://allItems`, `nudge://settings` — handled in `ContentView.handleDeepLink(_:)`

## Design System — Non-Negotiable

All colors come from `DesignTokens` in `Nudge/Core/Constants.swift`. Never use raw color literals.
- Canvas: pure `#000000` black (OLED). Cards: `#1C1C1E` at 80% opacity + 0.5px accent border
- Accent colors are **status-driven**, not decorative: blue=active, green=done, amber=stale(3+ days), red=overdue
- Use `DarkCard` component for all card surfaces — it handles background, border, pulse animation
- Typography: use `AppTheme` static properties (e.g., `AppTheme.taskTitle`, `AppTheme.caption`), not raw `.font()` calls
- Spacing follows a 4pt grid via `DesignTokens.spacingXS/SM/MD/LG/XL/XXL/XXXL` — no magic numbers
- Animation: all specs in `AnimationConstants`. Springs for motion, `.easeOut` for fades. Never use `.linear`
- Mark constant enums as `nonisolated` (e.g., `RecordingConfig`, `StoreKitProducts`) for safe cross-concurrency access

## Accessibility — Built In, Not Bolted On

Every custom view must call `.nudgeAccessibility(label:hint:traits:)` from `Nudge/Core/Accessibility/VoiceOverHelpers.swift`. Cards use `.nudgeAccessibilityElement()` to combine children. Swipe gestures get `.nudgeAccessibilityAction()` equivalents. Always respect `@Environment(\.accessibilityReduceMotion)` — `AnimationConstants.animation(for:reduceMotion:)` handles this.

## Haptics & Sound

Every interaction maps to a specific `HapticService` method (e.g., `.swipeDone()`, `.micStart()`, `.snoozeTimeSelected()`). Never call `UIImpactFeedbackGenerator` directly. Sound cues go through `SoundService`. Both are pre-warmed at app launch. **Exception:** the Share Extension creates its own `UINotificationFeedbackGenerator` directly since service singletons aren't available in extension targets.

## Localization

All user-facing strings must use `String(localized:)` — no hardcoded text, no `NSLocalizedString`.

## AI Integration

- **Primary: NudgyEngine** — OpenAI GPT-4o via REST API with function calling, streaming, and persistent memory
- **Fallback: AIService** — Apple Foundation Models (`FoundationModels` framework), fully on-device, no API keys
- Brain dump splitting: `NudgyEngine.shared.splitBrainDump()` (OpenAI) with `AIService.shared.splitBrainDump()` fallback
- Task extraction: `NudgyEngine.shared.extractTask()` with pattern-matching fallback
- Draft generation: `NudgyEngine.shared.generateDraft()` with `AIService.shared.generateDraft()` fallback
- Always check `NudgyEngine.shared.isAvailable` or `AIService.shared.isAvailable` — the app must work fully without AI
- **Two-tier AI dialogue:** `NudgyReactionEngine` returns curated text synchronously for instant display, then fires an async OpenAI call that upgrades the text when ready. Always provide a curated fallback for every AI-generated string

## Cross-Component Communication

Five custom `Notification.Name` values coordinate UI:

| Notification | Direction | Purpose |
|---|---|---|
| `.nudgeOpenBrainDump` | Views → ContentView | Present brain dump overlay |
| `.nudgeOpenQuickAdd` | Views → ContentView | Present quick-add sheet |
| `.nudgeComposeMessage` | ActionService → OneThingView | Trigger SMS compose |
| `.nudgeDataChanged` | OneThingView → ContentView | Refresh active count after mutations |
| `.nudgeNotificationAction` | NotificationService → ContentView | Route push notification tap actions |

`ContentView` is the central router — it observes all notifications and dispatches to the correct view or action.

**Share Extension → Main App:** `ShareExtensionPayload` JSON written to App Group UserDefaults. **This struct is defined in both targets** (`NudgeRepository.swift` and `ShareViewController.swift`) — keep them in sync manually. Ingested on every foreground event.

**Widget type duplication:** `NudgeActivityAttributes`, `TimeOfDay`, and `Color(hex:)` are **redefined in the widget target** — changes must be mirrored manually.

## Build & Deploy

```sh
# Build and install to device (from Nudge/ directory containing .xcodeproj)
xcodebuild -scheme Nudge -destination 'id=<DEVICE_UDID>' -allowProvisioningUpdates build
xcrun devicectl device install app --device <DEVICE_UDID> "<DerivedData_path>/Build/Products/Debug-iphoneos/Nudge.app"
```

- Team ID: `XG936GFSKZ`. Deployment target: iOS 17.0, iPhone only
- `Secrets.xcconfig` holds `OPENAI_API_KEY` — referenced via `$(OPENAI_API_KEY)` in `Info.plist` → read at runtime by `NudgyConfig.OpenAI.apiKey`. **Never commit API keys**
- Share Extension memory budget: <80MB — use `loadFileRepresentation` for images
