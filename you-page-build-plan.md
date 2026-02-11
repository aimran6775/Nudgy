# You Page Redesign — Build Plan

> **Purpose:** This document is the single source of truth for the You page overhaul.
> Every phase must compile, run, and be visually verified before moving to the next.
> Reference this before writing ANY code.

---

## Ground Rules

1. **Never break the build.** Every phase ends with `BUILD SUCCEEDED` and a working app.
2. **No new files until the old ones are stable.** Extract before you add.
3. **Emoji fish → Vector fish.** Every `Text(species.emoji)` in the aquarium becomes `FishView(size:color:accentColor:)` from `IntroVectorShapes.swift`.
4. **Reuse existing patterns.** `youSection()` / `youRow()` helpers, `DesignTokens`, `AppTheme`, `.glassEffect`, `.nudgeAccessibility()`.
5. **Never call sub-engines directly.** AI goes through `NudgyEngine.shared` or `NudgyConversationManager.shared.generateOneShotResponse()`.
6. **Verify on simulator 80F84FEC before device deploy.** Take screenshots between phases.
7. **Respect reduce motion.** Every animation checks `@Environment(\.accessibilityReduceMotion)`.
8. **All strings use `String(localized:)`.** No hardcoded text.

---

## Current File Map

| File | Role | Status |
|---|---|---|
| `Features/You/YouView.swift` (631 lines) | Main You tab | REWRITE in Phase 2 |
| `Features/You/NudgyMemoryView.swift` | Memory browser | KEEP as-is |
| `Features/You/MemojiPickerView.swift` | UIKit memoji capture | KEEP as-is |
| `Features/Aquarium/AquariumView.swift` (268 lines) | Aquarium detail page | REWRITE in Phase 2 (vector fish) |
| `Features/MoodCheckIn/MoodCheckInView.swift` (280 lines) | 3-phase mood check-in | KEEP — used as full check-in flow |
| `Features/MoodCheckIn/MoodInsightsView.swift` (328 lines) | Charts + trends | KEEP — linked from insight card |
| `Features/Settings/SettingsView.swift` (219 lines) | Legacy settings (unused) | REWRITE as new Settings sheet |
| `Features/Settings/PaywallView.swift` | Pro upgrade paywall | KEEP as-is |
| `Features/Onboarding/IntroVectorShapes.swift` | `FishView`, `FishShape`, etc. | KEEP — reuse vector fish |
| `Features/Penguin/AmbientFishScene.swift` (234 lines) | Homepage swimming fish | KEEP — reference for swim physics |
| `Features/Penguin/CompletionFishBurst.swift` | Completion celebration | KEEP — trigger catch ceremony from here |
| `Services/RewardService.swift` (449 lines) | Fish, snowflakes, streaks | MODIFY — add decoration unlock catalog |
| `Services/FishEconomy.swift` | Species, catches, economy | MODIFY — add visual properties |
| `Models/MoodEntry.swift` | SwiftData mood model | KEEP as-is |

---

## New Files to Create

| File | Phase | Purpose |
|---|---|---|
| `Features/You/YouSettingsView.swift` | Phase 1 | All config settings (extracted from YouView) |
| `Features/Aquarium/AquariumTankView.swift` | Phase 2 | Inline interactive fish tank component |
| `Features/You/QuickMoodCheckInView.swift` | Phase 3 | 1-tap mood emoji row |
| `Features/You/MoodInsightCard.swift` | Phase 4 | AI insight card + service |

---

## Data Flow

