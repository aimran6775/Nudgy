# You Page Implementation Reference

> Quick-access reference for building. Exact file paths, signatures, and dependencies.

---

## Xcode Project

- **Object version 77** — `PBXFileSystemSynchronizedRootGroup` auto-syncs from disk.
- **No pbxproj edits needed.** Drop a `.swift` into the folder → it's in the build.
- **Bundle ID:** `com.tarsitgroup.nudge`
- **Sim:** `80F84FEC-B3C7-400C-8F73-8A3D888A5A0E` (iPhone 17 Pro, iOS 26.2)
- **DerivedData:** `~/Library/Developer/Xcode/DerivedData/Nudge-hiursflqkxedchggqbbxpgjdebru`

## Build Command (copy-paste)

```bash
cd "/Users/abdullahimran/Desktop/untitled folder/Nudge" && xcodebuild -scheme Nudge -destination 'platform=iOS Simulator,id=80F84FEC-B3C7-400C-8F73-8A3D888A5A0E' -derivedDataPath ~/Library/Developer/Xcode/DerivedData/Nudge-hiursflqkxedchggqbbxpgjdebru build 2>&1 | tee /tmp/nudge_build.log | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -20
```

## Install + Launch (copy-paste)

```bash
xcrun simctl terminate 80F84FEC-B3C7-400C-8F73-8A3D888A5A0E com.tarsitgroup.nudge 2>/dev/null
xcrun simctl install 80F84FEC-B3C7-400C-8F73-8A3D888A5A0E ~/Library/Developer/Xcode/DerivedData/Nudge-hiursflqkxedchggqbbxpgjdebru/Build/Products/Debug-iphonesimulator/Nudge.app
xcrun simctl launch 80F84FEC-B3C7-400C-8F73-8A3D888A5A0E com.tarsitgroup.nudge -skipAuth -seedTasks
```

---

## File Map

| File | Path | Lines | Purpose |
|---|---|---|---|
| YouView | `Features/You/YouView.swift` | 650 | Main You tab — REWRITING |
| SettingsView | `Features/Settings/SettingsView.swift` | 283 | Legacy unused — REPLACING with YouSettingsView |
| AquariumView | `Features/Aquarium/AquariumView.swift` | 268 | Aquarium detail — will vector-ify |
| MoodCheckInView | `Features/MoodCheckIn/MoodCheckInView.swift` | 280 | 3-phase flow — KEEP |
| MoodInsightsView | `Features/MoodCheckIn/MoodInsightsView.swift` | 328 | Charts — KEEP |
| MemojiPickerView | `Features/You/MemojiPickerView.swift` | — | UIKit memoji — KEEP |
| NudgyMemoryView | `Features/You/NudgyMemoryView.swift` | — | Memory — KEEP |
| RemindersImportView | `Features/You/RemindersImportView.swift` | 204 | Reminders import — KEEP |
| FishEconomy | `Services/FishEconomy.swift` | — | FishSpecies enum — MODIFY |
| RewardService | `Services/RewardService.swift` | 449 | Fish/snowflakes — reference |
| IntroVectorShapes | `Features/Onboarding/IntroVectorShapes.swift` | 816 | FishView bezier — REUSE |
| AmbientFishScene | `Features/Penguin/AmbientFishScene.swift` | 234 | Swim physics — reference |
| ContentView | `ContentView.swift` | 330 | Tab bar — `YouView()` no params |

---

## Dependency Signatures (exact)

### YouView current @State / @Environment
```swift
@Environment(AppSettings.self) private var settings
@Environment(PenguinState.self) private var penguinState
@Environment(AuthSession.self) private var auth

@State private var showPaywall = false
@State private var selectedVoice: String = NudgyConfig.Voice.openAIVoice
@State private var isPreviewingVoice = false
@State private var selectedPhotoItem: PhotosPickerItem?
@State private var avatarService = AvatarService.shared
@State private var showMemojiPicker = false
@State private var showPhotoPicker = false
@State private var showPersonaPicker = false
@State private var showDailyReview = false
@State private var showRemindersImport = false
```

### Helper signatures (identical in YouView and SettingsView)
```swift
func youSection(title: String, @ViewBuilder content: () -> some View) -> some View
func youRow(icon: String, title: String, subtitle: String? = nil, value: String? = nil) -> some View
func formatHour(_ hour: Int) -> String
func voiceButton(voice: (id: String, name: String, description: String)) -> some View
```

