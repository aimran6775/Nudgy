# Nudge — Competitive Research & Apple API Integration Report

> Compiled Feb 2026. Focused on actionable features for Nudge's card-based, ADHD-friendly task UX.

---

## PART 1: APP-BY-APP COMPETITIVE ANALYSIS

---

### 1. TIIMO (tiimoapp.com)
**iPhone App of the Year 2025 · Apple Design Award Finalist 2024 · 3M+ downloads**

#### Card/Task UX
- **Color-coded visual timeline**: Each task is a colored block on a vertical timeline. Colors map to categories (work = blue, self-care = green, etc.). The timeline fills/progresses in real-time so you can see "where you are" in your day.
- **Drag-and-drop reordering**: Tasks can be repositioned on the timeline by dragging.
- **Card expansion**: Tapping a task card expands it inline to show duration, notes, and a start button. Collapsed state shows just icon + title + time.
- **Visual task icons**: Each task type gets a rounded icon (custom or emoji-based) making the schedule scannable without reading text.

#### Swipe Gestures
- **Swipe right → Complete**: Task card slides right with a green check animation.
- **Swipe left → Skip/Snooze**: Skips the current task or pushes it forward.
- **No destructive swipe** — deletion is buried in edit mode (ADHD-safe pattern: prevent accidental loss).

#### Category Organization
- **Activity categories** with assigned colors and icons (Morning Routine, Work, Exercise, etc.)
- **Routine templates**: Pre-built routines (Morning, Evening, Weekend) that auto-populate the timeline.
- **AI priority grouping**: Brain dump tasks, then AI categorizes and sequences them.

#### Apple Integrations
- ✅ Apple Calendar sync (2-way via EventKit)
- ✅ Apple Reminders sync
- ✅ Widgets (Home Screen + Lock Screen — shows current/next task with timer)
- ✅ Apple Watch app (shows current activity with countdown timer)
- ✅ VoiceOver, Voice Control, Larger Text, Dark Interface
- ✅ Family Sharing (up to 5 profiles)
- ❌ No Shortcuts/Siri integration noted
- ❌ No Live Activities/Dynamic Island
- ❌ No Focus Filters

#### ADHD-Specific Features
- **Time agnosia support**: Visual countdown timers on every task; timeline shows time passing in real-time
- **AI Co-Planner**: Conversational AI that helps plan/prioritize when executive function is low
- **Focus Timer**: Built-in calming countdown with visual progress
- **Neuroinclusive courses**: Expert guides on ADHD productivity
- **Community Hub**: Tips from neurodivergent users
- **Personal insights/stats**: Track task completion patterns over time
- **Co-designed with ADHD/Autism experts**

#### 🎯 Key Takeaway for Nudge
> Tiimo's **one-task-at-a-time focus timer view** is exactly the pattern Nudge should emulate. The color-coded timeline that shows "where you are in your day" prevents ADHD time blindness. Their AI Co-Planner for task prioritization parallels NudgyEngine perfectly.

---

### 2. THINGS 3 (culturedcode.com/things)
**2x Apple Design Award Winner · Vision Pro support · OS 26 ready**

#### Card/Task UX
- **Beautiful to-do cards**: Opening a to-do smoothly animates/transforms into a "clean white piece of paper." Additional fields (tags, checklist, dates, deadlines) are tucked away until needed.
- **Progress Pies**: Circular progress indicators on projects showing completion percentage.
- **Magic Plus button**: Draggable FAB that lets you insert a to-do at any position. Drag to left margin → creates a heading. Drag to Inbox target → sends to Inbox. "Liquid" button deforms shape during drag (OS 26).
- **Glassy, animated UI**: OS 26 update added glass buttons that glow and scale on touch, liquid deformation on drag.

#### Swipe Gestures
- **Swipe right → Reveal actions** (complete, schedule via Jump Start, move). Entering swipe mode also activates multi-select.
- **Swipe up/down on selection circles** → Super-fast multi-select of consecutive items.
- **Drag to reorder**: Multi-selected to-dos gather under your finger, drop into place with animation.
- **Two-finger swipe → Toggle Slim Mode** (collapse sidebar).

