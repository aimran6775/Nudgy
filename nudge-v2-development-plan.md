# Nudge v2 — Development Plan

> Post-testing brainstorm → structured roadmap. Ordered by impact × feasibility.

---

## 1. ADHD Retention & Engagement (Critical Path)

### The Problem
ADHD users are notorious for abandoning apps within 72 hours. The current reward system (snowflakes, accessories) provides extrinsic motivation but lacks the **variable-ratio reinforcement** that actually works for dopamine-seeking brains.

### Research-Backed Strategies

**What motivates ADHD users (clinical evidence):**
- **Immediate feedback loops** — ADHD brains respond to NOW rewards, not delayed gratification. Every action must produce instant visible change.
- **Variable-ratio reinforcement** — slot-machine mechanics (random bonus fish, surprise accessories) outperform fixed schedules by 3–5x for engagement.
- **External accountability** — the brain can't self-generate urgency, so Nudgy must BE the external pressure. "I'm waiting for you" > "You should do this."
- **Novelty seeking** — same UI = invisible after 3 days. Nudgy must evolve visually.
- **Hyperfocus channeling** — when ADHD users ARE engaged, they go deep. Body doubling works because it gives the brain a "witness."
- **Streak anxiety (carefully)** — Duolingo-style streaks work BUT missing a day must not be punishing (freeze days, "Nudgy remembers where you left off").

### Implementation Plan

#### 1a. Fish Economy Expansion (Catfish → Swordfish tier system)
Currently: 2 snowflakes/task, 5 bonus for all-clear, accessories cost 5–50.

**New tiered fish reward system:**

| Fish | Earned By | Value | Visual |
|------|-----------|-------|--------|
| 🐟 Minnow | Any task done | 1 | Small silver fish |
| 🐠 Catfish | Action items (call/text/email) completed | 3 | Spotted, whiskers |
| 🐡 Pufferfish | Completing tasks before noon | 2 | Inflated, funny |
| 🦈 Swordfish | Clearing ALL tasks in a day | 10 | Epic, rare animation |
| 🐋 Whale | 7-day streak | 25 | Massive celebration |

**Spending fish:**
- Environment upgrades (Ice Shelf → Fishing Pier → Cozy Camp → Summit Lodge — *already in stages system*)
- Nudgy cosmetics (already have 14 accessories, add more tiers)
- **NEW: Ability unlocks** — 10 fish → custom Nudgy greeting, 50 fish → pick Nudgy's voice, 100 fish → unlock "night mode" Antarctic aurora scene
- **NEW: Fish tank** — visual aquarium on the `.you` tab showing all collected fish species (collection-driven engagement)

**Variable rewards (random bonuses):**
- Random "golden fish" drops (2× value) on ~15% of completions
- "Fishing frenzy" — complete 3 tasks in 30 min = 3× multiplier for next hour
- Lucky catch messages from Nudgy: "Whoa, you caught a rare Swordfish! 🎣"

**Changes needed:**
- Rename `snowflakes` → `fish` throughout `RewardService.swift` and `NudgyWardrobe` model
- Add `FishType` enum to `NudgeItem` (awarded on completion)
- Add variable-ratio multiplier logic to `RewardService.recordCompletion()`
- New `FishTankView` in `Features/You/`
- Extend `NudgyWardrobe` with collected species tracking

#### 1b. Memory of Unfinished Nudges — Smart Resurfacing
Currently: expired snoozes resurface on foreground. No proactive "you left this unfinished" nudging.

**New behavior:**
- Nudgy remembers the last task you were working on (store `lastFocusedItemID` in `AppSettings`)
- On app open: "Welcome back! You were working on [task]. Ready to finish?" with one-tap resume
- After 3+ days stale: "This has been sitting here for a while. Should we break it down, snooze it, or drop it?"
- End-of-day: "You got 4 of 6 done today. Want to push [remaining] to tomorrow morning?"
- Weekly digest: "This week: 23 tasks done, 3 still hanging. You're on a 5-day streak 🔥"

**Changes needed:**
- Add `lastFocusedItemID` and `lastFocusedAt` to `AppSettings`
- New greeting logic in `NudgyEngine.greet()` — check for stale/in-progress items
- New `NudgyDialogueEngine` methods: `staleItemPrompt()`, `endOfDayReview()`, `weeklyDigest()`
- Notification at end-of-day (already have `scheduleEndOfDayPrompt()` — enhance it)

