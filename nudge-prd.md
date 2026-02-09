# Nudge — Product Requirements Document

> **Version:** 2.1
> **Date:** February 7, 2026
> **Status:** Pre-MVP — Final PRD, ready for development
> **Platform:** iOS 17+ (iPhone) — Native Swift + SwiftUI — Zero third-party UI dependencies
> **Team:** 2 engineers, no external dependencies
> **Design Language:** Dark UI — pure black canvas, dynamic accent colors, penguin mascot
> **Quality Bar:** Apple Editor's Choice candidate — built to Apple Design Award standards. Every pixel, animation, haptic, and interaction must feel like it shipped from Cupertino. No shortcuts, no "good enough."

---

## 1. One-Liner

**Nudge is a single-screen daily cockpit that captures, organizes, and resurfaces your tasks — then helps you *do* them — built for brains that don't work with traditional to-do apps.**

---

## 2. The Problem (Why This Exists)

### Who has this problem?
- **Primary:** Adults with ADHD (diagnosed or undiagnosed) — estimated 366M globally, 10M+ in the US alone
- **Secondary:** Overwhelmed professionals, anxious overthinkers, anyone who describes themselves as "scattered"

### What's broken today?
| Pain Point | Current "Solution" | Why It Fails |
|---|---|---|
| Thoughts vanish in seconds | Notes app, Reminders | Too many taps to capture — by the time you open the app, you forgot why |
| Interesting links/content disappear | Bookmarks, "Save for later" | Saved and never seen again. No resurfacing mechanism |
| Long task lists cause paralysis | Todoist, Things 3, TickTick | Seeing 30 items = doing 0 items. Lists punish the ADHD brain |
| Can't feel time passing | Clock, calendar alerts | Knowing it's 3pm ≠ *feeling* that 3pm means only 2 hours left. Time blindness is visceral. No ambient cue exists |
| Reminder fatigue | Phone alarms, notification spam | Aggressive buzzing → user disables all notifications → back to square one |

### Evidence from research
- r/ADHD is the **#1 highest-signal subreddit** for app demand (from 9,300-post analysis)
- Education/Self-improvement = **#1 willingness-to-pay** category
- ADHD users write **full spec sheets** in their complaint posts — they know exactly what they want and nobody's built it
- Reddit user request with 12 upvotes: *"snooze anything via the share button"* — this became our killer feature

---

## 3. Product Vision

### What Nudge IS
- A **capture tool** — get thoughts out of your head in under 5 seconds
- A **resurfacing engine** — saved things come back to you at the right time
- A **one-at-a-time task viewer** — anti-list, anti-overwhelm
- A **time awareness layer** — ambient, gentle, always-on sense of time passing through subtle accent color shifts
- A **personal action assistant** — doesn't just remind you, it drafts the message, dials the number, and opens the link. You just confirm
- A **companion, not a tool** — a friendly penguin mascot that makes productivity feel warm, not clinical

### What Nudge is NOT
- ❌ Not a calendar (no event scheduling, no invites)
- ❌ Not a project management tool (no boards, no columns, no assignments)
- ❌ Not a habit tracker (no streaks, no graphs, no guilt)
- ❌ Not a notes app (no rich text, no folders, no organization)
- ❌ Not a social platform (no sharing, no friends, no feeds)
- ❌ Not an ADHD diagnostic or medical tool

### Design Principles
1. **5-second capture** — If it takes longer than 5 seconds to get a thought into Nudge, the design has failed
2. **One thing at a time** — Never show a list when you can show a single card
3. **Gentle, not aggressive** — Nudge *asks*, it doesn't *demand*. A kind friend, not a drill sergeant
4. **Zero configuration** — Works beautifully with zero setup. No onboarding wizard, no category creation, no "getting started" checklist
5. **Offline-first** — Every feature works without internet. Sync is a bonus, not a requirement
6. **Dark, alive, never boring** — Pure black OLED canvas. Cards are dark translucent surfaces with subtle borders. Color enters through a **dynamic accent system** — blue, green, amber, red — that reflects task status, not decoration. The UI feels like a premium instrument panel: calm, focused, purposeful
7. **The penguin is the personality** — A stylized, original penguin mascot is Nudge's soul. It appears in empty states, onboarding, notifications, and idle moments. The penguin is warm, slightly clumsy, and always encouraging — embodying "doing your best, one waddle at a time." NOT a copy of any real penguin (Pesto, etc.) — an original character designed for dark UI with minimal line art

### Design System

| Token | Value | Usage |
|---|---|---|
| **Canvas** | `#000000` (true black) | App background — OLED power savings, zero distraction |
| **Card Surface** | `#1C1C1E` at 80% opacity + 0.5px `#2C2C2E` border | Task cards, sheets, overlays — dark translucent, layered feel |
| **Text Primary** | `#FFFFFF` (white) | Task titles, action labels, headings |
| **Text Secondary** | `#8E8E93` (system grey) | Timestamps, metadata, hints, counts |
| **Text Tertiary** | `#636366` (dark grey) | Disabled states, ultra-subtle labels |
| **Accent — Active** | `#007AFF` (iOS system blue) | Task ready for action, interactive elements, brain dump button |
| **Accent — Complete** | `#30D158` (iOS system green) | Done state, empty state glow, success feedback |
| **Accent — Stale** | `#FF9F0A` (iOS system amber) | Item aging 3+ days, needs attention |
| **Accent — Overdue** | `#FF453A` (iOS system red) | Urgent items, gentle pulse animation |
| **Mascot palette** | White + grey + accent tints | Penguin line art adapts accent color based on context |
| **Typography** | SF Pro (system) | Display weight for headings, Regular for body, Rounded for mascot UI |
| **Card material** | `.ultraThinMaterial` on `#000` | Dark frosted glass — subtle depth without the old gradient dependency |
| **Accent application** | Thin borders, icon tints, subtle glows | NOT backgrounds. Color is a *signal*, not a *fill*. Think single-pixel borders, soft shadows with accent hue, icon color |

#### Time-Aware Accent Temperature (Subtle)
The accent blue subtly shifts temperature through the day — **cool blue in the morning → teal at midday → warmer blue-purple in the evening**. This is NOT the old time-gradient — the background stays black always. The shift affects only the primary accent hue and is intentionally subtle enough that users feel it subconsciously rather than notice it consciously. Implementation: interpolate accent hue based on hour of day, ±15° on the color wheel from base `#007AFF`.

#### Penguin Mascot Specification
| Attribute | Detail |
|---|---|
| **Style** | Minimal line art / geometric — think Duolingo's owl simplicity, not realistic illustration |
| **Body** | Small, round, slightly oversized for its feet — inherently cute and clumsy |
| **Palette** | White body + dark accents, with the current accent color as a subtle tint (scarf, belly glow, eye highlight) |
| **Expressions** | 5-6 states: neutral (idle), happy (task done), sleepy (empty state), encouraging (stale item), celebrating (all clear), thinking (brain dump processing) |
| **Appears in** | App icon (silhouette on black), onboarding (3 panels), empty state ("Your penguin is happy!"), notification avatar, brain dump processing (thinking animation), idle One-Thing View (subtle breathing/blinking), settings header |
| **Animation** | Subtle idle: slow blink every ~8 seconds, gentle body sway. On task done: quick happy bounce. On empty state: sits contentedly with closed eyes |
| **Copyright** | 100% original character. NOT based on Pesto, Pudgy Penguins, or any existing IP. Designed in-house or commissioned. Simple enough to render as SF Symbol-weight line art |
| **Name** | The penguin is unnamed in the app — users may name it themselves. Internally referred to as "the Nudge penguin" or "Nudgy" for dev reference |

### 🏆 Apple Editor's Choice — How We Get There

Apple's featuring team evaluates apps on **6 explicit criteria**. Here's how Nudge maps to each one, and what we must nail:

| Apple Criteria | What Apple Looks For | How Nudge Delivers | Implementation Detail |
|---|---|---|---|
| **User Experience** | Cohesive, efficient, valuable functionality that's helpful and easy to use | The entire app is ONE screen. 5-second capture. Swipe to act. Zero learning curve. The simplest productivity app on the App Store | Every interaction must complete in ≤2 taps. No dead-ends. No loading spinners visible to users (use skeleton states). Instant response to every touch |
| **UI Design** | Beautiful visuals, intuitive gestures, overall quality | Dark OLED canvas, translucent cards, accent color system, penguin mascot with personality. Custom SwiftUI animations on every state transition | Every transition must use spring animations (`interpolatingSpring`). Cards must feel physical — momentum, overshoot, settle. No default `.easeInOut` anywhere. Every view must be pixel-audited at 1x, 2x, 3x |
| **Innovation** | New technologies solving unique problems | Voice-to-task AI splitting, AI-drafted messages, share-to-snooze from any app, time-aware accent system, Live Activity with gradient strip | Use latest iOS 17+ APIs: `@Observable`, SwiftData, `ActivityKit`, `TipKit` (for contextual hints), `SFSpeechRecognizer` on-device. Showcase Apple's own frameworks |
| **Uniqueness** | Fresh approach that stands out from the crowd | No productivity app combines: voice brain dump + one-thing view + share-to-snooze + AI message drafting + penguin companion. Category-defining | The penguin mascot alone differentiates us from every sterile task app. "Anti-productivity for ADHD brains" is a positioning no competitor owns |
| **Accessibility** | Great experience for a broad range of users | Full VoiceOver support, Dynamic Type on every screen, reduced motion alternatives, high-contrast mode, haptic feedback for all interactions | Ship with **zero** accessibility warnings in Xcode Accessibility Inspector. Test with VoiceOver on every screen before release. Support all 7 Dynamic Type sizes. Provide `.accessibilityLabel` on every custom view |
| **Localization** | High-quality multi-language support | English for MVP, but architecture must support localization from Day 1. All strings in `Localizable.strings`, no hardcoded text anywhere. RTL layout support via SwiftUI's automatic mirroring | Use `String(localized:)` for every user-facing string. Date/time formatting via `Date.FormatStyle` (auto-localizes). Prepare for 5 languages by v1.1: English, Spanish, French, German, Japanese |