#### Category Organization
- **Areas** (top-level life categories like Work, Personal, Health) → contain **Projects** → contain **Headings** → contain **To-dos**.
- **Tags** for cross-cutting labels (Errands, People names). Quick Find detects tag searches.
- **Today / This Evening** split: "This Evening" is a discrete sub-list within Today for tasks you'll do later (e.g., when you get home).
- **Someday**: Parking lot for ideas not yet scheduled — prevents list overwhelm.
- **Headings within projects**: Visual grouping dividers; dragging a heading moves all its child to-dos.

#### Apple Integrations
- ✅ Calendar events displayed inline in Today view (EventKit read-only)
- ✅ Siri ("In Things, remind me to call John at 5 AM")
- ✅ Apple Shortcuts (native actions including new "Use Model" AI action in OS 26)
- ✅ Widgets (Home Screen, Lock Screen — multiple sizes, Dark/Tinted/Clear styles)
- ✅ Control Center buttons (New To-Do, jump to specific list)
- ✅ Lock Screen controls
- ✅ Apple Watch app (checklists, headings, new To-Do via swipe/type/talk)
- ✅ Handoff between Mac/iPhone/iPad
- ✅ Home Screen Quick Actions (3D Touch / long-press)
- ✅ Haptic Feedback throughout
- ✅ Spotlight integration (create to-dos from Spotlight on Mac)
- ✅ Writing Tools (AI proofreading/summarizing in notes)
- ✅ Dynamic Type support
- ✅ Vision Pro app + widgets
- ✅ Things Cloud (custom sync — rebuilt in Swift, 4x faster)
- ❌ No Live Activities
- ❌ No HealthKit integration

#### 🎯 Key Takeaways for Nudge
> - **Jump Start popover** is brilliant: one UI for Today, This Evening, schedule date, set reminder, or Someday. Nudge should have a similar "When?" flow for quick scheduling.
> - **Magic Plus drag-to-position** prevents the ADHD trap of "where does this go?" — the answer is "wherever you drop it."
> - **This Evening** concept is perfect for ADHD — separates "now tasks" from "later today tasks" without a full scheduling system.
> - **Control Center buttons + Lock Screen controls** are low-friction capture that Nudge should implement immediately.
> - **Multi-select via swipe on circles** — elegant batch operations pattern.

---

### 3. STRUCTURED (structured.app)
**15M+ downloads · 500K+ Pro users · 600K+ tasks daily**

#### Card/Task UX
- **Vertical timeline as core UI**: Tasks displayed as colored blocks on a continuous vertical timeline. Each block's height represents duration. Empty gaps show free time.
- **Calendar overlay**: Apple Calendar events merge into the same timeline alongside tasks — no separate calendar view needed.
- **Current-time indicator**: A "now" line moves down the timeline so you always see where you are in the day.
- **Task blocks are color-coded by category** with rounded edges and subtle shadows.

#### Swipe Gestures
- **Swipe to complete**: Left swipe marks task done with a satisfying animation.
- **Tap to expand**: Shows notes, subtasks, and editing options.
- **Drag to reschedule**: Long-press and drag a task block to a new time slot on the timeline.

#### Category Organization
- **Color-coded categories**: Each category (Work, Personal, Health, etc.) has an assigned color that paints the timeline blocks.
- **Custom icons per category**: Choose from a large icon library.
- **Inbox for unscheduled tasks**: Brain dump area for items not yet placed on timeline.

#### Apple Integrations
- ✅ Apple Calendar sync (events appear on timeline)
- ✅ Widgets (Home Screen + Lock Screen — shows timeline view)
- ✅ Apple Watch app (timeline on wrist)
- ✅ Apple Reminders integration
- ❌ Limited Shortcuts support
- ❌ No Live Activities
- ❌ No Control Center controls
- ❌ No Siri deep integration

#### ADHD-Specific Features
- **Visual time representation**: The timeline makes time concrete/visible (fights time agnosia)
- **Habit tracking**: Recurring tasks tracked with streak data
- **Focus timer**: Built-in Pomodoro-style timer per task
- **"Overwhelm reduction"**: Marketing specifically targets this — the single-timeline view prevents the "where do I start?" paralysis
- **Structured Pro**: Advanced features behind subscription

#### 🎯 Key Takeaways for Nudge
> - **Timeline with calendar overlay** is the gold standard for "see your whole day." Nudge's current card-at-a-time view is complementary — consider a timeline as an alternate view mode.
> - **Duration-based block height** makes time tangible. If Nudge adds duration estimates to tasks, blocks can be proportional.
> - **The "now" line** is a simple, powerful ADHD feature. Even on Nudge's card view, showing "this task started 12 min ago" grounds the user in time.