#### 1c. Feeling Progress & Motivation
Currently: Level system exists but progression isn't visible moment-to-moment.

**New micro-progress indicators:**
- **Completion sparkle trail** — each done task leaves a sparkle that builds into a constellation on the Antarctic sky (visual accumulation)
- **Nudgy mood escalation** — Nudgy gets visibly happier through the day: cold → warming → productive → golden (already exists as `EnvironmentMood` — make it more dramatic visually)
- **"You're on fire" moments** — after 3 rapid completions, Nudgy does a special celebration + screen flash
- **Progress ring on `.nudges` tab** — already exists (`DailyProgressHeader`), make it more prominent with animated fill

---

## 2. Chat Reliability & Speed (High Priority)

### Current State Audit
- Chat uses GPT-4o-mini via OpenAI API (not GPT-4o as docs claimed)
- No timeout configuration — relies on URLSession defaults (~60s)
- No retry logic — immediate fallback to Apple Foundation Models or keyword matching
- Streaming is hybrid: tool calls are non-streaming, only final text response streams
- Max 300 tokens per response (very short)

### Fix Plan

#### 2a. Add Proper Failsafes to `NudgyConversationManager`

```
Retry chain (per request):
1. OpenAI GPT-4o-mini (timeout: 8s for first token, 15s total)
   ↓ on failure
2. Retry OpenAI once (with exponential backoff: 1s delay)
   ↓ on failure  
3. Apple Foundation Models (on-device, iOS 26+)
   ↓ on failure / unavailable
4. Keyword-based direct action (already exists)
   ↓ if no match
5. Curated Nudgy response ("I'm having trouble thinking right now, but let's keep going!")
```

**Changes needed in `NudgyConversationManager.swift`:**
- Add `URLSessionConfiguration` with `timeoutIntervalForRequest: 15`
- Add retry wrapper: `withRetry(maxAttempts: 2, backoff: .exponential)` 
- Add circuit breaker: after 3 consecutive failures in 5 min, skip OpenAI for 2 min
- Track latency per request → log to `NudgyMemory` for optimization
- Increase `max_tokens` to 500 for conversational quality

#### 2b. Perceived Speed Improvements
- **Streaming text in speech bubble** — currently shows static "Let me think..." while streaming feeds to `penguinState.streamingText`. Wire streaming text directly into the dialogue bubble with typewriter effect
- **Optimistic UI** — for task creation ("add buy milk"), immediately show the task card appearing while the AI confirms
- **Pre-warm conversation context** — on app foreground, pre-load the system prompt + last 5 messages so first response is faster
- **Parallel TTS** — start speaking the first sentence while still generating the rest (requires sentence-boundary detection in stream)

#### 2c. Conversation Flow Design
```
User taps mic → Nudgy: "Hey! What's on your mind?" (instant, curated)
   → Listening (waveform bars, live transcript)
   → 1.8s silence → auto-send
   → Nudgy thinks (bouncing dots, 0-8s)
   → Nudgy speaks response + auto-resume listening
   → Loop until goodbye detected or 8s empty silence
```

**Failure states that need handling:**
- Mic permission denied → clear message + Settings deep link
- Speech recognition fails → "I couldn't hear that clearly, could you try again?"
- API timeout → "Sorry, I'm being slow today. But I heard you say [transcript]. Want me to save that as a task?"
- Network offline → "I'm offline right now, but I can still save tasks for you!" (use keyword extractor)

---

## 3. Nudgy Mascot — Making It Come Alive (High Impact)

### Current State
- Penguin rendered as SwiftUI bezier paths (ported from Python)
- Sprite sheet animation system built but dormant (`useSpriteArt: false`)
- 12 expressions available but transitions are instant (no morphing)
- No flippers animation, no feet, floating feel
- Artist images exist but no automation pipeline

### Strategy: Hybrid Approach (Achievable Without Rive/Expensive Design)

#### 3a. Immediate: Enhance Bezier Penguin (Keep What Works)