#### Additional Apple Polish Signals
- **App Store Product Page:** Stunning screenshots with actual device frames (not flat mockups). App preview video (15-30 seconds) showing the brain dump → card flow + penguin reactions. Compelling subtitle and description that speaks to ADHD users
- **Privacy Nutrition Labels:** Complete and honest. Highlight: "No data collected" for most categories. Voice stays on-device. Only transcripts (anonymized) sent to AI
- **App Thinning + On-Demand Resources:** Keep initial download under 30MB. Penguin animation assets loaded efficiently
- **Crash-free rate:** Target **99.8%+** from Day 1. Zero tolerance for crashes in production
- **Launch time:** Cold start to interactive in **<1 second**. Use `@MainActor` sparingly, lazy-load services
- **Memory footprint:** <50MB in active use. Profile with Instruments before every release
- **Featuring Nomination:** Submit a Featuring Nomination via App Store Connect 3 months before target featuring date. Include penguin character story, ADHD mission angle, and technical showcase (SwiftData + ActivityKit + SFSpeechRecognizer)

### Motion & Animation Design System

Every interaction in Nudge must feel *physical* — cards have weight, buttons have feedback, transitions have purpose. No animation exists for decoration; every one communicates state.

| Interaction | Animation | Spec | Purpose |
|---|---|---|---|
| **Card swipe right (Done)** | Card flies right with rotation + momentum → border flashes green → checkmark particle burst → next card slides in from bottom with spring | `interpolatingSpring(stiffness: 200, damping: 18)`. Rotation: 15° max. Green flash: 0.15s. Next card delay: 0.2s | Celebrates completion. Feels satisfying and earned |
| **Card swipe left (Snooze)** | Card drifts left slowly → fades to 50% → "See you later" text appears → time picker slides up from bottom | `spring(response: 0.5, dampingFraction: 0.8)`. Card stays partially visible behind picker | Snoozing is gentle, not dismissive |
| **Card swipe down (Skip)** | Card drops below viewport with gravity feel → next card slides in from top | `interpolatingSpring(stiffness: 150, damping: 20)`. Slight vertical overshoot | Skipping is quick and weightless |
| **Brain dump: mic tap** | Button scales to 1.15x with haptic → accent glow ring pulses → waveform appears | Scale: `scaleEffect` 1.0 → 1.15 → 1.0 over 0.3s. Ring: continuous 2s pulse at 30% opacity | Starting a dump feels momentous |
| **Brain dump: processing** | Penguin "thinking" animation: tilted head, bouncing thought dots → cards materialize one by one with staggered slide-in | Stagger delay: 0.15s between cards. Each card: `offset(y: 50)` → `offset(y: 0)` + `opacity(0 → 1)` over 0.4s | AI processing feels alive, not loading |
| **Task done: penguin reaction** | Quick happy bounce: penguin jumps up 8pt → lands with squash/stretch → eyes become crescents briefly | Total duration: 0.6s. Overshoot on landing. Eyes animate over 0.3s | Emotional reward. The penguin celebrates *with* you |
| **Empty state: penguin idle** | Penguin sits contentedly. Slow blink every 8s. Gentle body sway (±2pt horizontal) on a 6s loop | Blink: eyes close over 0.15s, stay closed 0.2s, open over 0.15s. Sway: `sin(time) * 2` | The screen is never dead. Always alive |
| **Card age: stale pulse** | Amber border gently pulses (0.5px → 1px → 0.5px) on a 3s loop. Subtle, not alarming | Opacity: 0.6 → 1.0 → 0.6. Border width: 0.5 → 1.0 → 0.5. `Animation.easeInOut(duration: 1.5).repeatForever()` | Draws gentle attention without stress |
| **Notification action → app opens** | App launch: card immediately visible (no splash delay). If redirecting to Phone/Messages, subtle fade transition (0.2s) | Use `UIApplication.shared.open` after 0.1s delay to let the app settle | Seamless handoff. App appears for <0.3s |
| **Share Extension: saved** | Penguin thumbs-up micro-animation (0.4s) + "Saved ✓" text with green accent + haptic success | Thumbs-up: penguin arm raises over 0.2s, holds 0.1s, lowers 0.1s | Confirms the save with personality |
| **Scroll (All Items)** | Rubber-band scrolling (native). Section headers stick with blur backdrop. Row cards have subtle parallax on scroll (0.5pt vertical offset based on scroll position) | Use `.scrollTargetLayout()` + native elasticity. Parallax: `GeometryReader` + scroll offset | List feels layered and premium, not flat |
| **Tab bar transitions** | Cross-fade between views (0.25s). Active tab icon tints to accent blue. Inactive: grey | `.animation(.easeOut(duration: 0.25))` on tab change. Use `symbolEffect(.bounce)` on active icon | Navigation feels crisp. Zero jank |

#### Animation Principles
1. **Springs, not curves.** Use `interpolatingSpring` for all physical motions. Never `linear`. Use `.easeOut` only for opacity fades
2. **60fps or nothing.** Every animation must run at 60fps on iPhone 12 (our minimum viable device). Profile with Instruments Core Animation tool
3. **Interruptible.** All gesture-driven animations must be interruptible — if user swipes halfway and reverses, the card must follow the finger, not jump
4. **Reduced Motion.** When `UIAccessibility.isReduceMotionEnabled`, replace all springs with instant cross-fades (0.2s `opacity`). Skip bounces, particles, and parallax. Penguin still blinks but doesn't sway

### Haptic Design System

Haptics are the invisible layer that makes Nudge feel premium. Every meaningful interaction has a corresponding haptic.

| Interaction | Haptic Type | UIKit API | Feel |
|---|---|---|---|
| **Swipe Done** | `.success` notification | `UINotificationFeedbackGenerator().notificationOccurred(.success)` | Satisfying "done" thud |
| **Swipe Snooze** | `.warning` notification | `UINotificationFeedbackGenerator().notificationOccurred(.warning)` | Soft caution — "are you sure?" |
| **Swipe Skip** | `.light` impact | `UIImpactFeedbackGenerator(style: .light).impactOccurred()` | Quick, weightless tap |
| **Mic tap (start recording)** | `.medium` impact | `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` | Firm press to start |
| **Mic tap (stop recording)** | `.soft` impact | `UIImpactFeedbackGenerator(style: .soft).impactOccurred()` | Gentle release |
| **Card appears** | `.light` impact | `UIImpactFeedbackGenerator(style: .light).impactOccurred()` | Subtle arrival |
| **Snooze time selected** | `.selection` changed | `UISelectionFeedbackGenerator().selectionChanged()` | Picker tick |
| **Share saved** | `.success` notification | `UINotificationFeedbackGenerator().notificationOccurred(.success)` | Confirmed |
| **Action button tap** | `.medium` impact | `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` | Intentional press |
| **Error / limit hit** | `.error` notification | `UINotificationFeedbackGenerator().notificationOccurred(.error)` | Something's wrong |

### Sound Design

| Event | Sound | Spec | Notes |
|---|---|---|---|
| **Brain dump start** | Soft "pop" — like a bubble appearing | 0.2s, 2kHz sine with fast decay, subtle reverb | Only plays if device is not silent |
| **Task done** | Gentle chime — two ascending notes (C5 → E5) | 0.3s total, piano-like timbre, no sustain | Satisfying without being obnoxious. Respects Silent Mode via `AudioServicesPlaySystemSound` |
| **All tasks clear** | Warm three-note chord (C4-E4-G4) with slight shimmer | 0.5s, soft pad timbre | Only plays on the empty state arrival |
| **Notification nudge** | Custom notification sound — gentle "knock knock" pattern | Two soft taps separated by 0.15s. Total: 0.5s. Must be registered as `UNNotificationSound(named:)` | Distinct from all default iOS sounds. Reinforces brand |
| **Silent Mode behavior** | All sounds respect `AVAudioSession.sharedInstance().isOtherAudioPlaying` and the hardware silent switch. Haptics ALWAYS play (unless user disabled in iOS settings) | Check `ringer` state before playing audio | Never annoy. Haptics are the primary feedback; sound is a bonus |

---

## 4. MVP Feature Set (v1.0)

### ✅ IN — The 7 Core Features