```
YouView
├── @Environment(AppSettings.self)
├── @Environment(PenguinState.self)
├── @Environment(AuthSession.self)
├── @Environment(\.modelContext) ← NEW (needed for quick mood save)
│
├── AquariumTankView
│   ├── catches: [FishCatch]     ← RewardService.shared.fishCatches
│   ├── level: Int               ← RewardService.shared.level
│   ├── streak: Int              ← RewardService.shared.currentStreak
│   └── onFishTap: (FishCatch) → Void
│
├── QuickMoodCheckInView
│   ├── @Environment(\.modelContext)
│   ├── @Query last mood entry (today)
│   └── onCheckIn: (MoodLevel) → Void
│
├── MoodInsightCard
│   ├── @Query mood entries
│   └── uses NudgyConversationManager.shared.generateOneShotResponse()
│
├── NavigationLink → AquariumView (detail)
├── NavigationLink → MoodInsightsView
├── NavigationLink → NudgyMemoryView
│
└── .sheet → YouSettingsView
    ├── @Environment(AppSettings.self)
    ├── @Environment(PenguinState.self)
    ├── @Environment(AuthSession.self)
    └── .sheet → PaywallView
```

---

## Phase 1 — Extract Settings (safe refactor)

**Goal:** Move all config sections out of YouView into YouSettingsView. No visual change to the You tab yet — just moves the settings behind a gear icon.

**Steps:**

### 1a. Create `YouSettingsView.swift`

Path: `Nudge/Nudge/Features/You/YouSettingsView.swift`

Sections to MOVE from YouView (cut, not copy):
- "About You" (userName text field)
- "Nudge Style" (quiet hours pickers, max daily nudges stepper)
- "Routines" (NavigationLink → RoutineListView)
- "Lock Screen" (LiveActivityTip + toggle)
- "Nudgy" section (memory link, voice toggle, voice picker grid)
- "Your Style" (persona picker button)
- "Upgrade" (Pro upsell → PaywallView)
- "About" (version, support email)
- "Account" (sign out)

Structure:
```swift
struct YouSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PenguinState.self) private var penguinState
    @Environment(AuthSession.self) private var auth
    @Environment(\.dismiss) private var dismiss
    // + all existing @State from YouView that settings use
    // (showPaywall, selectedVoice, isPreviewingVoice,
    //  showPersonaPicker, selectedPhotoItem, showMemojiPicker,
    //  showPhotoPicker, avatarService)

    var body: some View {
        NavigationStack {
            ScrollView { ... }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                }
        }
    }

    // COPY these helpers into this file (they're private):
    // - settingsSection(title:content:) — renamed from youSection
    // - settingsRow(icon:title:subtitle:value:) — renamed from youRow
    // - formatHour(_:)
    // - voiceButton(voice:)
}
```

### 1b. Update YouView

- Remove all moved sections from the ScrollView body
- Add `@State private var showSettings = false`
- Add toolbar gear icon:
  ```swift
  .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
          Button { showSettings = true } label: {
              Image(systemName: "gearshape.fill")
                  .foregroundStyle(DesignTokens.textSecondary)
          }
      }
  }
  ```
- Add sheet: `.sheet(isPresented: $showSettings) { YouSettingsView() }`
- Remove `@State` vars that moved to YouSettingsView (showPaywall, selectedVoice, etc.)
- KEEP: avatarHeader (compact), mood section, daily review, showDailyReview

### 1c. Add to Xcode project

The new file must be added to the Nudge target in `project.pbxproj`. Use the same file reference pattern as other You/ files.

### 1d. Verify

- [ ] `BUILD SUCCEEDED`
- [ ] You tab shows: avatar, mood section (aquarium link, check in, insights), daily review
- [ ] Gear icon opens settings sheet
- [ ] All settings functional (quiet hours save, voice picker works, sign out works)
- [ ] Sheets inside settings work (PaywallView, PersonaPickerView, MemojiPickerView)

---

## Phase 2 — Inline Aquarium Tank (vector fish)

**Goal:** Replace the "My Aquarium" NavigationLink row with an inline interactive fish tank. Fish rendered with vector `FishView`, not emoji.

### 2a. Add visual properties to `FishSpecies`

File: `Services/FishEconomy.swift`