---

### 4. TODOIST (todoist.com)
**350K+ five-star reviews · 80+ integrations**

#### Card/Task UX
- **Minimal task rows**: Clean single-line task items with priority color dots (red p1, orange p2, blue p3, no color p4).
- **Quick Add with NLP**: Type "Call Mom tomorrow at 5pm #Personal p1" — parses date, project, priority automatically.
- **Three view modes per project**: List, Calendar (visual month/week), Board (Kanban columns).
- **Upcoming view**: Birds-eye schedule with drag-and-drop to reschedule.

#### Swipe Gestures
- **Swipe right → Complete**: Checkbox fills with priority color, task slides off with a subtle bounce.
- **Swipe left → Schedule**: Opens date picker inline.
- **Long-press → Drag to reorder** within a project.
- **Pull-down → Quick Add** in some views.

#### Category Organization
- **Projects** (with colors) → **Sections** within projects → **Sub-tasks** (nested hierarchy).
- **Labels** (cross-project tags with colors).
- **Filters** (custom smart views using query syntax: "overdue & #Work" etc.).
- **Favorites** sidebar section for pinned projects/filters.
- **Workspace separation**: Personal vs. Team projects visually separated.

#### Apple Integrations
- ✅ Siri integration
- ✅ Apple Watch (view + add tasks)
- ✅ Widgets (Home Screen)
- ✅ Shortcuts support
- ✅ Share Extension (share URLs/text as tasks)
- ✅ Calendar feed subscription (read-only, export tasks to Apple Calendar)
- ❌ No native Calendar read integration
- ❌ No Live Activities
- ❌ No Control Center controls

#### 🎯 Key Takeaways for Nudge
> - **NLP quick-add** is table stakes — Nudge's brain dump already does this but could add natural language date parsing.
> - **Swipe-left-to-schedule** is more useful than swipe-left-to-delete for ADHD users (reschedule > destroy).
> - **Kanban board view** could be powerful for Nudge's statuses (Active, Snoozed, Done) as swim lanes.
> - **Todoist Karma / productivity visualizations** gamify consistency — Nudge's penguin persona could tie into this.

---

### 5. TICKTICK (ticktick.com)
**Multi-platform · Habit + Task + Calendar unified**

#### Card/Task UX
- **Three-column desktop layout**: Lists | Tasks | Task Detail (with Markdown notes, images).
- **Calendar views**: Monthly, Weekly, Agenda, Multi-Day, Multi-Week — all showing tasks as time blocks.
- **Kanban board**: Drag tasks between columns.
- **Timeline view**: Gantt-chart-style view for project planning.

#### Swipe Gestures
- **Swipe right → Complete** with checkmark animation.
- **Swipe left → More actions** (schedule, move, delete).
- **Pin to Lock Screen** (iOS only) — persistent notification for current task.

#### Category Organization
- **Lists** (equivalent to projects) with colors and icons.
- **Smart Lists**: Today, Next 7 Days, All, Assigned to Me.
- **Tags** with nested tag hierarchy.
- **Filters**: Custom filtered views combining list + tag + date + priority.
- **Folders**: Group multiple lists into collapsible folders.

#### Apple Integrations
- ✅ Apple Calendar subscription sync
- ✅ Google Calendar 2-way sync
- ✅ Widgets (Home Screen — view + quick-add)
- ✅ Apple Watch app
- ✅ Siri voice add
- ✅ Location-based reminders (iOS geofencing via CoreLocation)
- ✅ Lock Screen pinned notifications
- ❌ No Shortcuts actions
- ❌ No Live Activities
- ❌ No Control Center

#### Unique Features
- **Eisenhower Matrix**: Built-in urgent/important quadrant view.
- **Habit Tracker**: Daily/weekly habits with streak tracking, check-in logs, and statistics.
- **Pomodoro Timer**: Focus timer with white noise options.
- **Constant Reminder**: Notifications keep ringing until you handle the task (opt-in, great for ADHD).
- **Daily Reminder**: Configurable "plan your day" notification at a set time.
- **Statistics dashboard**: Track tasks completed, focus duration, and habit logs.