#### Feature 1: Voice Brain Dump
| Attribute | Detail |
|---|---|
| **What** | Tap one big button → speak freely → AI splits your ramble into discrete task cards |
| **Example input** | *"I need to call the dentist, reply to Sarah about Saturday, buy dog food, and read that article Jake sent"* |
| **Example output** | 4 separate cards: "Call dentist", "Reply to Sarah — Saturday", "Buy dog food", "Read Jake's article" |
| **Tech** | On-device `SFSpeechRecognizer` (Apple Speech framework, `requiresOnDeviceRecognition = true`) → GPT-4o-mini / Claude Haiku for splitting (~$0.001/dump). **Limitation:** Apple enforces a ~1-minute limit on server-based recognition; on-device mode reportedly allows longer sessions but is undocumented. **Workaround:** Cap recording at 55 seconds with a visual countdown. Most brain dumps are 15-30 seconds anyway. If user is still talking at 55s, auto-stop, process what we have, and allow a second dump immediately |
| **Free tier limit** | 3 brain dumps per day |
| **Pro tier** | Unlimited |
| **Edge cases** | Empty recording → ignore. Single item → create 1 card, no AI call needed. No internet → save raw transcript, split later |

#### Feature 2: Share-to-Nudge (Snooze Anything)
| Attribute | Detail |
|---|---|
| **What** | From ANY app, tap Share → Nudge → pick when to be reminded → done in 2 taps |
| **Supported content** | URLs, text snippets, images, tweets, Instagram posts, emails — anything the OS share sheet supports |
| **Time options** | "Later today", "Tomorrow morning", "This weekend", "Next week", Custom date/time |
| **What happens** | Item saved as a card. At the chosen time, a notification appears with the content preview and a "View" button |
| **Tech** | Native iOS Share Extension (`NSExtensionContext`). Custom SwiftUI view in the share sheet. **Data handoff via App Group UserDefaults** (NOT direct SwiftData write — Share Extension and main app are separate processes; concurrent SwiftData writes risk SQLite corruption). Extension writes a lightweight JSON payload to `UserDefaults(suiteName: "group.nudge")`, main app ingests into SwiftData on next launch or via `NSNotification` if running. Share Extension memory limit is ~120MB — keep UI minimal, avoid loading large attachments into memory |
| **Free tier limit** | 5 saved items |
| **Pro tier** | Unlimited |

#### Feature 3: One-Thing Daily View
| Attribute | Detail |
|---|---|
| **What** | When you open the app, you see ONE task card — full screen, large text, no distractions |
| **Interactions** | **Done** (mark complete, next card slides in), **Skip** (push to end of queue, next card), **Snooze** (pick new time, card disappears until then) |
| **Ordering logic** | Items with specific due times first → overdue items → most recently added → shared/snoozed items approaching their time |
| **Empty state** | When all tasks done: celebratory micro-animation + message: *"Your brain is clear. Go enjoy something."* |
| **Swipe gestures** | Swipe right = Done, Swipe left = Snooze, Swipe down = Skip |
| **Tech** | SwiftUI card stack with `DragGesture`. Dark translucent card (`#1C1C1E` at 80% + `.ultraThinMaterial` + `RoundedRectangle` + 0.5px accent-colored border based on task status). Accent color on the card border signals task state: blue (active), amber (stale 3+ days), red (overdue). Subtle penguin mascot visible in idle state — small, breathing/blinking in the corner below the card. SwiftData for state |

#### Feature 4: Dynamic Status Accents + Time-Aware Tinting
| Attribute | Detail |
|---|---|
| **What** | The app uses a **dynamic accent color system** that communicates task status at a glance AND subtly shifts temperature through the day to combat time-blindness. The background is always pure black — color lives in borders, icons, glows, and the mascot's tint |
| **Status accent colors** | 🔵 Blue (`#007AFF`) = active, ready to act · 🟢 Green (`#30D158`) = completed / all clear · 🟠 Amber (`#FF9F0A`) = stale (3+ days untouched) · 🔴 Red (`#FF453A`) = overdue, gentle pulse. Applied to: card borders (0.5px), action button tints, penguin's accent tint, notification category colors |
| **Time-aware hue shift** | The base blue accent subtly shifts throughout the day — cool blue-cyan in morning → neutral blue at midday → warmer blue-indigo in evening. Shift range: ±15° on the color wheel from `#007AFF`. Effect is subconscious — you *feel* it's evening, you don't *see* the color change. Background stays pure `#000` always |
| **Subtlety** | The hue shift is SLOW and affects ONLY the blue accent. Green/amber/red status colors remain fixed. Users should not consciously notice the shift, but over days of use, they'll develop a feel for "morning blue" vs "evening blue" |
| **Customization** | None in MVP. Single accent palette. Keep it simple |
| **Tech** | SwiftUI `TimelineView(.periodic(from: .now, by: 300))` — updates accent hue every 5 minutes (no need for per-minute gradient rendering). `Color(hue: baseHue + timeOffset, saturation: 0.85, brightness: 1.0)` where `timeOffset` is interpolated from a 24-hour sine curve (±0.04 in hue space). Status colors are static `Color` constants. Card borders use `.stroke(accentColor, lineWidth: 0.5)`. Penguin tint uses `.colorMultiply(accentColor)` on the mascot asset |

#### Feature 4b: Live Activity — Time Strip + Current Task (Opt-in)
| Attribute | Detail |
|---|---|
| **What** | An **opt-in** Live Activity on the Dynamic Island and lock screen showing: current task name + a compact time-awareness gradient strip. This is the ONLY place the classic gradient (dawn blue → amber → sunset → indigo) appears — as a thin horizontal progress bar representing the day |
| **Opt-in, not default** | Live Activities can feel invasive — always on the lock screen, always on the Dynamic Island. **Not everyone wants this.** Enabled via Settings toggle: "Show task on Lock Screen" (default: OFF). On first brain dump, a one-time prompt: *"Want to see your current task on your Lock Screen?"* — user can enable or dismiss, never asked again |
| **What it shows** | **Dynamic Island (compact):** Task name truncated + small colored dot (accent color). **Expanded:** Full task text + action button + snooze. **Lock Screen:** Task name + thin gradient strip (5 pre-computed time-of-day colors) + penguin icon |
| **Gradient strip** | A thin (4pt) horizontal bar below the task name that shifts through 5 pre-computed states: dawn blue → morning gold → afternoon amber → sunset orange-red → night indigo. This is a simple image swap, NOT a live-rendered gradient |
| **Tech** | ActivityKit + `Live Activities`. **⚠️ Limitations:** (1) 8-hour max lifetime — auto-restart via `BGAppRefreshTask`. (2) Cannot self-update; push updates via background task at 5 time transitions (~every 2-3 hours). (3) ~4KB payload limit — task name + gradient state index only. Add `NSSupportsLiveActivitiesFrequentUpdates = YES` to Info.plist. Task changes pushed immediately when user completes/skips/snoozes in-app |
| **Why opt-in** | Many ADHD users have anxiety about persistent reminders. Seeing "Call dentist" on their lock screen all day could be *counterproductive*. The Live Activity is a power-user feature for people who explicitly want ambient visibility. Default OFF respects diverse ADHD experiences |

#### Feature 5: Gentle Nudge Notifications
| Attribute | Detail |
|---|---|
| **What** | Smart, conversational reminders that feel human, not robotic |
| **Tone examples** | *"You've had 'call dentist' for 3 days. Want to do it now or let it go?"* · *"You saved 4 links this week but haven't opened any. Couch reading tonight?"* · *"It's 4pm — you've got one big thing left. 15-minute sprint?"* — All notifications display the penguin mascot as the notification icon, reinforcing brand personality |
| **Frequency** | Max 3 nudges per day. Never after 9pm. Never before 8am |
| **Notification types** | (1) Snoozed item resurfacing, (2) Stale item check-in (3+ days old), (3) End-of-day "one thing left" prompt |
| **Actionable notifications** | Every nudge notification includes **tap-to-act buttons** in the notification banner (native `UNNotificationAction` + `UNNotificationCategory`). For a "Call dentist" nudge: **[ 📞 Call Now ] · [ 💬 Send Text ] · [ ⏰ Tomorrow ]**. **⚠️ iOS routing:** action buttons **always route through the app first** — they cannot directly launch `tel:` or `sms:` from the notification. Implementation: use `UNNotificationAction(options: [.foreground])` which brings the app to the foreground, then immediately call `UIApplication.shared.open(url)` to launch Phone/Messages. The app appears for ~0.3 seconds then redirects — feels nearly seamless. The **Snooze/Tomorrow** action uses `.destructive` option and runs silently in the background via `UNUserNotificationCenter.delegate` without opening the app |
| **User control** | Can mute nudges for today. Can disable specific nudge types in settings |
| **Tech** | Local scheduled notifications. Nudge copy generated from templates (no AI needed for MVP — use 15-20 pre-written messages with variable slots) |