Add computed properties to `FishSpecies`:
```swift
var displaySize: CGFloat {
    switch self {
    case .catfish:   return 22
    case .tropical:  return 26
    case .swordfish: return 32
    case .whale:     return 42
    }
}

var fishColor: Color {
    switch self {
    case .catfish:   return Color(hex: "4FC3F7")
    case .tropical:  return Color(hex: "FF8A65")
    case .swordfish: return Color(hex: "BA68C8")
    case .whale:     return Color(hex: "FFD54F")
    }
}

var fishAccentColor: Color {
    switch self {
    case .catfish:   return Color(hex: "0288D1")
    case .tropical:  return Color(hex: "E64A19")
    case .swordfish: return Color(hex: "7B1FA2")
    case .whale:     return Color(hex: "F57F17")
    }
}

var swimSpeed: Double {
    switch self {
    case .catfish:   return 3.5
    case .tropical:  return 4.0
    case .swordfish: return 5.0
    case .whale:     return 7.0
    }
}
```

### 2b. Create `AquariumTankView.swift`

Path: `Nudge/Nudge/Features/Aquarium/AquariumTankView.swift`

This is a SELF-CONTAINED component. ~200 lines. It manages its own animation state.

**Init params:**
```swift
struct AquariumTankView: View {
    let catches: [FishCatch]
    let level: Int
    let streak: Int
    var height: CGFloat = 220
    var onFishTap: ((FishCatch) -> Void)? = nil
```

**Internal model (similar to AmbientFishScene.SwimmingFish):**
```swift
private struct TankFish: Identifiable {
    let id: UUID           // matches FishCatch.id
    let catchData: FishCatch
    var x: CGFloat
    var y: CGFloat
    var speed: Double
    var amplitude: CGFloat
    var flipped: Bool
}
```

**Body structure:**
```swift
ZStack {
    // 1. Water gradient background
    RoundedRectangle(cornerRadius: 20)
        .fill(LinearGradient(
            colors: [Color(hex: "001B3A"), Color(hex: "002855"), Color(hex: "001B3A")],
            startPoint: .top, endPoint: .bottom
        ))

    // 2. Sand/gravel bottom strip
    // (subtle gradient at bottom 15% of tank)

    // 3. Bubbles (Canvas-drawn, 6-10 circles, sin-wave rising)

    // 4. Water caustic overlay (subtle Canvas light ripple pattern)

    // 5. Vector fish (from this week's catches, max 12 visible)
    ForEach(tankFish) { fish in
        FishView(
            size: fish.catchData.species.displaySize,
            color: fish.catchData.species.fishColor,
            accentColor: fish.catchData.species.fishAccentColor
        )
        .scaleEffect(x: fish.flipped ? -1 : 1, y: 1)
        .position(x: animatedX(fish), y: animatedY(fish))
        .onTapGesture { onFishTap?(fish.catchData) }
    }

    // 6. Empty state (no catches this week)
    if weeklyCatches.isEmpty {
        VStack(spacing: DesignTokens.spacingSM) {
            Text("🐧")
                .font(.system(size: 40))
            Text(String(localized: "Complete tasks to earn fish!"))
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textSecondary)
        }
    }

    // 7. Glass border
    RoundedRectangle(cornerRadius: 20)
        .strokeBorder(
            LinearGradient(
                colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ), lineWidth: 1
        )

    // 8. Ripple overlay (shows where user tapped water)
}
.frame(height: height)
.clipShape(RoundedRectangle(cornerRadius: 20))
.contentShape(RoundedRectangle(cornerRadius: 20))
.onTapGesture { location in
    // Tap on water (not fish) → show ripple, scatter nearby fish
}
```

**Swim physics (steal from AmbientFishScene pattern):**
- `TimelineView(.animation)` drives a `swimPhase` counter
- Each fish: `x = baseX + sin(phase / speed + offset) * xAmplitude`
- Each fish: `y = baseY + cos(phase / speed * 0.7 + offset) * yAmplitude`
- Fish flip direction (`scaleX`) when changing horizontal direction
- Max 12 fish visible (`.prefix(12)` of weekly catches)
- On scatter: spring offset, drift back after 1.5s