#### 🎯 Key Takeaways for Nudge
> - **Eisenhower Matrix** is an interesting alternate view for ADHD prioritization — but may be too complex. Nudge's AI prioritization is better.
> - **"Constant Reminder" until handled** is an aggressive but useful ADHD feature. Nudge could offer "persistent nudge" mode for critical tasks.
> - **Habit tracking integration** alongside tasks is natural. Nudge's routines feature could incorporate streak tracking.
> - **Location-based reminders** via CoreLocation/geofencing — e.g., "buy milk" triggers when near grocery store.

---

### 6. NOTION CALENDAR (formerly Cron)
**Free · Mac/iOS/Android/Windows**

#### Calendar Display (No-Overlap Strategy)
- **Side-by-side calendar layering**: Multiple calendars displayed in parallel columns rather than overlapping. Each calendar gets its own visual lane.
- **Menu bar quick-glance**: Join meetings directly from macOS menu bar without opening the app.
- **Built-in scheduling links**: Share availability without a separate tool (like Calendly).
- **Drag-and-drop Notion database items**: Edit project timelines directly from calendar view.
- **Auto-block busy slots**: Cross-calendar conflict detection prevents double-booking.
- **Time zone visualization**: See your day across multiple time zones (for global teams).
- **Command menu + shortcuts**: Keyboard-driven efficiency for power users.

#### Apple Integrations
- ✅ Apple Calendar sync (create events directly)
- ✅ iOS/iPadOS app with widgets
- ✅ Google Calendar deep integration
- ✅ Notion workspace integration (see Notion DB items on calendar)
- ❌ No Apple Watch app
- ❌ No Siri/Shortcuts
- ❌ No Live Activities

#### 🎯 Key Takeaways for Nudge
> - **Side-by-side calendar lanes** prevent the visual chaos of overlapping events. If Nudge adds a timeline view, use parallel lanes for "Calendar Events" vs "Nudge Tasks."
> - **Auto-blocking busy slots** when syncing with Apple Calendar prevents scheduling tasks during meetings.
> - **Menu bar / persistent glance** pattern = Nudge's Live Activity already does this, but could extend to Apple Watch complications.

---

## PART 2: CROSS-APP PATTERN ANALYSIS

### Swipe Gesture Consensus

| Direction | Most Common Action | Visual Feedback | Nudge Recommendation |
|---|---|---|---|
| **→ Right** | Complete/Done | Green check, card slides off, haptic | ✅ Already implemented |
| **← Left** | Schedule/Snooze (NOT delete) | Date picker or snooze options appear | ⚠️ Nudge should use left-swipe for snooze, not delete |
| **↑ Up** | Not common on cards | — | Could use for "send to brain dump" |
| **↓ Down** | Pull to refresh / Quick Add | Stretchy pull animation | Pull-to-add-task in card stack |

### Card Expansion Patterns

| App | Expansion Style | Animation |
|---|---|---|
| Things 3 | Card transforms into full-page "paper" | Smooth morph, spring animation |
| Tiimo | Inline expansion below card | Push-down, other cards shift |
| Structured | Inline expansion | Accordion-style |
| Todoist | Navigate to detail view | Push navigation |

**Nudge Recommendation**: Use Things-style **morph transition** — the card expands into a detail view with a spring animation. This matches Nudge's "one card at a time" philosophy and `AnimationConstants` springs.

### Category Organization Hierarchy

| App | Hierarchy |
|---|---|
| Things 3 | Area → Project → Heading → To-do → Checklist item |
| Todoist | Project → Section → Task → Sub-task |
| TickTick | Folder → List → Task → Sub-task → Checklist |
| Tiimo | Category → Routine → Activity |
| Structured | Category → Task |

**Nudge Recommendation**: Keep it flat. ADHD users get lost in deep hierarchies. Use:
`Category (color+icon) → NudgeItem → Checklist` (max 2 levels)

---

## PART 3: APPLE API INTEGRATION OPPORTUNITIES

### Tier 1: High Impact, Implement Now