#### Feature 6: Action Shortcuts (Call, Text, Open Link)
| Attribute | Detail |
|---|---|
| **What** | When AI splits a brain dump, it detects actionable items and attaches a quick-action button: 📞 Call, 💬 Text, 🔗 Open Link |
| **How it works** | "Call dentist" → card shows a 📞 button → tap → iOS Phone app opens with number ready to dial. "Text Sarah about Saturday" → card shows 💬 button → tap → Messages app opens with Sarah as recipient. Shared URLs → card shows 🔗 button → tap → opens in Safari/browser |
| **Detection logic** | AI prompt detects action verbs: "call", "text", "message", "email" → attaches action type. Shared URLs auto-get the 🔗 action. Users can also manually add a phone number or contact name to any card |
| **Contact lookup** | When user taps 📞 or 💬, the app opens the iOS contact picker if no number is attached yet. Once selected, the number is saved to the card for next time |
| **Tech** | Native `UIApplication.shared.open(URL(string: "tel:...")!)` for calls, `https:` for links — both use simple URL schemes. **⚠️ For texts with pre-filled body:** must use `MFMessageComposeViewController` (iOS's `sms:` URL scheme does NOT support the `body` parameter). `sms:` only opens a blank thread. To pre-fill text body + recipient, present `MFMessageComposeViewController` via a `UIViewControllerRepresentable` wrapper. For calls and links, URL schemes work fine. Contact picker via native `CNContactPickerViewController` (one-time permission request) |
| **Privacy** | Nudge NEVER reads calls, messages, or contacts in the background. It only opens the native dialer/messenger when YOU tap the button. Contact access is requested solely for the picker — standard iOS behavior, not invasive |

#### Feature 7: AI-Drafted Messages (Nudge & Do)
| Attribute | Detail |
|---|---|
| **What** | When a card has a 💬 or 📧 action, Nudge uses AI to **pre-write the message** based on task context. User reviews and taps Send — one tap instead of composing from scratch |
| **Example 1** | Task: *"Text Sarah about Saturday"* → Nudge drafts: *"Hey Sarah! Are we still on for Saturday? Let me know the time/place 🙌"* → Opens Messages with draft pre-filled → user taps Send |
| **Example 2** | Task: *"Email landlord about the leak"* → Nudge drafts: *"Hi, I wanted to follow up on the water leak in the kitchen I mentioned last week. Could someone come take a look this week? Thanks, [User's name]"* → Opens Mail with subject + body pre-filled → user taps Send |
| **Example 3** | Task: *"Call dentist to book cleaning"* → Nudge shows: *"I can't call for you yet, but here's a text you can send instead:"* → Draft: *"Hi, I'd like to schedule a teeth cleaning. I'm available weekday mornings. Could you let me know what's open? Thanks!"* → User chooses 📞 Call or 💬 Send Text |
| **How drafts work** | When a card with an action type is shown in the One-Thing View, the AI generates a contextual draft in the background. By the time the user taps the action button, the draft is ready. If offline, no draft — falls back to blank compose |
| **Tone detection** | AI infers tone from context: casual for friends ("Hey!"), professional for business ("Dear…"), brief for quick tasks. User can edit any draft before sending |
| **Tech** | Same GPT-4o-mini API used for brain dumps. Draft generation prompt includes: task text, contact name (if known), action type. **⚠️ Critical: iOS `sms:` URL scheme does NOT support `body` parameter** (Apple explicitly documents this). Must use `MFMessageComposeViewController` to pre-fill text message drafts — this presents a native Messages compose sheet inside the app with recipients + body pre-filled. For email, `mailto:?subject=...&body=...` DOES work. Uses Swift `async/await` for background generation |
| **Cost** | ~$0.0001 per draft (slightly more tokens than task splitting, still effectively free) |
| **Free tier** | Action shortcuts work (call/text/link) but **no AI drafts** — user composes manually |
| **Pro tier** | Full AI-drafted messages on every actionable card |

---

### ❌ OUT — Explicitly Not in MVP

| Feature | Why It's Out |
|---|---|
| User accounts / sign-up | Friction kills adoption. No accounts until cloud sync (v2) |
| Calendar integration | Moved to v1.1. Read-only — pull today's events as context cards, not management |
| Recurring tasks | Adds complexity to the data model. v2 |
| Tags / categories / folders | Organization = overhead = the exact problem we're solving against |
| Collaboration / sharing | Single-player tool. No network effects needed |
| Analytics / statistics | "You completed 47 tasks this week" = gamification = guilt. Against our principles |
| Widget | Moved to v1.1 — WidgetKit with dark card + accent color. Easy since we're native Swift |
| Apple Watch / Wear OS | v3 — Apple Watch only. Native SwiftUI watch app |
| Web app | Mobile-only for focus. v2/v3 |
| Cloud sync | SwiftData + CloudKit in v2.0 — since we built on SwiftData, sync is nearly free to add |
| Accent color customization | Users can't pick accent colors in MVP. Single palette ships. Custom palettes = v1.1 |

---

## 5. Screen-by-Screen Flow

```
┌─────────────────────────────────────────────────┐
│                 APP LAUNCH                       │
│                                                  │
│  First ever open? → Splash (3 screens max)       │
│  Returning user?  → One-Thing View               │
└──────────────────────┬──────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────┐
│            SCREEN 1: ONE-THING VIEW              │
│              (Home / Daily Cockpit)              │
│                                                  │
│  ┌─────────────────────────────────────────┐     │
│  │                                         │     │
│  │     [ Black bg + accent-border card ]    │     │
│  │                                         │     │
│  │         "Call the dentist"              │     │
│  │                                         │     │
│  │     ← Snooze    ·    Done →            │     │
│  │            ↓ Skip                       │     │
│  │                                         │     │
│  └─────────────────────────────────────┘     │
│          🐧 (idle penguin below card)            │
│                                                  │
│  Bottom bar:                                     │
│  [ 🎤 Brain Dump ]  [ 📋 All Items ]  [ ⚙ ]    │
│                                                  │
└──────────────────────┬──────────────────────────┘
           │           │           │
           ▼           ▼           ▼
    ┌──────────┐ ┌──────────┐ ┌──────────┐
    │ Screen 2 │ │ Screen 3 │ │ Screen 4 │
    │Brain Dump│ │All Items │ │ Settings │
    └──────────┘ └──────────┘ └──────────┘
```

### Screen 1: One-Thing View (Home)
- Full-screen card showing the single highest-priority item on a **pure black background**
- Card: dark translucent surface (`#1C1C1E` at 80%) with a subtle accent-colored border (blue = active, amber = stale, red = overdue)
- Task text in white, metadata (age, source) in grey
- Swipe right = Done (✓ animation, card border flashes green), swipe left = Snooze (time picker appears), swipe down = Skip
- **Penguin mascot:** Small, idle penguin visible below the card in a subtle position — slow blink every ~8 seconds, gentle body sway. When a task is completed, penguin does a quick happy bounce. Keeps the screen feeling alive, not static
- **Action button:** If the card has an action type (📞 Call / 💬 Text / 🔗 Open), a prominent action button appears below the task text, tinted with the accent color. Tapping it launches the native dialer, Messages, or browser. After the action, user returns to Nudge and can swipe Done
- **AI draft preview (Pro):** For 💬 and 📧 cards, a collapsible draft preview appears below the action button: *"Draft: Hey Sarah! Are we still on for Saturday?..."* — tap to expand full text, tap action button to send with draft pre-filled, or tap "Edit" to modify before sending
- If no items: **empty state penguin** — the mascot sits contentedly with closed eyes, the card area shows a soft green glow with the message *"Your brain is clear. Go enjoy something."*
- Bottom navigation: Brain Dump (mic icon, blue accent), All Items (list icon), Settings (gear icon)
- Floating indicator: small, subtle count in grey — *"3 of 7"* — showing position in today's queue

### Screen 2: Brain Dump
- Full-screen overlay/modal (slides up from bottom) on black background
- Large pulsing microphone button in center, ringed with the accent blue glow
- While recording: waveform visualization in accent blue + live transcript appearing in white text
- When done: **penguin "thinking" animation** (tilted head, bouncing dots) replaces the spinner → cards appear one by one with slide-in animation
- Each card has: auto-generated emoji, task text in white, accent-colored border, "Edit" pencil icon
- Bottom: "Save all" button (accent blue) → returns to One-Thing View with new cards added

### Screen 3: All Items
- Simple scrollable list on black background with dark translucent row cards
- Sections: "Up Next" (active queue, blue accent markers), "Snoozed" (with return time shown in grey), "Done Today" (with strikethrough + green accent)
- Stale items (3+ days) show amber accent dot
- Tap any item → edit text, change snooze time, or delete
- Long-press → quick actions (snooze, delete, move to top)
- This is the ONLY screen that shows a "list" — it's the escape hatch, not the primary experience

### Screen 4: Settings
- Minimal. Dark background, grouped sections with dark translucent cards. MVP settings:
  - **Nudge quiet hours** (default: 9pm–8am)
  - **Max nudges per day** (default: 3)
  - **Live Activity on Lock Screen** (default: OFF) — toggle to show current task on Dynamic Island + Lock Screen
  - **Upgrade to Pro** (in-app purchase)
  - **About / Contact** — penguin mascot in header with version number
- No account settings (no accounts in MVP)

### Screen 5: Snooze Time Picker (Overlay)
- Appears when swiping left on a card or tapping snooze
- Quick options: "Later today" (3 hours), "Tomorrow morning" (9am), "This weekend" (Saturday 10am), "Next week" (Monday 9am)
- Custom: date + time picker
- Tap option → card flies away with "See you then" micro-animation

### Screen 6: Share Extension (System-Level)
- Native iOS Share Extension target (separate Xcode target, shared App Group)
- Appears in iOS share sheet as "Save to Nudge" with penguin app icon
- On tap: custom SwiftUI overlay on dark background with time picker (same quick options as Screen 5), accent-colored buttons
- Uses `NSItemProvider` to extract URLs, text, images from the sharing app
- Tap option → "Saved ✓" confirmation with haptic + small penguin thumbs-up → share sheet dismisses
- Content saved to App Group UserDefaults → main app ingests into SwiftData on next launch

### Screen 7: Onboarding (First Launch Only)
- Maximum 3 screens, skippable. Black background, penguin mascot guides each panel:
  1. 🐧 Penguin with microphone: *"Talk, don't type"* — shows brain dump concept
  2. 🐧 Penguin holding one card: *"One thing at a time"* — shows One-Thing view
  3. 🐧 Penguin catching a falling link: *"Share anything, see it later"* — shows share-to-snooze
- Final screen: "Get started" button (accent blue on black) → goes directly to One-Thing View (empty state with idle penguin)
- No sign-up. No permissions asked yet (request mic on first brain dump, notifications on first snooze)

---

## 6. Technical Architecture

### Stack
| Component | Technology | Rationale |
|---|---|---|
| **Platform** | iOS 17+ (iPhone only) | Native Swift unlocks Share Extensions, WidgetKit, Dynamic Island, Live Activities, Siri Intents — all critical to Nudge's vision. Android planned for v3+ |
| **UI Framework** | SwiftUI | Declarative, native materials (`.ultraThinMaterial` on dark canvas), built-in animations, `TimelineView` for accent hue shift |
| **Language** | Swift 5.9+ | Native, performant, full access to Apple frameworks |
| **Design Language** | Dark UI + Dynamic Accents | Pure black (`#000`) canvas, dark translucent cards (`#1C1C1E`), status-driven accent colors (blue/green/amber/red). Penguin mascot for personality. `.ultraThinMaterial` for layered depth on dark surfaces |
| **Local DB** | SwiftData (Core Data successor) | Apple-native, Swift-first ORM, built-in migrations, works with CloudKit for future sync |
| **Speech-to-Text** | `SFSpeechRecognizer` (Apple Speech framework) | On-device, free, works offline, highest accuracy on iOS, no third-party dependency |
| **AI Task Splitting** | OpenAI GPT-4o-mini API | Cheapest capable model. ~$0.001 per brain dump. Fallback: save raw text if offline |
| **Share Extension** | Native iOS Share Extension (`NSExtensionContext`) | First-class Apple API. Reliable, fast, full control over UI. No plugin wrappers |
| **Action Shortcuts** | `UIApplication.shared.open(URL(...))` + `MFMessageComposeViewController` | `tel:` for calls, `mailto:` for email, `https:` for links — all via URL schemes. **SMS requires `MFMessageComposeViewController`** to pre-fill body text (the `sms:` URL scheme opens blank threads only). Wrap in `UIViewControllerRepresentable` for SwiftUI |
| **Contact Picker** | `CNContactPickerViewController` (ContactsUI framework) | Native iOS contact picker. One-time permission, no background access |
| **Notifications** | `UNUserNotificationCenter` + `UNNotificationAction` | Native iOS notifications with interactive buttons directly in the banner. No library needed |
| **State Management** | `@Observable` (Observation framework) + SwiftUI `@State` / `@Environment` | Apple's native observation — no third-party state management needed |
| **Navigation** | `NavigationStack` + `sheet()` / `fullScreenCover()` | SwiftUI-native navigation. Deep-link friendly |
| **In-App Purchases** | StoreKit 2 | Modern Swift-async API. Dramatically simpler than StoreKit 1. Handles subscriptions natively |
| **Networking** | `URLSession` + `async/await` | Native, no Alamofire needed. Swift concurrency for clean async code |
| **Analytics** | TelemetryDeck (privacy-first) or PostHog | Lightweight. Optional. TelemetryDeck is built for indie iOS apps |
| **Contextual Tips** | `TipKit` (iOS 17+) | Native inline tips to teach features without onboarding overload. E.g., "Swipe right to complete" on first card, "Try a brain dump" on empty state. Apple loves apps that use TipKit |
| **Accessibility** | Native `VoiceOver` + `Dynamic Type` + `accessibilityLabel` on all custom views | Full VoiceOver navigation, all 7 Dynamic Type sizes, reduced motion alternatives. Zero warnings in Accessibility Inspector |
| **Dynamic Island** | ActivityKit + `Live Activities` | **Opt-in** (default OFF). Show current task + time-awareness gradient strip on lock screen and Dynamic Island. iOS 16.1+. **⚠️ 8-hour max lifetime** — auto-restart via background task. Push gradient strip updates at 5 time-of-day transitions via `BGAppRefreshTask`. ~4KB payload limit |

### Data Model (SwiftData `@Model` Classes)

```swift
@Model
class NudgeItem {
    var id: UUID
    var content: String              // Task text or saved content
    var sourceType: SourceType       // .voiceDump, .share, .manual
    var sourceUrl: String?           // If shared from another app
    var sourcePreview: String?       // Link title, image thumb, etc.
    var status: ItemStatus           // .active, .snoozed, .done, .dropped
    var snoozedUntil: Date?          // When to resurface
    var createdAt: Date
    var completedAt: Date?
    var sortOrder: Int               // Position in queue
    var emoji: String?               // Auto-assigned emoji
    var actionType: ActionType?      // .call, .text, .email, .openLink
    var actionTarget: String?        // Phone number, email, or URL
    var contactName: String?         // Resolved contact name
    var aiDraft: String?             // AI-generated message draft (Pro)
    var aiDraftSubject: String?      // Email subject line draft
    var draftGeneratedAt: Date?      // When draft was last generated
}

@Model
class BrainDump {
    var id: UUID
    var rawTranscript: String        // Original speech text
    var processedAt: Date
    var items: [NudgeItem]           // SwiftData relationship to created items
}

// Stored in UserDefaults (not SwiftData — lightweight, no migration needed)
class AppSettings: ObservableObject {
    @AppStorage("quietHoursStart") var quietHoursStart: Int = 21    // 9pm
    @AppStorage("quietHoursEnd") var quietHoursEnd: Int = 8         // 8am
    @AppStorage("maxDailyNudges") var maxDailyNudges: Int = 3
    @AppStorage("liveActivityEnabled") var liveActivityEnabled: Bool = false  // Opt-in, default OFF
    @AppStorage("isPro") var isPro: Bool = false
    @AppStorage("dailyDumpsUsed") var dailyDumpsUsed: Int = 0
    @AppStorage("savedItemsCount") var savedItemsCount: Int = 0
    @AppStorage("userName") var userName: String = ""               // For draft sign-offs
}
```

### Project Structure (Xcode)
```
Nudge/
├── NudgeApp.swift                  // @main App entry point
├── ContentView.swift               // Root view + router
│
├── Core/
│   ├── Theme/
│   │   ├── AccentColorSystem.swift  // Dynamic accent colors (status-based + time-aware hue shift)
│   │   ├── DarkCard.swift           // Reusable dark translucent card component (#1C1C1E + accent border)
│   │   ├── AppTheme.swift           // Typography, spacing, colors, materials, design tokens
│   │   ├── AnimationConstants.swift  // All spring configs, timing specs, stagger delays — single source of truth
│   │   └── PenguinMascot.swift      // Penguin mascot SwiftUI view (states: idle, happy, thinking, sleeping, celebrating)
│   ├── Accessibility/
│   │   ├── DynamicTypeModifiers.swift  // Custom ViewModifiers for Dynamic Type scaling on custom views
│   │   └── VoiceOverHelpers.swift      // `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityAction` extensions
│   ├── Constants.swift             // Free tier limits, defaults, accent color hex values
│   └── Extensions/                 // Date helpers, URL helpers, View extensions, Color+Hex
│
├── Resources/
│   ├── Localizable.xcstrings       // All user-facing strings (String Catalog format, iOS 17+)
│   ├── Sounds/
│   │   ├── brain-dump-start.caf    // Bubble pop (0.2s)
│   │   ├── task-done.caf           // Two-note chime (0.3s)
│   │   ├── all-clear.caf           // Warm chord (0.5s)
│   │   └── nudge-knock.caf        // Custom notification sound (0.5s) — registered with UNNotificationSound
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset/     // Penguin silhouette on black + accent blue glow
│       ├── Penguin/                // All penguin expression states as vector PDFs
│       └── Screenshots/            // App Store screenshot templates (6.7", 6.5", 5.5")
│
├── Models/
│   ├── NudgeItem.swift             // SwiftData @Model for tasks
│   ├── BrainDump.swift             // SwiftData @Model for voice dumps
│   └── AppSettings.swift           // UserDefaults wrapper for settings
│
├── Services/
│   ├── AIService.swift             // GPT-4o-mini: task splitting + draft generation
│   ├── DraftService.swift          // AI draft lifecycle: generate, cache, pre-fill
│   ├── SpeechService.swift         // SFSpeechRecognizer wrapper
│   ├── NotificationService.swift   // UNUserNotificationCenter + actions
│   ├── ContactService.swift        // CNContactPicker integration
│   ├── ActionService.swift         // URL scheme launching (tel:, mailto:) + MFMessageComposeViewController for SMS
│   ├── PurchaseService.swift       // StoreKit 2 subscription management
│   ├── HapticService.swift         // Centralized haptic engine — pre-warms generators, plays patterns per interaction
│   ├── SoundService.swift          // Custom audio feedback — brain dump pop, done chime, clear chord. Respects Silent Mode
│   └── AccessibilityService.swift  // Dynamic Type support, VoiceOver helpers, Reduce Motion detection, high-contrast overrides
│
├── Features/
│   ├── OneThing/
│   │   ├── OneThingView.swift      // Main screen — single card on black bg + penguin mascot
│   │   └── CardView.swift          // Dark translucent task card with accent border + actions + draft
│   ├── BrainDump/
│   │   ├── BrainDumpView.swift     // Full-screen mic + waveform overlay
│   │   └── BrainDumpViewModel.swift
│   ├── AllItems/
│   │   ├── AllItemsView.swift      // List view (escape hatch)
│   │   └── ItemRowView.swift
│   ├── Snooze/
│   │   └── SnoozePickerView.swift  // Time picker overlay
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Onboarding/
│       └── OnboardingView.swift    // 3-screen first-launch flow
│
├── Shared/
│   └── Components/                 // Reusable SwiftUI components
│
├── NudgeShareExtension/            // iOS Share Extension target
│   ├── ShareViewController.swift   // NSExtensionContext handler
│   └── ShareView.swift             // SwiftUI share sheet UI (time picker)
│
├── NudgeWidget/                    // WidgetKit target
│   └── NudgeWidget.swift           // Lock screen / home screen widget
│
└── NudgeLiveActivity/              // Live Activity target (opt-in)
    └── NudgeLiveActivity.swift     // Dynamic Island + lock screen gradient strip + current task
```

### API Contract: Brain Dump Splitting

**Prompt sent to GPT-4o-mini:**
```
You are a task extraction assistant. The user spoke a stream-of-consciousness brain dump. 
Extract individual actionable items. For each item:
1. Write a short, clear task (max 8 words)
2. Assign one relevant emoji

Rules:
- If the input is a single task, return just that one
- Ignore filler words, "um", "uh", "like", repetitions
- If something isn't actionable (e.g., "I'm tired"), skip it
- Detect action types: if task involves calling someone → "CALL", texting/messaging → "TEXT", emailing → "EMAIL"
- Return JSON array: [{"task": "...", "emoji": "...", "action": "CALL|TEXT|EMAIL|null", "contact": "person or business name if mentioned, else null"}]

User's brain dump transcript:
"{transcript}"
```

**Cost analysis:**
- Average brain dump: ~50 words → ~75 tokens input + ~50 tokens output
- GPT-4o-mini: $0.15/1M input, $0.60/1M output
- **Cost per dump: ~$0.00004** (effectively free)
- 1,000 daily active users × 3 dumps/day = 3,000 calls/day = **~$0.12/day**

### API Contract: AI Draft Generation

**Prompt sent to GPT-4o-mini (when card is shown in One-Thing View):**
```
You are a message drafting assistant. The user has a task that requires contacting someone. 
Write a short, ready-to-send message on their behalf.

Context:
- Task: "{task_content}"
- Action type: {TEXT|EMAIL}
- Recipient: "{contact_name or 'unknown'}"
- Tone: {infer from context — casual for friends/family, professional for business/services}

Rules:
- Keep it SHORT. Texts: 1-3 sentences max. Emails: 3-5 sentences max
- Be natural and human — not robotic or overly formal
- Include a clear ask or purpose
- For emails: also generate a subject line
- If the task mentions a specific topic (e.g., "about Saturday"), include it
- Return JSON: {"draft": "...", "subject": "..." (email only)}
```

**Draft generation cost analysis:**
- Average draft: ~30 tokens input + ~40 tokens output
- **Cost per draft: ~$0.00003**
- 1,000 DAU × 2 drafts/day = 2,000 calls/day = **~$0.06/day**
- Combined with brain dumps: **~$0.18/day for 1,000 users**

---

## 7. Monetization

### Pricing Model
| | Free | Pro |
|---|---|---|
| **Price** | $0 | **$9.99/month** or **$59.99/year** |
| Brain dumps per day | 3 | Unlimited |
| Saved items (Share-to-Nudge) | 5 total | Unlimited |
| One-Thing View | ✅ | ✅ |
| Dynamic accent colors | ✅ | ✅ |
| Live Activity (opt-in) | ✅ | ✅ |
| Penguin mascot | ✅ | ✅ (extra expressions in Pro) |
| Action shortcuts (call/text/link) | ✅ | ✅ |
| **AI-drafted messages** | ❌ | ✅ — AI writes texts & emails, you just tap Send |
| **Actionable notification buttons** | ❌ | ✅ — Call/Text/Snooze directly from notification |
| Nudge notifications | Basic (snoozed items only) | Smart nudges (stale items, end-of-day prompts) |
| Swipe gestures | ✅ | ✅ |
| Priority support | ❌ | ✅ |

### Why this pricing works
- From research: consumer apps at **$8.99-$19.99/mo** that solve ONE thing = sweet spot
- ADHD is a **lifelong condition** — users don't churn from tools that genuinely help
- Free tier is **genuinely useful** (not crippled) — builds trust and word-of-mouth
- Yearly discount (50% off) encourages commitment and reduces churn

### Revenue projections (conservative)
| Metric | Month 3 | Month 6 | Month 12 |
|---|---|---|---|
| Downloads | 2,000 | 8,000 | 25,000 |
| Free users | 1,600 | 6,000 | 18,000 |
| Pro subscribers | 80 (4%) | 480 (6%) | 2,000 (8%) |
| MRR | $800 | $4,800 | $20,000 |

Conversion rate assumption: 4% at launch → 8% at maturity (industry average for utility apps: 2-5%, ADHD niche converts higher due to desperation)

---

## 8. Go-to-Market Strategy

### Pre-Launch (During Build — Weeks 1-4)
- [ ] Set up landing page with email capture (Carrd, $19/yr)
- [ ] Post in r/ADHD, r/adhdwomen — *"Building an app for ADHD brains, what do you need?"*
- [ ] Start a build-in-public thread on X/Twitter — weekly progress updates
- [ ] Create short TikTok/Reels showing the concept (screen recordings of prototype + penguin mascot reveal — character-driven content performs well in ADHD TikTok)
- [ ] **Goal: 200+ email signups before launch**

### Launch Week (Week 5)
- [ ] TestFlight beta testing with 20 waitlist volunteers (include 2-3 VoiceOver users if possible)
- [ ] Incorporate 3-5 days of feedback
- [ ] Submit to App Store — ensure: Privacy Nutrition Labels complete, all 4 screenshot sizes, app preview video uploaded, custom product page for ADHD keywords
- [ ] **Submit Featuring Nomination** via App Store Connect — include: penguin character story, ADHD mission angle, technical showcase (SwiftData + ActivityKit + SFSpeechRecognizer + TipKit), accessibility commitment, screenshots
- [ ] Product Hunt launch (Tuesday or Wednesday, 12:01am PT)
- [ ] Reddit launch posts: r/ADHD, r/adhdwomen, r/productivity, r/iphone, r/apple
- [ ] Email waitlist: *"It's here. You're the first to know."*

### Post-Launch (Months 1-3)
- [ ] Respond to every single App Store review
- [ ] Weekly TikTok content (1 video showing a real use case + penguin personality, 30-60 seconds — the penguin character is the hook)
- [ ] Monitor and engage in ADHD subreddits organically (don't spam)
- [ ] Reach out to 5-10 ADHD content creators on TikTok/YouTube for organic reviews
- [ ] App Store Optimization: target "ADHD planner", "brain dump app", "ADHD task manager", "ADHD iPhone app"

### Key Channels (Ranked by Expected ROI)
1. **ADHD TikTok/Reels** — Free, massive reach, highly viral niche
2. **Reddit (ADHD subs)** — Free, high-intent users, direct feedback loop
3. **Product Hunt** — Free, one-shot, good for credibility + early adopter surge
4. **ASO (App Store Optimization)** — Free, compounds over time
5. **Build-in-public on X** — Free, attracts indie hacker community + potential press

### Channels We're NOT Using
- ❌ Paid ads (no budget, premature)
- ❌ Influencer partnerships with payment (no budget)
- ❌ PR / press outreach (too small, no story yet)
- ❌ Content marketing / blog (time sink for 2-person team)

---

## 9. Sprint Plan

### Week 1: Foundation + Brain Dump + Design System
**Deliverable:** Open app → tap mic → speak → see split task cards on dark UI with accent-colored borders + penguin mascot idle state. All animations use spring physics. All text supports Dynamic Type. VoiceOver navigates every element.

| Day | Tasks |
|---|---|
| Day 1 | Xcode project setup, targets (main app, Share Extension, Widget, Live Activity), App Group for shared data, SwiftData container, design token constants (all hex colors, accent system). **`AnimationConstants.swift`** with all spring configs. **`Localizable.xcstrings`** String Catalog — every string from Day 1. Set `accessibilityLabel` convention: every custom view gets one |
| Day 2 | Dark UI theme system — `AccentColorSystem.swift` (status colors + time-aware hue shift), `DarkCard.swift` (translucent card component with accent border), `AppTheme.swift` (typography with Dynamic Type scaling, spacing), `PenguinMascot.swift` (basic idle state with blink animation). **`HapticService.swift`** — pre-warm all generators on app launch. **`AccessibilityService.swift`** — Reduce Motion detection, Dynamic Type size observer |
| Day 3 | SwiftData models (`NudgeItem`, `BrainDump`), basic CRUD operations, repository pattern. **`SoundService.swift`** — load all `.caf` files, respect Silent Mode |
| Day 4 | Brain Dump screen — `SFSpeechRecognizer` integration, mic button with accent glow ring + spring scale animation + haptic on tap, waveform visualization, AI service for task splitting, penguin "thinking" animation during processing. VoiceOver: announce "Recording started"/"Processing" states |
| Day 5 | Brain Dump → cards flow end-to-end with staggered slide-in animation (0.15s delay between cards). Manual text entry fallback. Action shortcuts wiring (`UIApplication.shared.open` for call/text/link, `CNContactPicker`). **TipKit** first tip: "Tap the mic to brain dump" on empty state |

### Week 2: One-Thing View + Nudge & Do + Animation Polish
**Deliverable:** Open app → see one dark translucent task card with accent border → penguin idle below → see AI draft → tap to act or swipe through. Every swipe has spring physics + haptic feedback. VoiceOver users can swipe through cards with custom actions.

| Day | Tasks |
|---|---|
| Day 1 | One-Thing View UI — full-screen dark card on black bg, accent-colored border based on task status, `DragGesture` for swipe interactions with **interruptible spring animations** (card follows finger, snaps back or commits with momentum), haptic feedback on each action (done=success, snooze=warning, skip=light), penguin mascot below card (idle: blink + sway). **VoiceOver**: card reads content + status, custom actions for done/snooze/skip |
| Day 2 | Task queue logic — ordering, done/skip/snooze state transitions. Done animation: card flies right with 15° rotation + green flash (0.15s) + checkmark particle burst + penguin happy bounce (0.6s). Empty state: sleeping penguin + green glow + "Your brain is clear" + chime sound. **VoiceOver**: announces "Task completed" / "All clear" |
| Day 3 | Snooze time picker overlay (slides from bottom with spring). AI draft generation service (background pre-fetch with Swift `async/await`). Selection haptic on picker scroll |
| Day 4 | Draft preview UI on cards — collapsible draft text, "Edit" option, pre-filled compose via `MFMessageComposeViewController`. TipKit tip: "Swipe right to complete" on first card interaction |
| Day 5 | All Items list view (escape hatch screen) with parallax scroll effect + sticky section headers. Actionable notification buttons (`UNNotificationAction(options: [.foreground])` — routes through app then opens Phone/Messages. Snooze action runs silently in background). Tab bar transitions: cross-fade (0.25s) + `symbolEffect(.bounce)` on active icon |

### Week 3: Share Extension + Notifications + Live Activity
**Deliverable:** Share from any app → appears in Nudge with penguin thumbs-up + haptic. Custom notification sound ("knock knock"). Opt-in Live Activity shows current task + gradient strip on lock screen/Dynamic Island.

| Day | Tasks |
|---|---|
| Day 1 | iOS Share Extension target — `NSExtensionContext`, SwiftUI share sheet UI, App Group `UserDefaults(suiteName:)` for data handoff to main app. **Penguin thumbs-up micro-animation** (0.4s) + success haptic on save |
| Day 2 | Share receiver — parse content (URL via `NSItemProvider`, text, image) → write JSON to App Group UserDefaults → main app ingests into SwiftData. Keep extension memory under 120MB (use `NSItemProvider` file URLs, avoid loading images into memory). VoiceOver: announce "Saved to Nudge" |
| Day 3 | Share-time picker (quick snooze options). Live Activity + Dynamic Island (opt-in) — gradient strip with 5 pre-computed color states, Settings toggle wiring, one-time opt-in prompt on first brain dump, `BGAppRefreshTask` to push updates at time transitions, auto-restart after 8-hour expiry |
| Day 4 | `UNUserNotificationCenter` — schedule, cancel, handle taps. `UNNotificationCategory` for action buttons. **Register custom notification sound** (`nudge-knock.caf`) via `UNNotificationSound(named:)` |
| Day 5 | Nudge notification templates — write copy, wire up stale/snoozed/EOD triggers. TipKit tips for share extension and Live Activity features |

### Week 4: Polish + Monetization + Ship Prep
**Deliverable:** App feels like it shipped from Apple's own design team. Free/Pro tiers work. Accessibility Inspector = zero warnings. Performance profiled. App Store assets complete. Ready for TestFlight.

| Day | Tasks |
|---|---|
| Day 1 | Onboarding flow (3 screens with penguin mascot, SwiftUI `TabView` with page style, black bg + accent highlights, spring transitions between pages). Settings screen, quiet hours, nudge frequency |
| Day 2 | StoreKit 2 integration — Pro subscription, paywall screen (compelling design with penguin Pro features preview), restore purchases. Free tier limits enforcement (dump count, saved items cap) |
| Day 3 | **Accessibility audit day.** Run Accessibility Inspector on every screen. Fix all warnings. Test full VoiceOver navigation flow. Verify all 7 Dynamic Type sizes render correctly (especially on cards and empty states). Test Reduce Motion: all springs → cross-fades. Test Bold Text, Increase Contrast, Smart Invert |
| Day 4 | **Performance profiling day.** Instruments: Core Animation (verify 60fps on all animations on iPhone 12), Allocations (verify <50MB active), Time Profiler (cold launch <1s). Fix any frame drops. **App Store screenshots** — capture on iPhone 15 Pro Max (6.7") and iPhone 14 (6.1"), design with device frames, dark background, accent highlights. **App preview video** (15-30s) showing brain dump → card flow → penguin reactions |
| Day 5 | Bug fixes, edge cases, micro-animation tweaks. App Store Connect: metadata (title, subtitle, keywords, description, privacy labels). Featuring Nomination draft. Final end-to-end test. TestFlight build |

---

## 10. Performance & Technical Excellence

Apple Editor's Choice apps are technically flawless. These are non-negotiable performance budgets:

### Performance Budgets
| Metric | Target | How to Measure | Fail Threshold |
|---|---|---|---|
| **Cold launch → interactive** | <1.0 second | Instruments Time Profiler + `os_signpost` on `didFinishLaunching` → first frame rendered | >1.5s = must fix before ship |
| **Animation frame rate** | 60fps on all transitions | Instruments Core Animation tool on iPhone 12 (our baseline device) | Any drop below 55fps = must fix |
| **Memory (active use)** | <50MB | Instruments Allocations, live bytes during brain dump → card interaction | >80MB = investigate |
| **Memory (Share Extension)** | <80MB | Profile in Instruments with extension target | >120MB = will crash |
| **SwiftData fetch** | <50ms for any query | `os_signpost` around all fetch operations | >100ms = add index or optimize predicate |
| **AI response (task split)** | <3 seconds end-to-end | Timer from API call to cards rendered | >5s = show cancel option |
| **App size (download)** | <25MB | Xcode archive → App Store Connect size report | >40MB = audit assets |
| **Crash-free rate** | 99.8%+ | Xcode Organizer crash reports | <99.5% = stop feature work, fix crashes |
| **Battery impact** | No background drain | Instruments Energy Log, test 8-hour background | Any drain = audit background tasks |

### Testing Strategy
| Layer | Tool | What We Test | When |
|---|---|---|---|
| **Unit tests** | XCTest | SwiftData CRUD, AI response parsing, accent color calculations, snooze date logic, draft generation | Every PR |
| **UI tests** | XCUITest | Full brain dump flow, swipe interactions, onboarding, paywall, share extension ingest | Every release |
| **Accessibility tests** | Accessibility Inspector + manual VoiceOver | Every screen navigable, every element labeled, Dynamic Type renders correctly | Week 4 Day 3 (dedicated) |
| **Performance tests** | Instruments (Time Profiler, Core Animation, Allocations, Energy) | All budgets met on iPhone 12 | Week 4 Day 4 (dedicated) |
| **Beta testing** | TestFlight | 20 volunteers from waitlist. Focus: ADHD users, diverse devices (iPhone 12 → 15 Pro Max), VoiceOver users | Week 5 |
| **Snapshot tests** | `swift-snapshot-testing` (optional) | Key screens at all Dynamic Type sizes — catch UI regressions | If time allows |

### Code Quality Standards
- **Zero force-unwraps** (`!`) in production code. All optionals handled with `guard let` or `if let`
- **Zero Xcode warnings** at build time. Treat warnings as errors (`SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`)
- **Structured concurrency only** — no `DispatchQueue.main.async`. Use `@MainActor`, `Task {}`, `async/await`
- **No third-party UI dependencies** — everything is native SwiftUI + UIKit bridges where needed
- **Consistent naming** — follow Swift API Design Guidelines. `verb` for mutating, `noun` for non-mutating
- **SwiftLint** with strict rules — enabled from Day 1

---

## 11. Success Metrics

### North Star Metric
**Daily Active Users who complete at least 1 item per day**

This single metric captures: people downloaded it (acquisition), opened it (activation), AND used it meaningfully (engagement).

### Supporting Metrics
| Metric | Target (Month 1) | Target (Month 6) |
|---|---|---|
| Daily Active Users (DAU) | 200 | 2,000 |
| DAU/MAU ratio (stickiness) | 30%+ | 40%+ |
| Brain dumps per user per day | 1.5 | 2.0 |
| Items completed per user per day | 3 | 5 |
| Share-to-Nudge uses per week | 2 per user | 5 per user |
| AI drafts sent (Pro users) | 3 per user/week | 8 per user/week |
| Actions taken from notifications | 10% of nudges | 25% of nudges |
| Free → Pro conversion | 4% | 8% |
| Day-7 retention | 35% | 45% |
| Day-30 retention | 15% | 25% |
| App Store rating | 4.5+ | 4.7+ |

### Metrics We're NOT Tracking
- ❌ Total downloads (vanity metric)
- ❌ Session duration (longer ≠ better for a utility app — we WANT short sessions)
- ❌ Feature usage percentages (premature optimization)

---

## 12. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Apple rejects share extension | Medium | High | Follow Apple's share extension guidelines strictly. Test on real device early (Week 1) |
| AI splitting produces garbage results | Low | Medium | Fallback to raw text as single card. Users can manually edit/split. Refine prompt over time |
| Speech-to-text accuracy is poor | Low | Low | Users can tap to manually type. Speech is a convenience, not the only input |
| Free tier too generous → nobody upgrades | Medium | High | Monitor conversion rate. Adjust limits at Week 6 if <2% conversion |
| Free tier too restrictive → bad reviews | Medium | Medium | Start generous, tighten only if conversion proves the value |
| ADHD community rejects "another productivity app" | Medium | High | Positioning is critical: "anti-productivity app for brains that hate productivity apps." The penguin mascot differentiates us from sterile corporate tools. Language matters |
| App Store review process delays launch | Low | Medium | Submit early. Have TestFlight ready as backup distribution |
| Competitor copies the concept | Low | Low | Speed is the moat for now. Data lock-in (saved items) provides switching cost after 30 days of use |
| AI drafts send wrong/awkward message | Medium | Medium | User ALWAYS sees the draft before sending — Apple requires confirmation. "Edit" button prominent. Draft is a suggestion, not auto-send |
| Users uncomfortable with AI writing for them | Low | Low | Drafts are Pro-only and optional. Free tier works without them. Position as "suggestion you can edit", not "AI taking over" |
| Quality bar causes scope creep / delays launch | Medium | High | The animation + accessibility + sound polish is *the product*, not decoration. But: timebox. Week 4 Day 3 is accessibility audit, Day 4 is performance. If not 100% polished by Day 5, ship what's ready and patch in Week 6. Perfect is the enemy of shipped |
| Apple rejects featuring nomination | Medium | Medium | Featuring is not guaranteed. But every quality signal (accessibility, localization, native APIs, performance) also benefits users directly. We lose nothing by building to this bar even without featuring |

---

## 13. Future Roadmap (Post-MVP)

These features are **explicitly out of v1** but planned for future versions based on user demand signals:

### v1.1 (Month 2-3) — Quick Wins + Calendar + Widget + Apple Platform Depth
- Manual text entry quick-add (floating + button)
- **Apple Calendar integration (read-only)** — pull today's events into the One-Thing view as non-actionable context cards (*"Meeting with Jake in 45 min"*). Uses native `EventKit` framework. Helps with time-blindness — you see your next commitment without leaving the app
- **WidgetKit home screen widget** — shows current one-thing task on dark card with accent border. Tap to open Nudge. Small, medium, and lock screen widget sizes. Widget background: `#000` with subtle accent glow
- **Home Screen Quick Actions** — 3D Touch / Haptic Touch on app icon: "Brain Dump" (launches directly to mic), "What's Next" (opens One-Thing View). Uses `UIApplicationShortcutItem` in Info.plist
- **Spotlight integration** — Index active tasks via `CSSearchableIndex`. Users can search for their tasks in Spotlight without opening the app. Tap result → opens directly to that card
- **Accent color customization** — users can choose their base accent color (blue, purple, teal, pink, orange) while status colors (green/amber/red) remain fixed
- **Penguin sticker pack (iMessage)** — 10-15 penguin stickers with expressions matching the mascot states. Free marketing via iMessage. Built with Xcode Sticker Pack target
- **Additional penguin expressions (Pro)** — 3-4 bonus mascot states (dancing, sleeping with Z's, wearing sunglasses, holiday themes)
- Email action shortcut (`mailto:` scheme)
- **Localization — 5 languages:** English, Spanish, French, German, Japanese. All strings already in `Localizable.xcstrings` from v1.0. Hire native speakers for review ($200-400 per language). RTL prep for Arabic in v1.2

### v1.2 (Month 3-4) — Nudge & Do: Level 2 + Shortcuts
- Recurring nudges (*"Weekly: take out trash"*)
- **OAuth email integration (Gmail/Outlook)** — send emails directly from Nudge without opening Mail app. User taps "Send" → email goes out. No context switch
- **Smart context memory** — Nudge remembers: your dentist is "Dr. Chen", your landlord's email, Sarah is casual tone, boss is formal. Future drafts are instantly contextual
- **Siri Integration** — `App Intents` framework: *"Hey Siri, nudge me to call dentist tomorrow"* → creates a card with action type + snooze time. Also: *"Hey Siri, what's my next nudge?"*
- **Shortcuts app integration** — full `App Intents` exposure for power users to build custom automations. E.g., "When I arrive home → show me my home tasks". Moves from v3.0 to v1.2 because App Intents is a strong Apple featuring signal
- **Focus Filters** — integrate with iOS Focus modes. In "Work" Focus, only show work-tagged tasks. In "Personal" Focus, hide work items. Uses `SetFocusFilterIntent`
- Smart ordering improvements (learn from user patterns)
- Quick-capture from notification shade

### v2.0 (Month 5-6) — Nudge & Do: Level 3 + Growth
- **iCloud sync** via CloudKit (SwiftData has built-in CloudKit support — since we used SwiftData from day 1, this is almost free to add). Requires Apple ID sign-in (users already have this)
- Web companion (view-only — manage on phone, glance on desktop)
- Calendar write-back — option to create a calendar event from a snoozed Nudge item ("block time for this task") via `EventKit`
- Smart contact suggestions — after a few calls/texts from Nudge, auto-suggest the right contact for similar tasks
- **Booking agent** — for tasks like "Book dentist appointment", Nudge opens the provider's booking page in an embedded `SFSafariViewController`, pre-fills your info, you confirm the slot
- **Smart ordering links** — "Buy dog food" → Nudge shows your usual brand on Amazon with a deep link, one tap to add to cart

### v3.0 (Month 8+) — Platform Expansion
- **Apple Watch app** — voice capture from wrist via `SFSpeechRecognizer`, glanceable complication showing current task
- **iPad companion** (SwiftUI adaptive layouts — same codebase)
- **Interactive Widgets** — iOS 17 `AppIntent`-powered widgets. Mark tasks done directly from the widget without opening the app
- Family sharing (parent can nudge child's app)
- **Android version** — Kotlin/Jetpack Compose, separate codebase, feature parity with iOS v2.0

---

## 14. Open Questions

These need answers before or during the build. Not blockers — just decisions to make:

1. **App icon & brand** — Penguin silhouette on pure black background with a subtle accent blue glow. Clean, recognizable at any size. Need to commission or design the penguin character early (Week 1) so it's ready for onboarding and empty states
2. **Notification tone** — Custom sound? Default? A gentle "nudge" sound could reinforce the brand
3. **What happens at midnight?** — Do incomplete items auto-roll to tomorrow? Or require explicit action?
4. **Brain dump language support** — English-only for MVP? Speech-to-text supports many languages, but AI splitting prompt is English
5. **Pricing experiment** — Should we A/B test $6.99/mo vs $9.99/mo? Or just pick one and validate?
6. **Privacy policy** — Voice data stays on-device. AI only sees text transcript. Drafts generated via API but never auto-sent. Need clear privacy page for App Store. Explicitly state: "Nudge never reads your messages, calls, or contacts without you tapping a button"
7. **Name availability** — Is "Nudge" available on the App Store? Need to check and have backup names ready
8. **Draft liability** — If an AI draft sends something awkward (user didn't read carefully), is that on us? Mitigation: always show draft with "Edit" option prominent, add disclaimer in onboarding: "Always review before sending"
9. **User's name for drafts** — AI drafts sign off with user's name. Ask for first name during onboarding (optional, single field, no account needed) or leave unsigned
10. **Penguin character design** — Commission an illustrator or design in-house? Need 5-6 expression states as vector assets. Budget: ~$200-500 for a freelance illustrator on Fiverr/99designs. Alternative: design as SF Symbol-weight line art ourselves in Figma
11. **Penguin naming** — Should the penguin have an official name in marketing (e.g., "Nudgy")? Or remain unnamed and let users project personality onto it? Unnamed = more universal, named = more memeable
12. **Live Activity adoption risk** — If <5% of users enable Live Activity, is it worth the maintenance burden? Monitor opt-in rate in Month 1. If negligible, deprioritize updates
13. **Accessibility beta testers** — Should we recruit 2-3 VoiceOver users for the TestFlight beta specifically? Would dramatically improve accessibility quality. Check: r/blind, r/iOSAccessibility
14. **App Store featuring timing** — Submit Featuring Nomination 3 months pre-launch? Or wait until we have 4.5+ rating and strong retention data? Apple's page says "submit well ahead of time." Recommend: submit nomination during TestFlight phase with early screenshots + penguin story
15. **Custom sound creation** — Commission a sound designer for the 4 audio cues ($100-300 on Fiverr)? Or design ourselves using GarageBand / Logic? Professional sounds are a cheap differentiator

---

*This is a living document. Update it as decisions are made and features ship.*