### Types referenced
- `AvatarService.shared` — `Services/AvatarService.swift`
- `NudgyVoiceOutput.shared` — `NudgyEngine/NudgyVoiceOutput.swift`
- `NudgyConfig.Voice.availableVoices` — `NudgyEngine/NudgyConfig.swift`
- `PurchaseService.shared` — `Services/PurchaseService.swift`
- `RewardService.shared` — `Services/RewardService.swift`
- `LiveActivityTip` — `Core/Tips/NudgeTips.swift`
- `DesignTokens` — `Core/Constants.swift`
- `AppTheme` — `Core/Theme/AppTheme.swift`
- `RoutineListView()` — `Features/Routines/RoutineListView.swift` (no params)
- `PersonaPickerView()` — `Features/Persona/PersonaPickerView.swift` (no params)
- `DailyReviewView()` — `Features/DailyReview/DailyReviewView.swift` (no params)
- `MoodCheckInView()` — `Features/MoodCheckIn/MoodCheckInView.swift` (no params)
- `MoodInsightsView()` — `Features/MoodCheckIn/MoodInsightsView.swift` (no params)
- `AquariumView(catches:level:streak:)` — `Features/Aquarium/AquariumView.swift`
- `FishView(size:color:accentColor:)` — `Features/Onboarding/IntroVectorShapes.swift`
- `MoodEntry` — `Models/MoodEntry.swift` (moodLevelRaw, note, loggedAt, tasksCompletedThatDay, energyRaw)
- `MoodLevel` — enum in MoodEntry.swift (awful/rough/okay/good/great, emoji, color)
- `NudgyConversationManager.shared.generateOneShotResponse(prompt:)` — AI mood insight

### .glassEffect pattern
```swift
.glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
```

---

## Phase 1 Checklist — Settings Extraction

**Create:** `Features/You/YouSettingsView.swift`
**Modify:** `Features/You/YouView.swift`
**Delete:** Nothing (SettingsView.swift stays — it's unreferenced anyway)

### Sections MOVING to YouSettingsView:
1. "About You" (userName text field)
2. "Nudge Style" (quiet hours pickers, max daily nudges stepper)  
3. "Routines" (NavigationLink → RoutineListView)
4. "Import" (NavigationLink → RemindersImportView)
5. "Lock Screen" (LiveActivityTip + toggle)
6. "Nudgy" (memory link, voice toggle, voice picker grid)
7. "Upgrade" (Pro upsell → PaywallView) — only if !isPro
8. "Your Style" (persona picker button → PersonaPickerView)
9. "About" (version, support email)
10. "Account" (sign out)

### Sections STAYING in YouView:
1. avatarHeader (compact — will shrink in Phase 6)
2. "Mood" section (aquarium link, check in, insights) — will transform in Phase 2-4
3. "Daily Review" button
4. Gear icon → settings sheet

### State vars MOVING to YouSettingsView:
- showPaywall, selectedVoice, isPreviewingVoice
- showPersonaPicker, showRemindersImport
- liveActivityTip

### State vars STAYING in YouView:
- selectedPhotoItem, avatarService, showMemojiPicker, showPhotoPicker (avatar)
- showDailyReview
- NEW: showSettings

### Sheets MOVING:
- .sheet PaywallView
- .sheet PersonaPickerView
- .sheet RemindersImportView

### Sheets STAYING:
- .sheet MemojiPickerView
- .sheet DailyReviewView
- .photosPicker
- NEW: .sheet YouSettingsView

---

## Phase 2+ Quick Ref

### FishSpecies (needs visual props)
- catfish: 22pt, #4FC3F7/#0288D1
- tropical: 26pt, #FF8A65/#E64A19  
- swordfish: 32pt, #BA68C8/#7B1FA2
- whale: 42pt, #FFD54F/#F57F17

### FishView init
```swift
FishView(size: CGFloat = 32, color: Color = Color(hex: "4FC3F7"), accentColor: Color = Color(hex: "0288D1"))
```

### RewardService public API
- `.fishCatches: [FishCatch]`
- `.level: Int`
- `.currentStreak: Int`
- `.snowflakes: Int`
- `.tasksCompletedToday: Int`
- `.lastFishCatch: FishCatch?`

### AI mood insight
```swift
await NudgyConversationManager.shared.generateOneShotResponse(prompt: String) -> String?
```
