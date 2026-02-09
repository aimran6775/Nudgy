# Nudge — 20-Phase Development Plan

> **Derived from:** nudge-prd.md v2.1
> **Date:** February 7, 2026
> **Team:** 2 engineers
> **Timeline:** ~6 weeks to App Store submission (Phases 1–18), then post-launch (19–20)
> **Quality Bar:** Apple Editor's Choice candidate — every phase ships production-grade work, not prototypes

---

## How to Use This Plan

Each phase is a **self-contained unit of work** with clear inputs, outputs, and a definition of done. Phases are sequential — each builds on the previous. Some phases are 1 day, some are 2–3 days, depending on complexity.

**Rules:**
1. Never move to the next phase until the current one's "Done When" criteria are met
2. Every phase includes accessibility + haptics + animation from the start — these are NOT bolt-on tasks
3. All strings go through `String(localized:)` from Phase 1 — no hardcoded text ever
4. Commit after every phase. Tag milestones (Phase 5, 10, 15, 18)
5. If a phase takes 2x longer than estimated, stop and re-scope — don't silently slip

---

## Phase 0: Pre-Code Decisions ⏱ 1 day
*Resolve open questions that block development*

### Tasks
- [ ] **Verify "Nudge" name availability** on the App Store (search App Store Connect). Have 2 backup names ready
- [ ] **Decide midnight behavior:** incomplete items auto-roll to tomorrow (recommended — ADHD brains shouldn't wake up to guilt)
- [ ] **Decide pricing:** ship with $9.99/mo and $59.99/yr. Can A/B test later with App Store product page variants
- [ ] **Commission penguin character art:** post job on Fiverr/99designs today ($200–500 budget). Need 6 expression states as vector PDFs: idle, happy, thinking, sleeping, celebrating, thumbs-up. Delivery: 5–7 days. **Alternative:** design minimal line art in Figma ourselves if budget is tight
- [ ] **OpenAI API key:** create account, add $10 credit, generate API key. Store in Xcode scheme environment variable (never hardcode)
- [ ] **Apple Developer account:** confirm active membership, team ID `XG936GFSKZ` is valid, certificates are current
- [ ] **Create App Group** in Apple Developer portal: `group.com.nudge.app` — needed for Share Extension data handoff

### Done When
- [ ] All 7 decisions documented in this file (check boxes above)
- [ ] Penguin art commission submitted (or Figma design started)
- [ ] API key secured and tested with a curl call
- [ ] App Group registered in developer portal

---

## Phase 1: Xcode Project Scaffolding ⏱ 1 day
*Transform the default template into the PRD's architecture*

### Tasks
- [ ] **Fix Xcode project settings:**
  - Deployment target → `17.0`
  - Targeted Device Family → `1` (iPhone only)
  - Remove macOS and visionOS from Supported Platforms
  - `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`
  - Enable SwiftLint (add via SPM: `realm/SwiftLint` plugin)
- [ ] **Add extension targets** (File → New → Target):
  - `NudgeShareExtension` — Share Extension
  - `NudgeWidget` — Widget Extension (stub for v1.1)
  - `NudgeLiveActivity` — (will live inside main target using ActivityKit, no separate target needed)
- [ ] **Configure App Group** in Signing & Capabilities for both main app and Share Extension: `group.com.nudge.app`
- [ ] **Add entitlements:**
  - Push Notifications (already configured ✅)
  - App Groups: `group.com.nudge.app`
  - Background Modes: `remote-notification`, `background-fetch` (for Live Activity refresh)
- [ ] **Create full folder structure** per PRD:
  ```
  Nudge/
  ├── Core/Theme/
  ├── Core/Accessibility/
  ├── Core/Extensions/
  ├── Resources/Sounds/
  ├── Models/
  ├── Services/
  ├── Features/OneThing/
  ├── Features/BrainDump/
  ├── Features/AllItems/
  ├── Features/Snooze/
  ├── Features/Settings/
  ├── Features/Onboarding/
  ├── Shared/Components/
  ```
- [ ] **Create `Localizable.xcstrings`** String Catalog with initial keys
- [ ] **Delete default template files:** Remove boilerplate `Item.swift`, default `ContentView.swift` list code
- [ ] **Create placeholder files** for every file in the PRD's project structure (empty stubs with `// TODO: Phase X` markers)
- [ ] **Set up `Constants.swift`** with all design tokens:
  - Colors: canvas `#000000`, card surface `#1C1C1E`, all accent hex values
  - Free tier limits: 3 dumps/day, 5 saved items
  - Animation: timing defaults
  - App Group suite name: `"group.com.nudge.app"`

### Done When
- [ ] Project builds with zero warnings and zero errors
- [ ] All folder groups visible in Xcode navigator matching PRD structure
- [ ] Share Extension target exists and builds
- [ ] App Group configured on both targets
- [ ] `Constants.swift` compiles with all design tokens accessible
- [ ] SwiftLint runs on build

---

## Phase 2: Design System — Theme + Dark Card + Accent Colors ⏱ 1.5 days
*The visual foundation that every screen sits on*

### Tasks
- [ ] **`AppTheme.swift`** — Full design token system:
  - `Color` extensions for all PRD hex values (canvas, card surface, text primary/secondary/tertiary, all accents)
  - Typography using `Font.system()` with Dynamic Type support — `.title`, `.headline`, `.body`, `.caption` with proper weight mapping to SF Pro
  - Spacing constants (4pt grid)
  - Corner radii (16pt cards, 12pt buttons, 8pt chips)
- [ ] **`AccentColorSystem.swift`** — Dynamic accent engine:
  - Static status colors: blue (active), green (complete), amber (stale 3+ days), red (overdue)
  - Time-aware hue shift: `TimelineView(.periodic(from: .now, by: 300))` driving hue interpolation ±15° from base `#007AFF` on a 24-hour sine curve
  - Function: `accentColor(for status: ItemStatus, at date: Date) -> Color`
  - Reduce Motion: skip hue animation, use static blue
- [ ] **`DarkCard.swift`** — Reusable card component:
  - Background: `#1C1C1E` at 80% opacity with `.ultraThinMaterial`
  - Border: 0.5px `RoundedRectangle` stroke in accent color (dynamic by status)
  - Corner radius: 16pt
  - Parameters: `accentColor`, `content` (ViewBuilder)
  - Supports Dynamic Type — card height adapts to text size
  - VoiceOver: card is a single accessibility element with `.accessibilityLabel`
- [ ] **`AnimationConstants.swift`** — Single source of truth:
  - `cardSwipeDone`: `interpolatingSpring(stiffness: 200, damping: 18)`
  - `cardSwipeSnooze`: `spring(response: 0.5, dampingFraction: 0.8)`
  - `cardSwipeSkip`: `interpolatingSpring(stiffness: 150, damping: 20)`
  - `cardAppear`: stagger delay 0.15s, offset 50pt
  - `micTapScale`: 1.0 → 1.15 → 1.0 over 0.3s
  - `penguinBounce`: total 0.6s with overshoot
  - `reducedMotionFade`: `.easeOut(duration: 0.2)`
  - Static method: `animation(for key: AnimationKey) -> Animation` that checks `UIAccessibility.isReduceMotionEnabled` and returns appropriate animation
- [ ] **`DynamicTypeModifiers.swift`** — Custom ViewModifiers:
  - `ScaledFont` modifier that maps custom font sizes to Dynamic Type sizes
  - `ScaledPadding` modifier for adaptive spacing
- [ ] **`VoiceOverHelpers.swift`** — Extensions:
  - `View` extension: `.nudgeAccessibility(label:hint:)` convenience wrapper
  - `View` extension: `.nudgeAccessibilityAction(name:action:)` for custom swipe actions

### Done When
- [ ] A test view renders a `DarkCard` on pure black background with blue accent border — looks identical to PRD mockup
- [ ] Accent color shifts visibly when simulating different times of day (override `Date()` for testing)
- [ ] Card text scales correctly at all 7 Dynamic Type sizes (test in Accessibility Inspector)
- [ ] VoiceOver reads the card as a single element with label
- [ ] AnimationConstants returns cross-fade when Reduce Motion is enabled

---

## Phase 3: SwiftData Models + Repository ⏱ 1 day
*The data layer that every feature reads and writes*

### Tasks
- [ ] **`NudgeItem.swift`** — SwiftData `@Model`:
  - All properties from PRD: `id`, `content`, `sourceType`, `sourceUrl`, `sourcePreview`, `status`, `snoozedUntil`, `createdAt`, `completedAt`, `sortOrder`, `emoji`, `actionType`, `actionTarget`, `contactName`, `aiDraft`, `aiDraftSubject`, `draftGeneratedAt`
  - Enums: `SourceType` (.voiceDump, .share, .manual), `ItemStatus` (.active, .snoozed, .done, .dropped), `ActionType` (.call, .text, .email, .openLink)
  - Computed properties: `isStale` (3+ days), `isOverdue` (past snoozedUntil), `accentStatus` (returns which accent to use)
- [ ] **`BrainDump.swift`** — SwiftData `@Model`:
  - `id`, `rawTranscript`, `processedAt`, relationship to `[NudgeItem]`
- [ ] **`AppSettings.swift`** — `@Observable` class with `@AppStorage`:
  - All settings from PRD: quiet hours, max nudges, Live Activity toggle, isPro, daily dumps used, saved items count, user name
  - Method: `resetDailyCounters()` — called at midnight
  - Method: `canDump() -> Bool` — checks free tier limit
  - Method: `canSave() -> Bool` — checks free tier limit
- [ ] **`NudgeRepository.swift`** — Data access layer:
  - `fetchActiveItems() -> [NudgeItem]` — sorted by PRD ordering logic (due times first → overdue → recent → snoozed approaching)
  - `fetchSnoozedItems() -> [NudgeItem]`
  - `fetchCompletedToday() -> [NudgeItem]`
  - `fetchStaleItems() -> [NudgeItem]` — 3+ days old, still active
  - `markDone(_ item: NudgeItem)`
  - `markSkipped(_ item: NudgeItem)`
  - `snooze(_ item: NudgeItem, until: Date)`
  - `createFromBrainDump(transcript: String, items: [ParsedTask])`
  - `createFromShare(content: String, url: String?, snoozeUntil: Date?)`
  - `ingestFromShareExtension()` — reads App Group UserDefaults, creates SwiftData items
- [ ] **Update `NudgeApp.swift`:**
  - Replace default `Item.self` schema with `NudgeItem.self` and `BrainDump.self`
  - Inject `AppSettings` into environment
  - Call `ingestFromShareExtension()` on app launch

### Done When
- [ ] Unit tests pass for: create item, mark done, mark skipped, snooze with date, fetch ordering, stale detection, daily counter reset
- [ ] App launches without crash with new SwiftData schema
- [ ] `AppSettings` persists across app restarts
- [ ] Repository correctly orders items per PRD priority rules (test with 10+ items in various states)

---

## Phase 4: Haptic + Sound + Accessibility Services ⏱ 0.5 days
*The invisible quality layers that make Nudge feel premium*

### Tasks
- [ ] **`HapticService.swift`:**
  - Singleton with pre-warmed generators: `UIImpactFeedbackGenerator` (light, medium, soft), `UINotificationFeedbackGenerator`, `UISelectionFeedbackGenerator`
  - Pre-warm on app launch: `.prepare()` on all generators
  - Methods matching PRD haptic table: `.swipeDone()`, `.swipeSnooze()`, `.swipeSkip()`, `.micStart()`, `.micStop()`, `.cardAppear()`, `.snoozeSelected()`, `.shareSaved()`, `.actionTap()`, `.error()`
  - Each method calls the correct generator + style from the PRD
- [ ] **`SoundService.swift`:**
  - Load `.caf` files from bundle (placeholder silent files for now — real sounds in Phase 17)
  - Methods: `.playBrainDumpStart()`, `.playTaskDone()`, `.playAllClear()`, `.playNudgeKnock()`
  - Check `AVAudioSession` for Silent Mode — skip audio if ringer is off
  - Use `AudioServicesPlaySystemSound` for non-blocking playback
- [ ] **`AccessibilityService.swift`:**
  - `@Observable` class monitoring:
    - `UIAccessibility.isReduceMotionEnabled` → published property
    - `UIAccessibility.isBoldTextEnabled` → published property
    - `UIAccessibility.preferredContentSizeCategory` → published property
  - Subscribe to `UIAccessibility.reduceMotionStatusDidChangeNotification` etc.
  - Inject into SwiftUI environment for all views to read

### Done When
- [ ] Each haptic method produces the correct physical feel on a real device (simulator won't work)
- [ ] Sound methods play audio when ringer is on, stay silent when off
- [ ] AccessibilityService correctly detects Reduce Motion toggle in real-time

---

## Phase 5: Penguin Mascot ⏱ 1 day
*The soul of the app — warm, alive, never static*

### Tasks
- [ ] **`PenguinMascot.swift`** — SwiftUI view with state machine:
  - **Input:** `PenguinState` enum: `.idle`, `.happy`, `.thinking`, `.sleeping`, `.celebrating`, `.thumbsUp`
  - **Idle animation:** Slow blink every ~8 seconds (eyes close 0.15s, stay closed 0.2s, open 0.15s). Gentle body sway ±2pt horizontal on 6s loop using `sin(time) * 2`
  - **Happy bounce:** Jump up 8pt → land with squash/stretch → eyes become crescents. Total 0.6s with overshoot
  - **Thinking:** Tilted head, 3 bouncing dots above head in sequence
  - **Sleeping:** Eyes closed (crescents), slight lean, subtle Z's floating up
  - **Celebrating:** Both flippers up, slight jump, sparkle particles
  - **Thumbs-up:** One flipper raises 0.2s, holds 0.1s, lowers 0.1s
- [ ] **Placeholder art:** Use SF Symbols or basic SwiftUI shapes (circles, ellipses) to create a geometric penguin. Replace with commissioned art when it arrives
  - Body: white `Ellipse` with dark wing shapes
  - Eyes: two small circles that animate for blink
  - Beak: small orange triangle
  - Accent tint: `.colorMultiply(accentColor)` on a scarf/belly element
- [ ] **Reduce Motion:** When enabled, skip sway and bounce. Penguin still blinks but doesn't move position
- [ ] **VoiceOver:** `.accessibilityLabel("Nudge penguin, looking happy")` — label changes with state
- [ ] **Size variants:** Mascot renders at 3 sizes: large (empty state, 120pt), medium (One-Thing idle, 60pt), small (share extension confirm, 40pt)

### Done When
- [ ] Penguin renders in all 6 states with smooth transitions between them
- [ ] Idle blink loop runs indefinitely without memory leak
- [ ] Happy bounce plays and returns to idle automatically
- [ ] VoiceOver reads appropriate label for each state
- [ ] Penguin looks presentable (even with placeholder shapes — the animation quality matters more than art at this stage)

---

## Phase 6: Brain Dump — Speech + AI ⏱ 2 days
*The core capture mechanic — 5 seconds from thought to card*

### Tasks
- [ ] **`SpeechService.swift`:**
  - Wrap `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`
  - Request microphone + speech permissions on first use (not in onboarding)
  - Start/stop recording methods returning `AsyncStream<String>` for live transcript
  - **55-second cap** with visual countdown (last 10 seconds show countdown in accent amber)
  - Auto-stop at 55s → process what we have → allow immediate second dump
  - Error handling: permission denied, recognizer unavailable, offline fallback
  - VoiceOver: announce "Recording started", "Recording stopped", "Processing"
- [ ] **`AIService.swift`:**
  - `splitBrainDump(transcript: String) async throws -> [ParsedTask]`
  - `ParsedTask` struct: `task: String`, `emoji: String`, `action: ActionType?`, `contact: String?`
  - Send to GPT-4o-mini with exact PRD prompt
  - Parse JSON response with error handling (malformed JSON → fallback to single raw card)
  - Offline detection → save raw transcript, return single card with full text
  - Timeout: 5 seconds → show cancel option
  - Mock mode for testing without API calls
- [ ] **`BrainDumpView.swift`:**
  - Full-screen modal on pure black background
  - Large pulsing mic button (center) with accent blue glow ring
  - Tap to start: button scales 1.15x (spring), glow ring pulses continuously, haptic `.micStart()`
  - Live transcript appearing in white text below mic (`.typewriterEffect`)
  - Tap to stop: button scales down, glow fades, haptic `.micStop()`
  - Processing state: mic disappears → penguin "thinking" animation appears → bouncing dots
  - Results: cards materialize one by one with staggered slide-in (0.15s delay)
  - Each card: emoji + task text + accent border + "Edit" pencil icon
  - Bottom: "Save all" button (accent blue) → dismiss modal → cards added to queue
  - **TipKit:** "Tap the mic to brain dump" tip on first visit
- [ ] **`BrainDumpViewModel.swift`:**
  - Manages recording state, transcript, AI response, card creation
  - Coordinates SpeechService → AIService → NudgeRepository
  - Tracks daily dump count for free tier enforcement
  - Handles errors gracefully (show toast, never crash)

### Done When
- [ ] Full flow works end-to-end: tap mic → speak → see transcript → penguin thinks → cards appear → save → cards in queue
- [ ] 55-second cap with countdown works
- [ ] Offline mode saves raw transcript as single card
- [ ] Free tier blocks 4th dump with friendly message
- [ ] VoiceOver narrates entire flow
- [ ] All animations use spring physics from `AnimationConstants`
- [ ] Haptics fire on mic start/stop/card appear

---

## Phase 7: One-Thing View — Card Stack + Swipe Gestures ⏱ 2 days
*The home screen — the single most important view in the app*

### Tasks
- [ ] **`OneThingView.swift`:**
  - Pure black background, full screen
  - Single `CardView` centered with current highest-priority item
  - Penguin mascot below card (medium size, idle state)
  - Floating queue position: "3 of 7" in grey, top-right
  - Bottom navigation bar: Brain Dump (🎤), All Items (📋), Settings (⚙️)
  - Tab bar: accent blue on active icon with `.symbolEffect(.bounce)`, grey on inactive
  - Cross-fade transition (0.25s) between tabs
  - When empty: full-screen empty state — large sleeping penguin + green glow + "Your brain is clear. Go enjoy something."
  - Empty state triggers: `.playAllClear()` sound + success haptic
  - VoiceOver: reads card content first, then swipe actions, then navigation
- [ ] **`CardView.swift`:**
  - `DarkCard` with accent border based on item status (blue/amber/red)
  - Task text in white (`.title2` weight, Dynamic Type)
  - Emoji in top-left
  - Source metadata in grey (age, source app)
  - Stale items: amber border with gentle pulse animation (3s loop)
  - Action button (if applicable): 📞/💬/🔗 icon, accent-tinted, below task text
  - AI draft preview (Pro only): collapsible text below action button, "Edit" option
  - **`DragGesture` for swipe interactions:**
    - Card follows finger position (interruptible)
    - Swipe right >100pt: commit to Done → card flies right with 15° rotation + green flash + particle burst → next card slides in from bottom with spring → penguin happy bounce → haptic `.swipeDone()` → sound `.playTaskDone()`
    - Swipe left >100pt: commit to Snooze → card drifts left, fades → snooze picker slides up → haptic `.swipeSnooze()`
    - Swipe down >80pt: commit to Skip → card drops with gravity → next card from top → haptic `.swipeSkip()`
    - Partial swipe + release: card springs back to center (interruptible spring)
    - Visual hints during drag: slight opacity reduction, border color shifts to indicate action
  - VoiceOver custom actions: `.accessibilityAction(named: "Complete")`, `.accessibilityAction(named: "Snooze")`, `.accessibilityAction(named: "Skip")`
- [ ] **Task queue management:**
  - `@Query` fetching from `NudgeRepository.fetchActiveItems()`
  - When item done/skipped: remove from array, advance to next
  - When snoozed: remove from array, update `snoozedUntil` in SwiftData
  - When all items done: transition to empty state with celebration animation

### Done When
- [ ] Swipe right, left, down all work with correct spring animations + haptics + sounds
- [ ] Card follows finger precisely — no lag, no jumping
- [ ] Partial swipe snaps back smoothly
- [ ] Next card slides in after each action
- [ ] Empty state shows sleeping penguin with green glow + chime
- [ ] Queue position counter updates correctly
- [ ] Stale items pulse with amber border
- [ ] VoiceOver users can navigate and act on cards using custom actions
- [ ] 60fps on iPhone 12 during swipe animations (verify in Instruments preview)

---

## Phase 8: Snooze Picker + Action Shortcuts ⏱ 1 day
*Two critical interaction layers that make cards actionable*

### Tasks
- [ ] **`SnoozePickerView.swift`:**
  - Overlay that slides up from bottom with spring animation
  - Dark card background, accent-colored buttons
  - Quick options: "Later today" (3hrs), "Tomorrow morning" (9am), "This weekend" (Sat 10am), "Next week" (Mon 9am)
  - Custom: native `DatePicker` with dark styling
  - Tap option → selection haptic → card flies away with "See you then" text → picker dismisses
  - VoiceOver: each option is labeled with the resolved date ("Tomorrow morning, February 9th at 9 AM")
- [ ] **`ActionService.swift`:**
  - `openCall(number: String)` → `UIApplication.shared.open(URL(string: "tel:\(number)")!)`
  - `openLink(url: String)` → `UIApplication.shared.open(URL(string: url)!)`
  - `openEmail(to: String, subject: String?, body: String?)` → `mailto:` URL scheme
  - `openTextMessage(to: String, body: String?)` → present `MFMessageComposeViewController` via `UIViewControllerRepresentable` wrapper (because `sms:` doesn't support body)
  - `MessageComposeView: UIViewControllerRepresentable` wrapper for SwiftUI
  - Haptic `.actionTap()` on every action launch
- [ ] **`ContactService.swift`:**
  - `pickContact() async -> CNContact?` — presents `CNContactPickerViewController`
  - Extract phone number and/or email from selected contact
  - Save contact name + number to `NudgeItem.contactName` + `NudgeItem.actionTarget`
  - `UIViewControllerRepresentable` wrapper for SwiftUI
- [ ] **Wire action buttons into `CardView`:**
  - Show action button only when `item.actionType != nil`
  - Tap 📞: if `actionTarget` exists → open call; else → show contact picker → then open call
  - Tap 💬: if `actionTarget` exists → open message compose; else → show contact picker
  - Tap 🔗: open URL in Safari

### Done When
- [ ] Snooze picker appears with spring animation, all 4 quick options resolve to correct dates
- [ ] Custom date picker works and saves snooze date
- [ ] Tapping 📞 opens Phone app with number
- [ ] Tapping 💬 opens MFMessageComposeViewController with pre-filled recipient
- [ ] Tapping 🔗 opens Safari
- [ ] Contact picker saves selected contact to the card for future use
- [ ] All actions fire appropriate haptics

---

## Phase 9: AI Draft Generation (Pro Feature) ⏱ 1 day
*The "Nudge & Do" magic — AI writes your messages*

### Tasks
- [ ] **`DraftService.swift`:**
  - `generateDraft(for item: NudgeItem) async throws -> Draft`
  - `Draft` struct: `body: String`, `subject: String?` (email only)
  - Uses GPT-4o-mini with exact PRD prompt (task content, action type, contact name, inferred tone)
  - Background pre-fetch: when a card becomes the active One-Thing card, trigger draft generation if actionType is .text or .email and no draft cached
  - Cache draft on `NudgeItem.aiDraft` + `NudgeItem.aiDraftSubject` + `NudgeItem.draftGeneratedAt`
  - Don't regenerate if draft exists and is <24 hours old
  - Offline: skip draft silently — user can still compose manually
  - Pro-only gate: check `AppSettings.isPro` before generating
- [ ] **Draft UI on `CardView`:**
  - Collapsible draft preview below action button (initially collapsed, showing first line)
  - Tap to expand full draft text
  - "Edit" button → opens editable `TextEditor` with draft pre-filled
  - When user taps action button with draft available: pre-fill the compose view with draft body (and subject for email)
  - Free tier: show "Upgrade to Pro for AI-drafted messages" in place of draft
- [ ] **Wire into `MFMessageComposeViewController`:**
  - Pass `item.aiDraft` as `body` parameter
  - Pass `item.actionTarget` as recipient
  - Pass `item.contactName` as display name

### Done When
- [ ] Draft generates in background when actionable card becomes active
- [ ] Draft appears on card with collapsible preview
- [ ] Tapping action button pre-fills compose with draft
- [ ] Edit mode allows modifying draft before sending
- [ ] Free tier shows upgrade prompt instead of draft
- [ ] Offline mode gracefully skips draft (no error shown)

---

## Phase 10: All Items List View ⏱ 1 day
*The escape hatch — for when users need to see everything*

### Tasks
- [ ] **`AllItemsView.swift`:**
  - Black background, scrollable list
  - 3 sections: "Up Next" (active, blue accent markers), "Snoozed" (return time in grey), "Done Today" (strikethrough + green accent)
  - Section headers: sticky with blur backdrop (`.ultraThinMaterial`)
  - Row parallax: subtle 0.5pt vertical offset based on scroll position via `GeometryReader`
  - Stale items: amber accent dot beside row
  - Tap any item → inline edit (text, snooze time, delete)
  - Long-press → context menu: Snooze, Delete, Move to Top
  - Swipe-to-delete with red accent
  - VoiceOver: section names announced, each row reads content + status + age
- [ ] **`ItemRowView.swift`:**
  - Dark card row with accent indicators
  - Emoji + task text + source icon + age
  - Action type badge (📞/💬/🔗) if applicable
  - Done items: strikethrough text + green checkmark

### Done When
- [ ] All 3 sections render with correct items
- [ ] Sticky headers work during scroll
- [ ] Parallax effect is visible but subtle
- [ ] Tap to edit works
- [ ] Long-press context menu works
- [ ] Swipe-to-delete works
- [ ] VoiceOver reads all items with proper labels

---

## Phase 11: Share Extension ⏱ 1.5 days
*Share from any app → save to Nudge*

### Tasks
- [ ] **`NudgeShareExtension/ShareViewController.swift`:**
  - `NSExtensionContext` handler — extract shared content via `NSItemProvider`
  - Support: URLs (`kUTTypeURL`), text (`kUTTypeText`), images (save file URL reference only — don't load into memory)
  - Parse URL metadata (title, favicon) if available via `LPMetadataProvider` (keep lightweight)
  - Write JSON payload to App Group UserDefaults: `{ "content": "...", "url": "...", "preview": "...", "snoozedUntil": "...", "savedAt": "..." }`
  - **Memory budget:** Keep total extension memory under 80MB. Use `NSItemProvider.loadFileRepresentation` for images, never `loadDataRepresentation`
- [ ] **`NudgeShareExtension/ShareView.swift`:**
  - Custom SwiftUI share sheet UI on dark background
  - Content preview (URL title or text snippet)
  - Snooze time picker (same quick options as SnoozePickerView)
  - "Save to Nudge" button (accent blue)
  - On save: penguin thumbs-up micro-animation (0.4s) + "Saved ✓" in green + haptic success
  - Dismiss share sheet after 0.5s delay
  - VoiceOver: announce "Saved to Nudge"
- [ ] **Main app ingestion** (`NudgeRepository.ingestFromShareExtension()`):
  - On app launch + on `applicationDidBecomeActive`: check App Group UserDefaults for new items
  - Parse JSON payloads → create `NudgeItem` objects in SwiftData with `.share` source type
  - Clear UserDefaults after ingestion
  - If app is already running when share happens: use `NSNotification` / polling to detect new items

### Done When
- [ ] Share a URL from Safari → Nudge appears in share sheet → save with snooze time → item appears in app on next launch
- [ ] Share text from Notes → works
- [ ] Penguin thumbs-up animation plays on save
- [ ] Extension memory stays under 80MB (profile in Instruments)
- [ ] Multiple shares before opening app: all items ingested correctly (no data loss)

---

## Phase 12: Notifications System ⏱ 1.5 days
*Gentle nudges that feel human, not robotic*

### Tasks
- [ ] **`NotificationService.swift`:**
  - Request notification permission (on first snooze or first brain dump — not on launch)
  - **Notification categories** with `UNNotificationCategory`:
    - `snoozed-item`: actions — [View] (foreground)
    - `stale-item`: actions — [Do it Now] (foreground), [Drop It] (destructive/background)
    - `actionable-item` (Pro): actions — [📞 Call] (foreground), [💬 Text] (foreground), [⏰ Tomorrow] (destructive/background)
  - **Schedule methods:**
    - `scheduleSnoozeReturn(for item: NudgeItem)` — fire at `snoozedUntil` date
    - `scheduleStaleNudge(for item: NudgeItem)` — fire 3 days after creation if still active
    - `scheduleEndOfDay()` — fire at 5pm if there are remaining active items
  - **Notification templates** — 15–20 pre-written messages with variable slots:
    - Stale: "You've had '{task}' for {days} days. Want to do it now or let it go?"
    - EOD: "It's {time} — you've got {count} thing(s) left. 15-minute sprint?"
    - Snoozed return: "Hey! '{task}' is back. Ready to tackle it?"
  - **Custom notification sound:** Register `nudge-knock.caf` via `UNNotificationSound(named: "nudge-knock.caf")`
  - **Quiet hours:** Don't schedule any notification between `quietHoursStart` and `quietHoursEnd`
  - **Max daily cap:** Track delivered count, stop at `maxDailyNudges`
  - **Notification icon:** Set app icon (penguin) — this happens automatically
- [ ] **Handle notification taps** (`UNUserNotificationCenterDelegate`):
  - Foreground actions: bring app to foreground → route to relevant card → if Call/Text action, immediately open Phone/Messages via `ActionService`
  - Background actions (Snooze/Tomorrow): update `NudgeItem.snoozedUntil` without opening app
  - Default tap: open app to One-Thing View showing the relevant card
- [ ] **Pro-only gating:**
  - Free tier: only snoozed item return notifications
  - Pro tier: stale nudges, EOD nudges, actionable notification buttons

### Done When
- [ ] Snoozed item notification fires at correct time with custom sound
- [ ] Tapping notification opens app to the relevant card
- [ ] "Call Now" action opens Phone app (via app foreground redirect)
- [ ] "Tomorrow" action snoozes without opening app
- [ ] Quiet hours respected — no notifications between 9pm–8am
- [ ] Daily cap enforced — max 3 nudges per day
- [ ] Free tier gets basic notifications only

---

## Phase 13: Live Activity + Dynamic Island (Opt-in) ⏱ 1 day
*Ambient task visibility on Lock Screen — power user feature*

### Tasks
- [ ] **`NudgeLiveActivity.swift`** (in main target using ActivityKit):
  - `NudgeActivityAttributes`: `taskContent: String`, `taskEmoji: String`
  - `NudgeActivityState`: `gradientStripIndex: Int` (0–4 for 5 time-of-day states), `accentColorHex: String`
  - **Dynamic Island (compact):** Task emoji + truncated task name
  - **Dynamic Island (expanded):** Full task text + "Done" button + "Snooze" button
  - **Lock Screen:** Task emoji + full text + thin gradient strip (4pt horizontal bar) showing 5 pre-computed time-of-day colors
  - Gradient strip: 5 states (dawn blue, morning gold, afternoon amber, sunset orange-red, night indigo) — render as colored rectangles, NOT live gradient
- [ ] **Lifecycle management:**
  - Start Live Activity when user enables toggle (or first opt-in prompt)
  - Update when task changes (done/skip/snooze → show next task)
  - Update gradient strip at 5 time-of-day transitions via `BGAppRefreshTask`
  - Auto-restart after 8-hour expiry: schedule `BGAppRefreshTask` to restart at hour 7.5
  - Stop when user disables toggle or no active tasks
- [ ] **Opt-in flow:**
  - Settings toggle: "Show task on Lock Screen" (default OFF)
  - One-time prompt after first brain dump: "Want to see your current task on your Lock Screen?" → Enable / No thanks → never asked again
  - Store preference in `AppSettings.liveActivityEnabled`
- [ ] **Notification integration:**
  - When Live Activity is active, reduce notification frequency (user already sees the task)

### Done When
- [ ] Live Activity appears on lock screen and Dynamic Island when enabled
- [ ] Current task text updates when task changes
- [ ] Gradient strip shows correct time-of-day color
- [ ] 8-hour auto-restart works
- [ ] Opt-in toggle in Settings works
- [ ] One-time prompt shows and is never repeated
- [ ] Live Activity stops when disabled or no tasks

---

## Phase 14: Settings + Free/Pro Tier + StoreKit 2 ⏱ 1.5 days
*Monetization — the engine that makes this sustainable*

### Tasks
- [ ] **`SettingsView.swift`:**
  - Dark background, grouped sections with `DarkCard` style
  - **Nudge Settings:** Quiet hours (time pickers), max nudges per day (stepper), Live Activity toggle
  - **Account:** "Upgrade to Pro" row (accent blue, prominent), restore purchases
  - **About:** Penguin mascot in header (celebrating state), version number, privacy policy link, contact/support email
  - All text localized via `String(localized:)`
  - VoiceOver: all controls properly labeled
- [ ] **`PurchaseService.swift`:**
  - StoreKit 2: `Product.products(for: ["com.nudge.pro.monthly", "com.nudge.pro.yearly"])`
  - Purchase flow: `product.purchase()` → verify transaction → update `AppSettings.isPro`
  - Restore purchases: `Transaction.currentEntitlements` → check for active subscription
  - Handle transaction updates: `Transaction.updates` async stream
  - Expiration handling: if subscription lapses, set `isPro = false`
  - Receipt validation: use StoreKit 2's built-in `JWS` verification (no server needed for MVP)
- [ ] **Paywall screen:**
  - Modal presentation from Settings or when hitting free tier limit
  - Dark background with accent highlights
  - Feature comparison: Free vs Pro (table from PRD)
  - Penguin mascot showing Pro features (special expression)
  - Monthly ($9.99) and Yearly ($59.99, "Save 50%") buttons
  - Restore purchases link at bottom
  - Close/dismiss button (never trap users)
- [ ] **Free tier enforcement:**
  - Brain dumps: check `AppSettings.dailyDumpsUsed` < 3, increment on each dump, show paywall on 4th
  - Saved items: check `AppSettings.savedItemsCount` < 5, show paywall when limit reached
  - AI drafts: check `AppSettings.isPro`, show "Upgrade for AI drafts" inline on card
  - Notification buttons: check `AppSettings.isPro`, show basic notifications for free

### Done When
- [ ] Settings renders all options correctly
- [ ] StoreKit 2 purchase flow works in sandbox
- [ ] Paywall shows on free tier limit hit
- [ ] Pro purchase unlocks all features immediately
- [ ] Restore purchases works for existing subscribers
- [ ] Subscription expiration correctly reverts to free tier

---

## Phase 15: Onboarding ⏱ 0.5 days
*3 screens, skippable, penguin-guided — then get out of the way*

### Tasks
- [ ] **`OnboardingView.swift`:**
  - `TabView` with `PageTabViewStyle`, 3 pages, dark background
  - Spring transitions between pages
  - **Page 1:** Penguin with microphone → "Talk, don't type" → subtitle explaining brain dump
  - **Page 2:** Penguin holding one card → "One thing at a time" → subtitle explaining One-Thing view
  - **Page 3:** Penguin catching a falling link → "Share anything, see it later" → subtitle explaining share-to-snooze
  - "Skip" button (top right, grey text) on every page
  - "Get Started" button (accent blue) on page 3 → dismiss → show One-Thing View (empty state)
  - Page dots in accent blue
  - Animations: penguin in each panel has a subtle entrance animation (slide + fade)
  - VoiceOver: each page reads title + subtitle + page position
- [ ] **First-launch detection:**
  - `@AppStorage("hasCompletedOnboarding") var hasCompleted = false`
  - Show onboarding only when `false`, set to `true` on completion/skip
  - **Don't request permissions here** — request mic on first brain dump, notifications on first snooze

### Done When
- [ ] 3 screens render with penguin + text + animations
- [ ] Swipe between pages with spring physics
- [ ] Skip and Get Started both dismiss and don't show again
- [ ] No permission requests during onboarding
- [ ] VoiceOver navigates all pages

---

## Phase 16: TipKit Integration ⏱ 0.5 days
*Contextual hints that teach features without an instruction manual*

### Tasks
- [ ] **Configure TipKit** in `NudgeApp.swift`:
  - `try? Tips.configure([.displayFrequency(.monthly)])`
- [ ] **Define tips:**
  - `BrainDumpTip`: "Tap the mic to brain dump" — shows on empty One-Thing View
  - `SwipeRightTip`: "Swipe right to complete" — shows on first card interaction
  - `ShareTip`: "Share from any app to save here" — shows after first brain dump
  - `LiveActivityTip`: "Show your current task on your Lock Screen" — shows in Settings near the toggle
- [ ] **Invalidation rules:**
  - `BrainDumpTip` → invalidate after first brain dump
  - `SwipeRightTip` → invalidate after first swipe done
  - `ShareTip` → invalidate after first share extension use
  - `LiveActivityTip` → invalidate after toggle enabled

### Done When
- [ ] Tips appear at correct moments
- [ ] Tips dismiss and don't reappear after action taken
- [ ] Tips respect the monthly display frequency
- [ ] Tips work with VoiceOver

---

## Phase 17: Sound Assets + Animation Polish Pass ⏱ 1 day
*The craft layer — what separates "works" from "feels incredible"*

### Tasks
- [ ] **Create or integrate sound assets:**
  - `brain-dump-start.caf` — bubble pop (0.2s)
  - `task-done.caf` — two-note ascending chime C5→E5 (0.3s)
  - `all-clear.caf` — warm three-note chord C4-E4-G4 (0.5s)
  - `nudge-knock.caf` — gentle double-knock (0.5s)
  - Create in GarageBand/Logic or commission on Fiverr ($100–300)
  - Convert to `.caf` format: `afconvert input.wav output.caf -d aac`
- [ ] **Full animation audit:**
  - Play through every interaction in the app
  - Verify every animation uses spring physics (no default `.easeInOut`)
  - Verify card swipes feel physical — momentum, overshoot, settle
  - Verify all stagger delays are consistent (0.15s)
  - Verify empty state penguin loop is smooth
  - Verify tab bar transitions cross-fade correctly
  - Check Reduce Motion: all springs → instant cross-fades
- [ ] **Micro-interaction polish:**
  - Checkmark particle burst on swipe done (small green dots radiating outward)
  - Brain dump waveform visualization smoothness
  - Snooze picker slide-up spring timing
  - "See you then" text fade timing
  - Card border pulse timing for stale items
- [ ] **Performance check:** Run all animations through Instruments Core Animation on iPhone 12 — all must maintain 60fps

### Done When
- [ ] All 4 sounds play correctly and sound professional
- [ ] Every animation in the app feels physical and polished
- [ ] Zero default `.easeInOut` animations remain
- [ ] Reduce Motion fallbacks work for every animation
- [ ] 60fps maintained on iPhone 12 during all transitions

---

## Phase 18: Accessibility Audit + Performance Profiling + Ship Prep ⏱ 2 days
*The final gate before TestFlight — no shortcuts*

### Day 1: Accessibility + Performance

- [ ] **Accessibility Inspector audit:** Run on every screen. Fix ALL warnings — zero tolerance
- [ ] **Full VoiceOver walkthrough:**
  - Launch → Onboarding (3 pages) → Get Started → Empty state → Brain Dump → Cards appear → Swipe Done → Swipe Snooze → Snooze picker → All Items → Settings → Back
  - Every element must be reachable and labeled
  - Custom actions must work (done/snooze/skip on cards)
  - Penguin states must be announced
- [ ] **Dynamic Type verification:**
  - Test at all 7 sizes: xSmall, Small, Medium (default), Large, xLarge, xxLarge, xxxLarge
  - Cards must not clip text — height should adapt
  - Empty state text must remain readable
  - Snooze picker options must not overlap
- [ ] **Reduce Motion verification:**
  - Toggle in Settings → verify all springs become cross-fades
  - Penguin still blinks but doesn't sway
  - Card swipes still work but without rotation/particles
- [ ] **Bold Text + Increase Contrast + Smart Invert:** Quick visual check on each screen
- [ ] **Instruments — Performance:**
  - Time Profiler: cold launch → interactive < 1 second
  - Core Animation: 60fps on all animations (test on iPhone 12)
  - Allocations: active memory < 50MB during brain dump → card flow
  - Energy: no background drain (test 8-hour background period)
- [ ] **Fix any failures** — this is blocking. No ship until green.

### Day 2: App Store Prep

- [ ] **App Store screenshots:**
  - Capture on: iPhone 15 Pro Max (6.7"), iPhone SE / iPhone 14 (6.1")
  - Screens: One-Thing View (card with action), Brain Dump (waveform), Empty State (penguin), All Items, Share Extension
  - Design frames: device mockup on dark background with accent highlights and tagline text
  - 5–8 screenshots per device size
- [ ] **App preview video (15–30 seconds):**
  - Screen recording: tap mic → speak → penguin thinks → cards appear → swipe done → penguin bounces → share from Safari → notification → empty state
  - Add subtle captions explaining each step
  - Export at App Store required resolution
- [ ] **App Store Connect metadata:**
  - Title: "Nudge — ADHD Brain Dump & Tasks"
  - Subtitle: "One thing at a time. Voice to action."
  - Keywords: "ADHD, brain dump, task manager, ADHD planner, voice tasks, ADHD app, productivity, reminders"
  - Description: Compelling copy speaking to ADHD users (pain → solution → delight)
  - Privacy Nutrition Labels: complete honestly ("Voice data stays on-device", "Task text sent to AI for processing")
  - Category: Productivity
  - Age Rating: 4+ (no objectionable content)
- [ ] **Featuring Nomination draft:**
  - Why Nudge deserves featuring: ADHD mission, penguin character story, technical showcase (SwiftData, ActivityKit, SFSpeechRecognizer, TipKit, @Observable), accessibility commitment, design craft
- [ ] **TestFlight build:**
  - Archive → Upload → Internal testing group
  - Invite 20 waitlist volunteers
  - Include 2–3 VoiceOver users if recruited

### Done When
- [ ] Accessibility Inspector: ZERO warnings on ALL screens
- [ ] VoiceOver: complete flow navigable without sighted assistance
- [ ] Dynamic Type: no clipping or overlap at any size
- [ ] Performance: all budgets met (launch <1s, 60fps, <50MB, no battery drain)
- [ ] Screenshots and preview video ready to upload
- [ ] App Store metadata complete
- [ ] TestFlight build uploaded and distributed

---

## Phase 19: Beta Testing + Bug Fixes ⏱ 3–5 days
*Real users, real feedback, real fixes*

### Tasks
- [ ] **Distribute TestFlight** to 20 beta testers (from email waitlist)
  - Priority: ADHD users, diverse iPhone models (12 → 15 Pro Max), 2–3 VoiceOver users
  - Include TestFlight notes: what to test, known limitations, how to give feedback
- [ ] **Feedback channels:**
  - TestFlight in-app feedback (built-in)
  - Shared Discord/Telegram group for quick communication
  - Google Form for structured feedback
- [ ] **Focus areas for testers:**
  - Brain dump accuracy — does AI splitting produce useful cards?
  - Swipe gestures — do they feel natural?
  - Notification tone and timing — helpful or annoying?
  - Share Extension — does it work from their most-used apps?
  - Overall feel — does the app feel premium?
  - VoiceOver testers: is anything unreachable or mislabeled?
- [ ] **Triage feedback:**
  - P0 (must fix): crashes, data loss, broken core flows
  - P1 (should fix): confusing UX, accessibility gaps, performance issues
  - P2 (nice to fix): polish, wording tweaks, animation timing
  - P3 (later): feature requests → add to roadmap
- [ ] **Fix P0 and P1 issues** — ship updated TestFlight builds
- [ ] **Final performance + accessibility re-test** after fixes

### Done When
- [ ] All P0 issues resolved
- [ ] All P1 issues resolved or deferred with rationale
- [ ] Crash-free rate at 99.8%+ across all TestFlight users
- [ ] At least 10 testers have given explicit "ship it" approval
- [ ] VoiceOver testers confirm full navigability

---

## Phase 20: App Store Submission + Launch ⏱ 1–2 days
*Ship it. Then show the world.*

### Tasks
- [ ] **Final submission checklist:**
  - [ ] Version number: 1.0.0 (build 1)
  - [ ] All screenshots uploaded (6.7" and 6.1" at minimum)
  - [ ] App preview video uploaded
  - [ ] Privacy Nutrition Labels complete
  - [ ] All metadata reviewed (title, subtitle, keywords, description)
  - [ ] Age rating set to 4+
  - [ ] Pricing: Free with In-App Purchases
  - [ ] In-App Purchase products configured (monthly + yearly)
  - [ ] Featuring Nomination submitted
  - [ ] App review notes: explain brain dump flow, mention AI usage for task splitting
- [ ] **Submit for App Store Review**
  - Expected review time: 24–48 hours
  - Have a fix-ready branch in case of rejection
  - Common rejection reasons to pre-check: privacy description accuracy, in-app purchase restore button visible, share extension follows guidelines
- [ ] **Launch day execution** (once approved):
  - [ ] Release to App Store (manual release recommended for coordinated launch)
  - [ ] Product Hunt launch (Tuesday or Wednesday, 12:01am PT)
  - [ ] Reddit posts: r/ADHD, r/adhdwomen, r/productivity, r/iphone, r/apple
  - [ ] Email waitlist: "It's here. You're the first to know."
  - [ ] X/Twitter build-in-public thread: "We shipped. Here's the story."
  - [ ] First TikTok/Reel: screen recording of brain dump → cards → penguin reaction (30–60 seconds)
- [ ] **Post-launch monitoring (first 48 hours):**
  - Watch Xcode Organizer for crash reports
  - Monitor App Store reviews — respond to every single one
  - Track downloads, conversion rate, Day 1 retention
  - Be ready to hotfix if critical issues arise

### Done When
- [ ] App is LIVE on the App Store 🎉
- [ ] Featuring Nomination submitted
- [ ] All launch channels activated
- [ ] First 24 hours: no P0 crashes
- [ ] First review responses written
- [ ] You take a breath. You shipped it.

---

## Timeline Summary

| Phase | Name | Duration | Cumulative |
|---|---|---|---|
| 0 | Pre-Code Decisions | 1 day | Day 1 |
| 1 | Xcode Project Scaffolding | 1 day | Day 2 |
| 2 | Design System | 1.5 days | Day 3–4 |
| 3 | SwiftData Models + Repository | 1 day | Day 5 |
| 4 | Haptic + Sound + Accessibility Services | 0.5 days | Day 5 |
| 5 | Penguin Mascot | 1 day | Day 6 |
| 6 | Brain Dump (Speech + AI) | 2 days | Day 7–8 |
| 7 | One-Thing View (Card Stack + Swipes) | 2 days | Day 9–10 |
| 8 | Snooze Picker + Action Shortcuts | 1 day | Day 11 |
| 9 | AI Draft Generation | 1 day | Day 12 |
| 10 | All Items List View | 1 day | Day 13 |
| 11 | Share Extension | 1.5 days | Day 14–15 |
| 12 | Notifications System | 1.5 days | Day 16–17 |
| 13 | Live Activity + Dynamic Island | 1 day | Day 18 |
| 14 | Settings + Monetization (StoreKit 2) | 1.5 days | Day 19–20 |
| 15 | Onboarding | 0.5 days | Day 20 |
| 16 | TipKit Integration | 0.5 days | Day 21 |
| 17 | Sound Assets + Animation Polish | 1 day | Day 22 |
| 18 | Accessibility Audit + Perf + Ship Prep | 2 days | Day 23–24 |
| 19 | Beta Testing + Bug Fixes | 3–5 days | Day 25–29 |
| 20 | App Store Submission + Launch | 1–2 days | Day 30–31 |

**Total: ~31 working days (6.2 weeks)**

With 2 engineers working in parallel on independent phases (e.g., one on UI while other on services), this compresses to **~4–5 weeks** of calendar time.

---

## Parallel Work Opportunities

These phase pairs can be worked on simultaneously by 2 engineers:

| Engineer A | Engineer B |
|---|---|
| Phase 2 (Design System) | Phase 3 (Data Models) |
| Phase 5 (Penguin Mascot) | Phase 4 (Services: Haptic/Sound/Accessibility) |
| Phase 7 (One-Thing View UI) | Phase 6 (Brain Dump: Speech + AI backend) |
| Phase 8 (Snooze Picker + Actions) | Phase 9 (AI Draft Service) |
| Phase 10 (All Items UI) | Phase 11 (Share Extension) |
| Phase 13 (Live Activity) | Phase 12 (Notifications) |
| Phase 15 (Onboarding) + 16 (TipKit) | Phase 14 (StoreKit + Settings) |
| Phase 17 (Polish) | Phase 18 Day 1 (Accessibility Audit) |

**With full parallelization: ~18–20 working days (4 weeks)**

---

## Git Tagging Strategy

| Tag | After Phase | Meaning |
|---|---|---|
| `v0.1.0-scaffold` | Phase 1 | Project structure ready |
| `v0.2.0-design-system` | Phase 2 | Visual foundation complete |
| `v0.3.0-data-layer` | Phase 4 | Models + Services foundation |
| `v0.4.0-capture` | Phase 6 | Brain dump works end-to-end |
| `v0.5.0-core-loop` | Phase 8 | Full capture → view → act loop |
| `v0.6.0-features-complete` | Phase 13 | All MVP features implemented |
| `v0.7.0-monetization` | Phase 14 | Free/Pro tiers work |
| `v0.8.0-polished` | Phase 17 | Animation + sound polish done |
| `v0.9.0-ship-ready` | Phase 18 | Accessibility + performance passed |
| `v1.0.0-rc1` | Phase 19 | Release candidate after beta |
| `v1.0.0` | Phase 20 | App Store release 🚀 |

---

*Start at Phase 0. Don't skip ahead. Ship quality.*