**Ripple effect:**
- `@State private var ripplePoint: CGPoint?`
- `@State private var rippleScale: CGFloat = 0`
- On water tap: set point, animate scale 0→1 with `.easeOut(duration: 0.6)`, fade opacity
- Render as `Circle().stroke()` at ripplePoint

### 2c. Update `AquariumView.swift` (detail page)

Replace emoji fish with vector fish. Same change as tank but in the full-page context:
- `fishView(for:index:)` → use `FishView(size:color:accentColor:)` instead of `Text(species.emoji)`
- `speciesCard(_:)` → keep emoji for the collection grid icons (small enough that emoji works)
- `recentCatchesList` → keep emoji for list items (inline text context)

### 2d. Update YouView to embed AquariumTankView

Replace the "Mood" section's aquarium NavigationLink row with:
```swift
// Aquarium tank (hero)
VStack(spacing: DesignTokens.spacingSM) {
    AquariumTankView(
        catches: RewardService.shared.fishCatches,
        level: RewardService.shared.level,
        streak: RewardService.shared.currentStreak,
        onFishTap: { fish in selectedFish = fish }
    )

    // Weekly progress bar
    weeklyProgressBar

    // Species strip
    speciesStrip

    // "See full aquarium →"
    NavigationLink { AquariumView(...) } label: {
        Text(String(localized: "See Full Aquarium"))
            .font(AppTheme.caption)
            .foregroundStyle(DesignTokens.accentActive)
    }
}
```

Add `@State private var selectedFish: FishCatch?` to YouView. Show a small info popover when set.

### 2e. Verify

- [ ] `BUILD SUCCEEDED`
- [ ] You tab shows inline aquarium tank with vector fish swimming
- [ ] Fish are colored per species (blue catfish, coral tropical, purple swordfish, gold whale)
- [ ] Tapping a fish shows info (species + task name)
- [ ] Tapping water shows ripple
- [ ] Weekly progress bar visible below tank
- [ ] "See Full Aquarium" links to detail page
- [ ] Detail page also uses vector fish
- [ ] Empty state works (no fish → penguin + prompt)
- [ ] `reduceMotion` → fish static, no bubbles

---

## Phase 3 — Quick Mood Check-In

**Goal:** Add a 1-tap mood check-in row directly on the You page. No navigation, no multi-step flow.

### 3a. Create `QuickMoodCheckInView.swift`

Path: `Nudge/Nudge/Features/You/QuickMoodCheckInView.swift`

~100 lines. Self-contained.

```swift
struct QuickMoodCheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoodEntry.loggedAt, order: .reverse)
    private var recentMoods: [MoodEntry]

    @State private var justCheckedIn: MoodLevel? = nil
    @State private var showFullCheckIn = false

    // Today's last mood (if any)
    private var todaysMood: MoodLevel? {
        let start = Calendar.current.startOfDay(for: Date())
        return recentMoods.first(where: { $0.loggedAt >= start })?.moodLevel
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            HStack {
                Text(String(localized: "How are you feeling?"))
                    .font(AppTheme.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer()
                if todaysMood != nil || justCheckedIn != nil {
                    Button(String(localized: "Full Check-In")) {
                        showFullCheckIn = true
                    }
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.accentActive)
                }
            }

            HStack(spacing: DesignTokens.spacingMD) {
                ForEach(MoodLevel.allCases, id: \.self) { mood in
                    moodButton(mood)
                }
            }
        }
        .sheet(isPresented: $showFullCheckIn) {
            MoodCheckInView()
        }
    }

    private func moodButton(_ mood: MoodLevel) -> some View {
        let isSelected = (justCheckedIn ?? todaysMood) == mood
        return Button {
            quickSave(mood)
        } label: {
            Text(mood.emoji)
                .font(.system(size: 28))
                .scaleEffect(isSelected ? 1.15 : 1.0)
                .padding(DesignTokens.spacingSM)
                .background {
                    if isSelected {
                        Circle()
                            .fill(mood.color.opacity(0.2))
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
        .nudgeAccessibility(
            label: mood.label,
            hint: isSelected
                ? String(localized: "Currently selected mood")
                : String(localized: "Tap to log mood as \(mood.label)")
        )
    }

    private func quickSave(_ mood: MoodLevel) {
        let repo = NudgeRepository(modelContext: modelContext)
        let completedToday = repo.completedTodayCount()

        let entry = MoodEntry(
            mood: mood,
            tasksCompleted: completedToday
        )
        modelContext.insert(entry)
        try? modelContext.save()

        justCheckedIn = mood
        HapticService.shared.lightTap()
    }
}
```