**Add flippers (wings):**
- Current `PenguinMascot` draws static wings as `Path` curves
- Add `@State private var flipperAngle: Double = 0` 
- Idle: gentle ±5° sway (2s period sine wave)
- Excited (task done): rapid ±15° flap (0.3s period, 4 cycles)
- Listening: slight forward lean + wings slightly out
- Celebrating: big flaps + bounce

**Add feet:**
- Two orange oval paths below the body
- Idle: static, grounded
- Walking: alternating forward/back animation
- Celebrating: tiny hop (Y offset animation)

**Better expression transitions:**
- Use `withAnimation(.spring(duration: 0.4))` for expression changes
- Eyes: animated size change (squint → wide) via `scaleEffect`
- Beak: morph between closed/open/smile using `Path` interpolation (SwiftUI `animatablePair`)
- Blush: opacity pulse on happy expressions

**Shading & depth:**
- Add radial gradient overlay on body (lighter center → darker edges)
- Subtle drop shadow under penguin (grounds it)
- Inner glow on belly (warmth)

**Changes needed:**
- Refactor `PenguinMascot.swift` into component views: `PenguinBody`, `PenguinFace`, `PenguinWings`, `PenguinFeet`
- Add animation state machine driven by `PenguinState.expression`
- Wire flipper excitement to `HapticService` events

#### 3b. Medium-term: Frame Animation from Artist Assets

**The pipeline (automated):**

```
Artist PNG (single pose, high-res)
  → Python script: extract layers (body, eyes, beak, wings, feet)
  → Generate 8-12 variant frames per expression:
     - idle: gentle breathing (scale body 98-102%)
     - happy: eyes squint, wings up, slight bounce
     - thinking: eyes look up, wing on chin
     - sleeping: eyes closed, Z's particle
     - etc.
  → Export as numbered PNGs: nudgy-idle-1.png ... nudgy-idle-8.png
  → Drop into Assets.xcassets
  → SpriteAnimator picks them up automatically (system already built!)
```

**To automate this (without manual frame drawing):**

1. **Pillow (Python)** — transform single artist PNG into frame variants:
   - Affine transforms for breathing (slight scale)
   - Eye overlay swap (open → half → closed → squint)
   - Wing rotation via separate layer
   - Beak overlay swap
   
2. **Alternative: Core Animation in-app** — keep the bezier penguin but add `CADisplayLink`-driven micro-animations that make it feel like 12fps sprite animation:
   - Breathing: 3% body scale oscillation
   - Eye blinks: random every 3-8 seconds (0.15s close + 0.15s open)
   - Micro-sway: 1° rotation oscillation  
   - Wing idle: 3° rotation oscillation
   - Combine all = feels alive without sprite sheets

**Recommendation: Option 2 (Core Animation on bezier) is fastest to ship and doesn't need artist involvement.**

#### 3c. Long-term: Finch-Style Companion Feel

What Finch does that Nudgy should match:
- **Contextual idle animations** — not just looping, Nudgy reacts to time of day (yawning at night, stretching in morning)
- **Personality evolution** — Nudgy's default expression shifts based on your streak (happy baseline at 7+ days, neutral at 0)
- **Wardrobe visibility** — equipped accessories must be visible on the penguin (currently emoji placeholders)
- **Interactive responses** — tap = wobble + giggle, long press = hug animation, double tap = high-five, drag = waddle to new position
- **Environmental awareness** — weather API → if it's raining IRL, rain in the Antarctic scene

---

## 4. Onboarding Redesign (30-Second ADHD-Optimized)

### Current Problems
- Two nearly identical flows (IntroView + OnboardingView) — confusing
- No permissions requested during onboarding (deferred to first use = friction)
- No interactive tutorial — purely passive swipe pages
- No Nudgy personality — just text + static penguin
- No voice option

### New Flow (30 seconds target)