#### 1. App Intents + Shortcuts (iOS 16+)
**Framework**: `AppIntents`
**What it enables**:
- Siri voice commands: "Hey Siri, add a nudge to call Mom"
- Shortcuts actions: "Add Task", "Complete Task", "Show Today's Nudges", "Start Brain Dump"
- **App Shortcuts** (zero-config, appear automatically in Spotlight + Shortcuts app)
- **Action Button** support (iPhone 15 Pro+): Single press → Quick Add
- **Control Center controls** (iOS 18+): Button to add task or toggle focus
- **Lock Screen controls**: Quick-add without unlocking
- **Interactive Snippets**: Show task preview inline in Siri response
- **Focus Filters** (iOS 16+): Only show certain categories during Work Focus, hide work tasks during Personal Focus
- **Spotlight indexing**: Tasks searchable in system-wide Spotlight via `CSSearchableIndex` or `AppEntity` donation

**Nudge Implementation**:
```swift
// Example: App Shortcut for adding a nudge
struct AddNudgeIntent: AppIntent {
    static var title: LocalizedStringResource = "Add a Nudge"
    static var description = IntentDescription("Create a new task")
    
    @Parameter(title: "Title") var title: String
    @Parameter(title: "Category") var category: NudgeCategory?
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Create via NudgeRepository
        return .result(dialog: "Added: \(title)")
    }
}

struct NudgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddNudgeIntent(),
                    phrases: ["Add a nudge in \(.applicationName)",
                              "Create a task in \(.applicationName)"],
                    shortTitle: "Add Nudge",
                    systemImageName: "plus.circle")
    }
}
```

#### 2. EventKit — Calendar + Reminders (iOS 4+, enhanced iOS 17+)
**Framework**: `EventKit`, `EventKitUI`
**What it enables**:
- **Read calendar events**: Show today's calendar events alongside nudges (like Things 3's Today view)
- **Create events**: Block time for important nudges on the user's calendar
- **Read reminders**: Import from Apple Reminders as nudges
- **Create reminders**: Optionally sync nudges back as Reminders for cross-app visibility
- **Location-based reminders**: `EKStructuredLocation` with geofences — "remind me to buy groceries when I'm near the store"
- **Recurring events**: `EKRecurrenceRule` for repeating nudges
- **Change notifications**: `EKEventStoreDidChange` to stay synced when calendar changes externally

**Nudge Implementation Priority**:
1. Read calendar events → display in a "Your Day" timeline alongside nudge cards
2. Import from Reminders → one-time or ongoing sync
3. Location-based nudges → for `ActionType.errand` tasks
4. Time-block creation → "Block 30 min for this nudge" creates a calendar event