### 3b. Embed in YouView

Place below the aquarium section:
```swift
youSection(title: String(localized: "Mood")) {
    QuickMoodCheckInView()
}
```

### 3c. Verify

- [ ] `BUILD SUCCEEDED`
- [ ] 5 emoji buttons render horizontally
- [ ] Tapping saves a MoodEntry (check via MoodInsightsView)
- [ ] Today's previous mood shows glow
- [ ] "Full Check-In" link opens MoodCheckInView sheet
- [ ] Haptic fires on tap
- [ ] VoiceOver reads each mood label

---

## Phase 4 — AI Mood Insight Card

**Goal:** A card below mood check-in showing an AI-generated one-liner about mood patterns.

### 4a. Create `MoodInsightCard.swift`

Path: `Nudge/Nudge/Features/You/MoodInsightCard.swift`

~120 lines.

```swift
struct MoodInsightCard: View {
    @Query(sort: \MoodEntry.loggedAt, order: .reverse)
    private var entries: [MoodEntry]

    @State private var insight: String? = nil
    @State private var isLoading = false
    @State private var lastGeneratedDate: String = ""

    var body: some View {
        Group {
            if entries.count < 3 {
                // Not enough data
                hintCard
            } else if isLoading {
                shimmerCard
            } else if let insight {
                insightCard(insight)
            } else {
                // Waiting to generate
                hintCard
            }
        }
        .onAppear { generateIfNeeded() }
        .onChange(of: entries.count) { _, _ in generateIfNeeded() }
    }

    private func generateIfNeeded() {
        let today = Date().formatted(date: .abbreviated, time: .omitted)
        guard today != lastGeneratedDate else { return }
        guard entries.count >= 3 else { return }
        guard NudgyEngine.shared.isAvailable else { return }

        isLoading = true
        Task {
            let prompt = buildPrompt()
            if let response = await NudgyConversationManager.shared
                .generateOneShotResponse(prompt: prompt) {
                await MainActor.run {
                    insight = response
                    lastGeneratedDate = today
                    isLoading = false
                }
            } else {
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func buildPrompt() -> String {
        // Last 14 entries, format as: "Mon: 😊 (4 tasks), Tue: 😐 (1 task)"
        // Ask: "In ONE short sentence (max 15 words), give a mood insight
        //        or encouragement. Be warm, specific, brief. No emoji."
        let recent = entries.prefix(14)
        let lines = recent.map { entry in
            let day = entry.loggedAt.formatted(.dateTime.weekday(.abbreviated))
            return "\(day): \(entry.moodLevel.emoji) (\(entry.tasksCompletedThatDay) tasks)"
        }
        return """
        You are Nudgy, a friendly productivity penguin. \
        Here are the user's recent mood check-ins:\n\(lines.joined(separator: "\n"))\n\n\
        In ONE short sentence (max 15 words), share a specific observation \
        about their mood pattern or give encouragement. Be warm and specific. No emoji.
        """
    }
}
```

Visual: small glass card with ✨ icon + insight text + "See Insights →" link.

### 4b. Embed in YouView

Place below QuickMoodCheckInView inside the Mood section:
```swift
youSection(title: String(localized: "Mood")) {
    VStack(spacing: DesignTokens.spacingMD) {
        QuickMoodCheckInView()

        Divider().overlay(Color.white.opacity(0.06))

        MoodInsightCard()

        NavigationLink {
            MoodInsightsView()
        } label: {
            youRow(
                icon: "chart.line.uptrend.xyaxis",
                title: String(localized: "See Full Insights")
            )
        }
        .buttonStyle(.plain)
    }
}
```