```
┌──────────────────────────────────────────────────┐
│ SCREEN 1: "Meet Nudgy" (5 sec)                   │
│                                                    │
│ • Nudgy waddles in from left (animated)            │
│ • Speech bubble: "Hi! I'm Nudgy 🐧"              │
│ • Auto-advances after 3s OR tap to proceed         │
│ • Optional: Nudgy speaks this via TTS              │
│ • Mute button in corner (persists preference)      │
│                                                    │
│ [Skip All →]                                       │
├──────────────────────────────────────────────────┤
│ SCREEN 2: Permissions (8 sec)                     │
│                                                    │
│ • "I work best when I can listen and remind you"   │
│ • Big friendly buttons:                            │
│   🎤 "Let me listen" → mic permission              │
│   🔔 "Let me remind you" → notification permission │
│ • Both show Nudgy reaction on grant/deny           │
│ • Deny = "No worries, you can turn these on later" │
│                                                    │
│ [Skip →]                                           │
├──────────────────────────────────────────────────┤
│ SCREEN 3: Quick Demo (10 sec)                     │
│                                                    │
│ • "Try it! Tell me something you need to do"       │
│ • Pre-filled example if they don't have mic:        │
│   "Call mom, buy groceries, finish report"          │
│ • Shows brain dump → card extraction live           │
│ • Nudgy: "See? That's all it takes! 🎉"           │
│                                                    │
│ [Skip →]                                           │
├──────────────────────────────────────────────────┤
│ SCREEN 4: Sign In + Name (7 sec)                  │
│                                                    │
│ •  Sign in with Apple (one tap)                   │
│ • Name auto-pulled from Apple ID                   │
│ • "Should I call you [firstName]?" with edit        │
│ • If no Apple ID: email option (smaller, secondary) │
│ • Big "Start →" button                             │
│                                                    │
│ Total flow: ~30 seconds                            │
└──────────────────────────────────────────────────┘
```

### Key ADHD Retention Principles Applied:
1. **Immediate value demo** (Screen 3) — user sees the core magic before committing
2. **Minimal decisions** — max 2 choices per screen, clear defaults
3. **Skip everything** — ADHD users hate being trapped; every screen has skip
4. **Nudgy narrates** — voice-over option keeps attention (audio + visual dual channel)
5. **Auto-advance** — don't rely on user to tap; screens progress automatically with generous timing
6. **One sign-in button** — Apple Sign In is fastest; email is secondary (keep it but make it small)

### Changes Needed:
- Replace both `IntroView` and `OnboardingView` with single `OnboardingFlowView`
- Merge intro + auth + onboarding into one continuous flow
- Move Apple Sign In into onboarding flow (currently separate `AuthGateView`)
- Request permissions inline (mic via `SFSpeechRecognizer.requestAuthorization()`, notifications via `UNUserNotificationCenter.requestAuthorization()`)
- Add TTS narration option using `NudgyVoiceOutput`
- Build demo brain dump that works offline (canned responses)

### Improved Dialogue Box
- Current: `PenguinDialogue` with `.speech/.thought/.announcement/.whisper` styles
- **Enhancement:** Typewriter text animation (character by character, 30ms/char)
- Larger font (currently likely `AppTheme.caption` level — bump to `AppTheme.taskTitle`)
- Tail pointer toward Nudgy's beak
- Subtle glass blur background (match existing `ultraThinMaterial`)
- Tap to skip typewriter → show full text instantly
- Queue indicator (dots) when multiple lines pending

---

## 5. Live Activity & Dynamic Island — Push the Limits

### What Apple Allows (Verified Feb 2026)

**Dynamic Island capabilities:**
- ✅ `Button` with `AppIntent` (via `LiveActivityIntent` protocol) — runs in app process
- ✅ `Toggle` with `AppIntent`  
- ✅ Deep link URLs (`widgetURL`, `Link`)
- ✅ Live timer (`Text(.timerInterval:)`)
- ✅ Custom animations on data updates (opacity, move, push, scale transitions)
- ✅ Alert configuration (expanded presentation + sound + haptic on updates)
- ✅ ActivityKit push notifications (remote updates without app running)
- ✅ Transient Live Activities (auto-dismiss on app exit)
- ✅ Long press → expanded view (up to 160pt height)
- ✅ Stale date detection (visual indicator when outdated)
- ❌ No scrolling, no text input, no network access from widget
- ❌ Max 4KB data per update
- ❌ Max 8 hours active
- ❌ No custom background colors in Dynamic Island (always black)

### Enhancement Plan

#### 5a. Interactive Buttons via AppIntent (Replace Deep Links)
Currently: Done/Snooze buttons use `nudge://` deep links → opens app → processes → back to Lock Screen.