#### 3. WidgetKit — Enhanced Widgets (iOS 17+)
**Framework**: `WidgetKit`
**Already partially implemented** in `NudgeWidgetExtension`.
**Expand to**:
- **StandBy mode** (iOS 17): Large, glanceable widget when iPhone is on charger — show current/next nudge
- **Interactive widgets** (iOS 17): Complete/snooze buttons directly on widget without opening app
- **Multiple widget sizes**: Small (next nudge), Medium (today's top 3), Large (mini timeline)
- **Lock Screen widgets**: Circular (count of active nudges), Rectangular (next nudge title + time)
- **Smart Stack relevance**: Use `TimelineEntryRelevance` to surface widget when tasks are due
- **Widget configuration**: Let users choose which category/list to display via `AppIntentConfiguration`

#### 4. ActivityKit — Live Activities (iOS 16.1+)
**Framework**: `ActivityKit`
**Already partially implemented** in `NudgeLiveActivityWidget`.
**Expand to**:
- **Dynamic Island** (compact + expanded presentations)
- Show current task + elapsed time in compact view
- Expanded view: task title, category color, complete/snooze buttons
- **Lock Screen banner**: Persistent current-task display
- **Button interactions**: Complete/snooze directly from Dynamic Island
- **Push-based updates**: `ActivityKit push notifications` via APNs for remote task updates
- **Apple Watch Smart Stack**: Live Activities auto-appear on Watch (iOS 17+/watchOS 10+)
- **CarPlay Home Screen**: Show current nudge while driving
- **Mac Menu Bar**: Live Activity appears in menu bar (macOS 15+)

### Tier 2: Medium Impact, Implement Next

#### 5. Contacts Framework (iOS 9+)
**Framework**: `Contacts`
**What it enables for Nudge**:
- **Auto-resolve contact names** in tasks: "Call John" → lookup John's phone number → pre-fill for CALL action
- **Contact picker** for task assignment: Already using `.nudgeNeedsContactPicker` notification
- **Fetch contact photos** for task card avatars when task involves a person
- **Unified contacts**: Merges contacts across iCloud, Google, Exchange

**API Details**:
- `CNContactStore` for fetching (thread-safe, background-friendly)
- `CNContact.predicateForContacts(matchingName:)` for name search
- `CNContactFormatter` for proper name display
- Privacy: Requires `NSContactsUsageDescription` in Info.plist
- iOS 18: New `CNContactAccessButton` for limited contact access without full permission

#### 6. HealthKit (iOS 8+)
**Framework**: `HealthKit`
**What it enables**:
- **Mood check-in data** → write `HKStateOfMind` samples (iOS 17.2+) when user does mood check-ins
- **Mindful minutes** → write `HKCategoryTypeIdentifier.mindfulSession` when user completes a focus timer
- **Sleep data** → read sleep schedule to suggest quiet hours / optimal task windows
- **Activity data** → read step count to gamify "take a walk" nudges
- **Medication reminders** → read medication schedule to avoid scheduling demanding tasks during medication timing

**Nudge Implementation**:
- Write mindful minutes when focus timer completes
- Write mood samples from MoodCheckIn feature
- Read sleep data to auto-configure quiet hours
- Requires `NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription`

#### 7. MapKit + CoreLocation (iOS 17+)
**Framework**: `MapKit`, `CoreLocation`
- **Geofenced nudges**: Trigger notifications when entering/leaving locations
- **Location suggestions**: "You're near the grocery store — you have 'Buy milk' on your list"
- **CLMonitor** (iOS 17): Modern, battery-efficient geofencing API
- Works with `EKStructuredLocation` for EventKit integration

### Tier 3: Polish & Differentiation

#### 8. Handoff + Universal Links
- **Handoff** (NSUserActivity): Start viewing a nudge on iPhone, continue on iPad/Mac
- **Universal Links**: `https://nudge.app/task/{id}` opens directly in-app
- Already have deep link scheme (`nudge://viewTask?id=`), add web URL equivalents

#### 9. CallKit + MessageUI
- **CallKit**: Detect when a "CALL" action type nudge could be fulfilled — offer "Call Now" button
- **MessageUI** (`MFMessageComposeViewController`): Already using via `.nudgeComposeMessage` notification for TEXT action type. Ensure body prefill works.
- **MFMailComposeViewController**: For EMAIL action type nudges

#### 10. Focus Filters (iOS 16+)
**Framework**: `AppIntents` (SetFocusFilterIntent)
- When "Work" Focus is active → show only work-category nudges
- When "Personal" Focus → hide work nudges
- When "Sleep" Focus → suppress all nudge notifications
- Filter applies to widgets, notifications, and in-app content simultaneously

```swift
struct NudgeFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Nudge Filter"
    
    @Parameter(title: "Categories to show")
    var categories: [NudgeCategoryEntity]
    
    func perform() async throws -> some IntentResult {
        // Store filtered categories in AppSettings
        return .result()
    }
}
```

#### 11. Apple Watch App (watchOS 10+)
- **Complication**: Show active nudge count or next due task
- **Smart Stack widget**: Current task with complete/snooze buttons
- **Quick-add via dictation**: Capture tasks on the go
- **Haptic reminders**: Wrist tap when a nudge is due
- Uses shared App Group data or WatchConnectivity

---

## PART 4: PRIORITIZED FEATURE ROADMAP FOR NUDGE

### Phase 1: Foundation (Next Sprint)

| Feature | Inspired By | Apple API | Impact |
|---|---|---|---|
| **Swipe-left to Snooze** (not delete) | Tiimo, Things | SwiftUI gestures | High — ADHD-safe, prevents accidental deletion |
| **Calendar events in day view** | Things 3, Structured | EventKit | High — see whole day at a glance |
| **Interactive widgets** (complete/snooze) | Things 3 | WidgetKit + AppIntents | High — reduce app opens |
| **Control Center quick-add button** | Things 3 | AppIntents (Controls) | Medium — frictionless capture |
| **App Shortcuts** (voice add, brain dump) | Things 3 | AppIntents | Medium — accessibility + speed |

### Phase 2: Differentiation (Sprint +1)

| Feature | Inspired By | Apple API | Impact |
|---|---|---|---|
| **Focus Filters** | Concept | AppIntents | Medium — context-appropriate nudges |
| **Lock Screen widgets** (next nudge) | Tiimo, Structured | WidgetKit | Medium — constant awareness |
| **StandBy mode widget** | — | WidgetKit | Medium — nightstand/desk glance |
| **"This Evening" split** | Things 3 | App logic | High — ADHD "now vs later" clarity |
| **Spotlight task search** | Things 3 | AppIntents + CSSearchableIndex | Medium |
| **Location-based nudges** | TickTick | CoreLocation + CLMonitor | Medium — contextual reminders |

### Phase 3: Ecosystem (Sprint +2)

| Feature | Inspired By | Apple API | Impact |
|---|---|---|---|
| **Enhanced Live Activity** (Dynamic Island) | — | ActivityKit | High — persistent task awareness |
| **Apple Watch companion** | Tiimo, Things | WatchKit + WidgetKit | High — wrist capture + reminders |
| **HealthKit mood/mindful** | Tiimo insights | HealthKit | Low — wellness integration |
| **Handoff** | Things 3 | NSUserActivity | Low — multi-device continuity |
| **Contacts auto-resolve** | Internal need | Contacts framework | Medium — CALL/TEXT/EMAIL actions |
| **"Persistent Nudge" mode** | TickTick | UNNotificationRequest (repeating) | Medium — ADHD can't-miss reminders |

### Phase 4: Delight (Ongoing)

| Feature | Inspired By | Effort |
|---|---|---|
| **Time agnosia counter** on cards ("started 12 min ago") | Tiimo | Low |
| **Streak tracking** for recurring nudges | TickTick | Medium |
| **Completion animations** (penguin celebrates) | Nudge's own persona | Low |
| **AI day planning** ("Plan my day" generates timeline) | Tiimo AI Co-Planner | Medium (via NudgyEngine) |
| **Kanban board view** (Active/Snoozed/Done columns) | Todoist | Medium |
| **Calendar time-blocking** ("Block 30 min for this") | Notion Calendar | Medium (EventKit write) |

---

## PART 5: COMPETITIVE POSITIONING SUMMARY

| Feature | Tiimo | Things 3 | Structured | Todoist | TickTick | **Nudge (Target)** |
|---|---|---|---|---|---|---|
| ADHD-first design | ✅ | ❌ | Partial | ❌ | ❌ | **✅** |
| One-card-at-a-time | Partial | ❌ | ❌ | ❌ | ❌ | **✅** |
| AI task assistant | ✅ | Partial | ❌ | ❌ | ❌ | **✅ (on-device + cloud)** |
| Mascot/persona | ❌ | ❌ | ❌ | ❌ | ❌ | **✅ (Nudgy penguin)** |
| Visual timeline | ✅ | Partial | ✅ | ❌ | ✅ | Phase 2 |
| Live Activities | ❌ | ❌ | ❌ | ❌ | ❌ | **✅ (already built)** |
| Calendar sync | ✅ | Read-only | ✅ | Export only | Sub only | **Phase 1** |
| Apple Watch | ✅ | ✅ | ✅ | ✅ | ✅ | Phase 3 |
| Shortcuts/Siri | ❌ | ✅ | Partial | ✅ | Partial | **Phase 1** |
| Focus Filters | ❌ | ❌ | ❌ | ❌ | ❌ | **Phase 2** |
| Interactive Widgets | ❌ | ✅ | ❌ | ❌ | ❌ | **Phase 1** |
| Control Center | ❌ | ✅ | ❌ | ❌ | ❌ | **Phase 1** |
| Habit tracking | ❌ | ❌ | ✅ | ❌ | ✅ | Phase 3 |
| Location reminders | ❌ | ❌ | ❌ | ❌ | ✅ | Phase 2 |

### Nudge's Unique Advantages (No Competitor Has All Of These)
1. **On-device AI** via Apple Foundation Models (private, no cloud dependency)
2. **Mascot-driven motivation** (Nudgy penguin emotional feedback)
3. **Live Activities already built** (no major competitor has this)
4. **Share Extension** for capturing from any app
5. **ADHD-first + Apple-deep** = currently no app occupies this exact niche

---

*This research should drive the next 3-4 development sprints. Start with Phase 1 (EventKit + AppIntents + Interactive Widgets) as these have the highest user-visible impact with well-documented Apple APIs.*