### 4c. Verify

- [ ] `BUILD SUCCEEDED`
- [ ] With <3 mood entries: shows hint ("Check in a few more times...")
- [ ] With 3+ entries: loading shimmer → AI insight text
- [ ] Insight regenerates once per day
- [ ] Works without AI (graceful fallback — shows hint card)
- [ ] "See Full Insights" navigates to MoodInsightsView
- [ ] No crash if OpenAI key missing

---

## Phase 5 — Aquarium Interactivity & Polish

**Goal:** Make the aquarium feel alive with interactions.

### 5a. Feed mechanic

In `AquariumTankView`, add:
- `DragGesture` that detects downward swipe inside the tank
- `@State private var foodParticles: [FoodParticle]` — small circles with gravity
- Fish nearest to food particle swim toward it (increase speed, adjust target position)
- Particle disappears on "collision" (distance < 15pt)
- Gate on `RewardService.shared.tasksCompletedToday` — can feed once per completed task
- `@State private var feedsAvailable: Int` decrements on each feed

### 5b. Catch ceremony

Triggered when `RewardService.shared.lastFishCatch` changes (via `.onChange`).

Overlay on YouView (not inside tank):
- Fishing line `Path` drops from top
- New `FishView` appears attached to line, wiggling
- Auto-reels after 2s (or tap to reel)
- Fish splashes into tank position with ripple + bubble burst
- Species name + "+X ❄️" text fades in/out
- Total duration: 3s, skippable

### 5c. Tank decorations

- Define `TankDecoration` enum: `.coral`, `.seaweed`, `.castle`, `.treasureChest`
- Each has: `unlockCost: Int` (snowflakes), `Shape`-based visual, position
- Stored in `NudgyWardrobe` (existing SwiftData model)
- Small "🪸" button in tank corner → opens decoration shop popover
- Selected decorations render at bottom of tank as static views

### 5d. Verify

- [ ] Feed: swipe down drops food, fish chase, limited by tasks completed
- [ ] Catch: completing a task triggers fishing ceremony on You page
- [ ] Decorations: can buy with snowflakes, appear in tank
- [ ] Performance: 60fps with 12 fish + bubbles + decorations
- [ ] Memory: no leaks from animation loops
- [ ] Haptics: feed → `.swipeDone()`, catch → `.celebrate()`

---

## Phase 6 — Page Polish & Accessibility

### 6a. Compact avatar header

Shrink from centered 88pt to left-aligned 48pt with name inline:
```
[48pt avatar] Abdullah        [⚙️]
```

### 6b. Remaining sections

Below mood, keep these compact:
- Nudgy's Memory (NavigationLink → NudgyMemoryView)
- Daily Review (button → DailyReviewView sheet)
- Upgrade to Pro (if !isPro, subtle banner)

### 6c. Accessibility audit

- Every interactive element: `.nudgeAccessibility(label:hint:traits:)`
- Fish tap: `.accessibilityLabel("Tap to see fish details")`
- Mood buttons: labels + selected state
- Tank: `.accessibilityElement(children: .contain)` with summary
- Dynamic Type: `.scaledPadding()`, `.scaledFrame()` where needed

### 6d. Final verify

- [ ] `BUILD SUCCEEDED` (sim + device)
- [ ] Full page flow: avatar → tank → mood → insight → memory → review → upgrade
- [ ] Settings sheet: all options functional
- [ ] VoiceOver: complete navigation, all elements announced
- [ ] Dynamic Type: XXL doesn't break layout
- [ ] Reduce Motion: all animations disabled gracefully
- [ ] Dark mode: already enforced, just verify contrast
- [ ] Performance: scroll is smooth, no jank
- [ ] Device deploy: install on iPhone, test real-world

---

## Final YouView Layout (target state)