**New: `LiveActivityIntent` buttons that execute WITHOUT opening the app:**

```swift
struct MarkDoneIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Mark Done"
    @Parameter(title: "Task ID") var taskID: String
    
    func perform() async throws -> some IntentResult {
        // Runs in app's process (not widget process)
        // Access ModelContainer, mark done, update Live Activity
        return .result()
    }
}
```

Actions to support from Lock Screen/Dynamic Island WITHOUT opening app:
- ✅ Mark Done (Button + `MarkDoneIntent`)
- ✅ Snooze 1hr / Tomorrow (Button + `SnoozeIntent` with parameter)
- ✅ Skip to next (Button + `SkipIntent`)
- ✅ Start voice brain dump (Button → opens app to listening mode, since mic needs foreground)

#### 5b. ActivityKit Push Notifications (Background Updates)
Currently: local-only updates, app must be in foreground.

**Add push-to-update capability:**
- Register for push token on Live Activity start
- Send push from a lightweight server (or use CloudKit push) when:
  - Snoozed item expires (timer-based)
  - End-of-day summary
  - Streak milestone ("7-day streak! 🔥" in Dynamic Island)
- Use `AlertConfiguration` for important updates (lights screen + sound)

**Note:** This requires a push notification server. Options:
- CloudKit subscriptions (free, Apple-native)
- Simple AWS Lambda + SNS (low cost)
- Firebase Cloud Messaging (free tier)

#### 5c. Enhanced Dynamic Island UI

**Compact (always visible):**
- Leading: Nudgy emoji + task emoji
- Trailing: Live timer (existing) + micro progress (e.g., "2/5" in tiny text)

**Expanded (long press):**
- Full task content (2 lines)
- **3 action buttons:** Done ✅ | Snooze 🕐 | Skip ⏭️ (all via `LiveActivityIntent`)
- Mini Nudgy speech bubble: "You got this!" (rotates through encouragement)
- Time-of-day gradient strip (existing)
- Queue position with progress bar (not just "1 of 3")

**Smart updates:**
- Task stale >3 days → accent shifts to amber, Nudgy looks concerned
- Overdue → accent red, "This one needs you!"
- All clear → celebratory state, "All done! 🎉" with Nudgy party emoji

#### 5d. Time-Based Smart Notifications from Live Activity
- Morning: show highest priority task
- Pre-meeting (Calendar integration): "You have a meeting in 15min. Quick: [task]?"
- Evening: "3 tasks left. Finish one before bed?"
- Stale items: "This has been here 3 days. Time to act or drop?"

---

## 6. Voice Reliability — Noise Handling

### Current State
- Using `SFSpeechRecognizer` on-device
- Silence threshold: 1.8s
- Audio mode: `.playAndRecord`, `.default` (no noise cancellation)
- No ambient noise detection

### Improvements

#### 6a. Add AVAudioSession Noise Handling
```swift
// In SpeechService.configureAudioSession()
audioSession.setMode(.voiceChat)  // Enables built-in echo cancellation + noise reduction
// Currently using .default — .voiceChat activates Apple's noise suppression DSP
```

**Warning:** `.voiceChat` mode also applies AGC (Automatic Gain Control). The current code explicitly avoids this. Test thoroughly — if AGC causes issues, use `.measurement` mode with manual noise gate:

```swift
// Manual noise gate: ignore audio below threshold
let noiseFloor: Float = 0.01  // Calibrate based on testing
if rmsLevel < noiseFloor {
    // Treat as silence, don't feed to recognizer
}
```

#### 6b. Ambient Noise Warning
- Before recording starts, sample 0.5s of ambient audio
- If RMS > 0.05: show "It's a bit noisy here — try to find a quieter spot 🤫"
- If RMS > 0.1: suggest text input instead

#### 6c. Confidence-Based Filtering
- `SFSpeechRecognitionResult` includes `.bestTranscription.segments[].confidence`
- Filter out segments with confidence < 0.3 (likely noise)
- Highlight low-confidence words in transcript preview: "Buy milk and [unclear] at the store"

#### 6d. Adaptive Silence Threshold
- Noisy environments: increase silence threshold to 2.5s (noise causes false triggers)
- Quiet environments: decrease to 1.5s (faster interaction)
- User preference: adjustable in Settings (Advanced)

---

## 7. Guided Execution — Adapted to User Behavior

### Concept
When Nudgy presents a task, don't just show the card — guide the user through completing it step by step, adapting to their behavior patterns.

### Implementation

#### 7a. Smart Micro-Steps (Enhance Existing)
Currently: `InlineMicroSteps` exists in Nudges tab but isn't connected to NudgyEngine.

**New flow:**
```
User taps task → Nudgy: "Want me to break this down?"
  → AI generates 2-4 micro-steps
  → Each step is a checkable sub-item
  → Completing all steps = task done
  → Nudgy celebrates each sub-step
```

#### 7b. Behavioral Adaptation
Track in `NudgyMemory`:
- Average time per task type (calls take user 2min, emails take 15min)
- Time-of-day productivity (user completes most tasks 10am-12pm)
- Abandonment patterns (user often snoozes "email" type tasks)

Use this to:
- Suggest best time: "You're usually productive around 10am. Save this for then?"
- Predict snooze: "You've snoozed email tasks 4 times. Want to do it now while I wait?" (body doubling)
- Reorder queue: put tasks matching user's current energy level first

#### 7c. Action Enrichment
When Nudgy extracts "buy X on Amazon":
- Auto-generate Amazon search URL: `https://amazon.com/s?k=X`
- Task card shows "Open Amazon →" action button

When Nudgy extracts "call dentist":
- Contact resolution already works → enhance with appointment context
- "I found Dr. Smith's number. Want me to draft a voicemail script too?"

When bulk brain dump (15+ items):
- Auto-categorize: calls, shopping, work, personal
- Priority sort: urgent → important → nice-to-have
- "You told me 15 things. I organized them into 4 groups. Want to start with the 3 urgent ones?"

---

## 8. Tab Bar & Notification Badges

### Should We Keep the Badge Count?

**Research says: Yes, but adapt it.**
- ADHD users respond to visual urgency signals
- BUT: a badge of "7" creates anxiety and avoidance ("too many, I'll deal with it later" → never opens app)

**Solution: Smart badge behavior:**
- Show badge only for 1-3 items (manageable → motivating)
- At 4+: replace number with a dot (· ) → "there's stuff" without overwhelm
- At 0: show ✓ briefly then remove (celebration micro-moment)
- Configurable in Settings: "Show task count" toggle

### Dynamic Tab Icons
SwiftUI `TabView` with iOS 18+ supports:
- `Tab` with custom `Image` — you can swap images dynamically
- SF Symbols support `.symbolEffect(.bounce)` in tabs

**Enhancement ideas:**
- `.nudgy` tab: Nudgy's expression changes based on state (happy face if all clear, sleepy face at night)
  - Use `Image("PenguinTabHappy")`, `Image("PenguinTabSleepy")` etc. — swap via `penguinState.expression`
- `.nudges` tab: SF Symbol `bell` → `bell.badge` (filled when items) → `checkmark.circle` (all done)
  - Use `.symbolEffect(.bounce)` when new item arrives
- `.you` tab: `person.circle` → `person.circle.fill` when streak active

**Changes needed:**
- Add 3-4 PenguinTab variants to Assets.xcassets
- Dynamic tab image selection in `ContentView` based on `penguinState` and active count
- Store badge display preference in `AppSettings`

---

## 9. Event Logging & Personalization Data

### Start with Structured Event Logging (Not Full CloudKit Ontology)

**Why:** A full ontology in CloudKit is complex, fragile, and premature. Start with structured local event logging that can later feed into CloudKit if needed.

**Event types to log:**

```swift
struct NudgeEvent: Codable {
    let id: UUID
    let timestamp: Date
    let type: EventType
    let metadata: [String: String]
    
    enum EventType: String, Codable {
        case taskCreated, taskCompleted, taskSnoozed, taskDropped, taskSkipped
        case brainDumpStarted, brainDumpCompleted
        case appOpened, appBackgrounded
        case chatMessageSent, chatMessageReceived
        case streakMilestone, levelUp
        case nudgyInteraction  // taps, long-press, etc.
    }
}
```