```
┌─────────────────────────────────┐
│ [48pt avatar] Name      [⚙️]   │
├─────────────────────────────────┤
│                                 │
│ ┌─────────────────────────────┐ │
│ │  🐟  🐠    🗡️       🐋    │ │ ← AquariumTankView (220pt)
│ │    ○  ○    bubbles         │ │    vector FishView
│ │  🐟      🐠       🐟      │ │    tap fish → info
│ │  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │ │    tap water → ripple
│ └─────────────────────────────┘ │    swipe down → feed
│  ████████████░░░░ 8/12 this wk  │
│  [🐟×4] [🐠×3] [🗡️×1] [🐋×0] │
│  See Full Aquarium →            │
├─────────────────────────────────┤
│ MOOD                            │
│ How are you feeling?  Full →    │
│  😫   😔   😐   😊   🤩       │ ← 1-tap check-in
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│ ✨ You feel best on 3+ task days│ ← AI insight
│  📊 See Full Insights →        │
├─────────────────────────────────┤
│ 🧠 Nudgy's Memory →            │
│ 🌙 Review My Day →             │
├─────────────────────────────────┤
│ ⭐ Upgrade to Nudge Pro →      │ ← only if !isPro
└─────────────────────────────────┘
```

---

## Build & Deploy Commands

```bash
# Simulator build
cd "/Users/abdullahimran/Desktop/untitled folder/Nudge"
xcodebuild -scheme Nudge \
  -destination 'platform=iOS Simulator,id=80F84FEC-B3C7-400C-8F73-8A3D888A5A0E' \
  -derivedDataPath ~/Library/Developer/Xcode/DerivedData/Nudge-hiursflqkxedchggqbbxpgjdebru \
  build 2>&1 | tail -5

# Install + launch sim
xcrun simctl terminate 80F84FEC com.tarsitgroup.nudge 2>/dev/null
xcrun simctl install 80F84FEC ~/Library/Developer/Xcode/DerivedData/Nudge-hiursflqkxedchggqbbxpgjdebru/Build/Products/Debug-iphonesimulator/Nudge.app
xcrun simctl launch 80F84FEC com.tarsitgroup.nudge -skipAuth -seedTasks

# Screenshot
xcrun simctl io 80F84FEC screenshot ~/Desktop/you_page_phase_N.png

# Device build
xcodebuild -scheme Nudge -destination 'generic/platform=iOS' \
  -derivedDataPath ~/Library/Developer/Xcode/DerivedData/Nudge-hiursflqkxedchggqbbxpgjdebru \
  -allowProvisioningUpdates build 2>&1 | tail -5

# Device deploy
xcrun devicectl device install app --device 09FBBBCD-4F17-5A40-9247-5D9592E746F5 \
  ~/Library/Developer/Xcode/DerivedData/Nudge-hiursflqkxedchggqbbxpgjdebru/Build/Products/Debug-iphoneos/Nudge.app
xcrun devicectl device process launch --device 09FBBBCD-4F17-5A40-9247-5D9592E746F5 \
  --terminate-existing com.tarsitgroup.nudge
```

---

## Anti-Patterns to Avoid

1. **Don't create 500+ line files.** AquariumTankView should be ~200 lines. If it's growing, extract sub-components.
2. **Don't animate with `Timer.publish`.** Use `TimelineView(.animation)` for smooth 60fps.
3. **Don't use `onAppear` for animations that should be continuous.** Use `TimelineView` or `.repeatForever`.
4. **Don't break existing navigation.** Deep links (`nudge://viewTask`, etc.) must still work.
5. **Don't duplicate FishView.** Import from IntroVectorShapes, don't copy the struct.
6. **Don't nest NavigationStacks.** YouView has one. Sheets that need navigation get their own.
7. **Don't call `modelContext.save()` without `try?`.** SwiftData can throw.
8. **Don't forget `@Bindable var settings = settings`** for two-way bindings inside body.
9. **Don't use `.linear` animations.** Use `.spring()` or `.easeOut()` per AnimationConstants.
10. **Don't add Lottie yet.** Vector SwiftUI fish first. Lottie overlay is a future enhancement, not a Phase 1-6 dependency.