**Storage:** Append-only JSON file in App Group (lightweight, no SwiftData overhead). Rotate monthly.

**Use for personalization:**
- Compute user patterns: best productivity hours, average tasks/day, common snooze times
- Feed summary to `NudgyEngine` system prompt: "User typically completes 4 tasks/day, most active 9-11am, tends to snooze phone calls"
- Power "weekly insights" in `.you` tab
- Eventually sync aggregated stats (not raw events) via CloudKit for cross-device consistency

**Do NOT build:**
- Full relational ontology in CloudKit (over-engineering at this stage)
- Real-time streaming analytics (unnecessary complexity)
- External analytics SDK (privacy-first — everything stays on-device)

---

## 10. Integration Expansion

### Already Working Well
- ✅ Phone calls (`tel:` URL)
- ✅ SMS (`MFMessageComposeViewController` with body prefill)
- ✅ Email (`mailto:` URL)
- ✅ Links (`SFSafariViewController`)
- ✅ Contact resolution (CNContactStore)

### Expand To
- **Calendar:** `EventKit` — check user's calendar before suggesting task timing
- **Reminders:** `EventKit` — two-way sync with Apple Reminders (import existing tasks, export Nudge tasks)
- **Maps/Directions:** When task mentions a place → `MKLocalSearch` → "Open in Maps" button
- **Shortcuts/Siri:** `AppIntents` for "Hey Siri, add a nudge: buy milk"
- **Focus modes:** detect active Focus → suppress notifications if "Do Not Disturb" / "Sleep"
- **Share to Nudge improvements:** current Share Extension is solid, add:
  - Safari web page → auto-extract title + summary
  - Photos → OCR text extraction (`VNRecognizeTextRequest`)
  - Voice memos → transcription

---

## Priority Matrix

| # | Item | Impact | Effort | Ship Target |
|---|------|--------|--------|-------------|
| 4 | Onboarding redesign | 🔴 Critical | Medium | Week 1-2 |
| 2 | Chat reliability + failsafes | 🔴 Critical | Medium | Week 1-2 |
| 3a | Bezier penguin enhancements | 🟡 High | Low | Week 2-3 |
| 1b | Smart resurfacing | 🟡 High | Low | Week 2-3 |
| 6 | Voice noise handling | 🟡 High | Low | Week 2 |
| 8 | Tab bar smart badges | 🟢 Medium | Low | Week 3 |
| 1a | Fish economy expansion | 🟡 High | Medium | Week 3-4 |
| 5a | Live Activity AppIntents | 🟡 High | Medium | Week 4-5 |
| 1c | Progress visualization | 🟢 Medium | Medium | Week 4-5 |
| 9 | Event logging | 🟢 Medium | Low | Week 4 |
| 7 | Guided execution | 🟢 Medium | High | Week 5-6 |
| 3b | Sprite animation pipeline | 🟢 Medium | High | Week 6-8 |
| 5b | Push notifications for LA | 🟢 Medium | High | Week 7-8 |
| 10 | Integration expansion | 🟢 Medium | High | Ongoing |
| 5d | Time-based smart notifs | 🟢 Medium | Medium | Week 6 |
| 3c | Finch-level companion | 🔵 Future | Very High | v3 |

---

## Questions to Resolve

1. **Fish vs Snowflakes naming** — `RewardService` calls them snowflakes, UI apparently calls them fish. Which name ships? (Recommendation: 🐟 fish — more tangible, feeds Nudgy)
2. **Email auth** — do we keep it? It's local-only (SHA-256 hash in Keychain). Apple Sign In is simpler. Recommendation: keep as secondary but deprioritize.
3. **OpenAI dependency** — GPT-4o-mini is the primary LLM. Apple Foundation Models is iOS 26+ only. What's the fallback plan for iOS 17-25 users without an OpenAI key? The keyword extractor is very basic.
4. **Artist assets** — you mentioned sharing images from your artist. To automate the pipeline, I need: (a) a single high-res PNG with separate layers (body, eyes, beak, wings, feet) exported individually, or (b) a Figma/Sketch file with named layers. Which format are the artist assets in?
5. **Server for push notifications** — Live Activity push updates need a server. Is CloudKit push subscriptions acceptable, or do you want a dedicated backend?
