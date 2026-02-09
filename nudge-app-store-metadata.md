# Nudge — App Store Metadata

> Ready to paste into App Store Connect

## Identity

| Field | Value |
|---|---|
| **Bundle ID** | `com.nudge.app` |
| **SKU** | `NUDGE001` |
| **Version** | 1.0.0 |
| **Build** | 1 |
| **Category** | Productivity |
| **Age Rating** | 4+ |
| **Pricing** | Free with In-App Purchases |

## Name & Subtitle

**Title:** Nudge — ADHD Brain Dump & Tasks

**Subtitle:** One thing at a time. Voice to action.

## Keywords

```
ADHD, brain dump, task manager, ADHD planner, voice tasks, ADHD app, productivity, reminders, focus, to do
```

## Description

Your brain is a monsoon of thoughts, reminders, half-ideas, and "I should do that later"s. Nudge catches them all.

**TAP THE MIC. BRAIN DUMP EVERYTHING.**
Speak your mind for up to 55 seconds. Our AI splits your stream of consciousness into bite-sized task cards — one for "call the dentist," one for "buy dog food," one for "reply to Sarah about Saturday." Done.

**ONE THING AT A TIME.**
No overwhelming lists. No 47-item to-do apps that make you feel worse. Nudge shows you ONE card. Handle it. Swipe right to complete. Swipe left to snooze. Move on to the next. That's it.

**SHARE ANYTHING, SEE IT LATER.**
See a recipe on Instagram? A link in iMessage? Share it to Nudge, pick when you want to be reminded, and forget about it. We'll knock on your brain at exactly the right time.

**MEET YOUR PENGUIN.**
Every nudge comes with a companion — a tiny penguin that celebrates your wins, naps when your brain is clear, and gently nudges you when things get stale.

**BUILT FOR ADHD BRAINS:**
• Voice-first: talk, don't type
• Anti-list: see one task, not fifty
• Smart reminders: gentle nudges, not guilt trips
• Quick actions: call, text, email, or open links from any card
• Quiet hours: no buzzes when you're recharging
• Dark mode only: easy on the eyes, stunning on OLED
• 100% private: voice stays on-device, tasks stay on your phone

**NUDGE PRO** unlocks:
• Unlimited brain dumps (Free: 3 per day)
• AI-drafted replies for email, text, and messages
• Lock Screen Live Activity for your current task
• Smart notification buttons (call, text, open link)
• Unlimited saved items from Share Extension

$9.99/month or $59.99/year (save 50%)

Your brain is not broken. It just needs a better system. Nudge is that system.

## Promotional Text

New: Brain dump your thoughts by voice — AI splits them into action cards. One thing at a time.

## Privacy Nutrition Labels

| Data Type | Collection | Purpose |
|---|---|---|
| Voice Data | Not collected | Processed on-device only via Apple SFSpeechRecognizer |
| Task Content | Used by app | Sent to OpenAI API for task splitting (not stored on servers) |
| Purchase History | Used by app | StoreKit 2 manages subscription state |
| Contacts | Used by app | Optional — used for quick call/text actions |

## In-App Purchases

| Product ID | Type | Price | Display Name |
|---|---|---|---|
| `com.nudge.pro.monthly` | Auto-Renewable Subscription | $9.99/mo | Nudge Pro Monthly |
| `com.nudge.pro.yearly` | Auto-Renewable Subscription | $59.99/yr | Nudge Pro Yearly |

**Subscription Group:** Nudge Pro

## App Review Notes

Nudge is a task management app designed for people with ADHD. The core flow:

1. User taps the microphone and speaks (e.g., "I need to call the dentist, buy dog food, and reply to Sarah about Saturday")
2. On-device speech recognition converts voice to text
3. Text is sent to OpenAI's GPT-4o-mini API to split into individual tasks with emoji and action type detection
4. Tasks appear as swipeable cards — one at a time
5. User swipes right (done), left (snooze), or down (skip)

The app uses:
- SFSpeechRecognizer (on-device, iOS 17+)
- OpenAI API for task splitting only (no personal data stored)
- StoreKit 2 for subscriptions
- ActivityKit for optional Lock Screen widget
- UNUserNotificationCenter for reminders
- Share Extension for saving content from other apps

Test account credentials: N/A (no sign-in required)

## Screenshot Screens (capture these)

1. **One-Thing View** — Single task card with penguin below, dark background
2. **Brain Dump** — Mic button with waveform visualization, penguin thinking
3. **Task Cards** — Card with action button (📞 Call Dr. Chen), swipe hints
4. **Empty State** — Sleeping penguin, "Your brain is clear" message
5. **All Items** — List view with sections (Up Next, Snoozed, Done Today)
6. **Share Extension** — Dark share sheet saving a link with snooze time picker
7. **Settings / Paywall** — Pro upgrade comparison

Devices: iPhone 15 Pro Max (6.7"), iPhone 14 (6.1")

## Apple Featuring Nomination

**Why Nudge deserves featuring:**

1. **Mission-driven:** Built specifically for the 30M+ adults with ADHD who feel overwhelmed by traditional task apps
2. **Technical showcase:** Native SwiftUI + SwiftData + SFSpeechRecognizer + ActivityKit + TipKit + StoreKit 2 + @Observable — uses every modern Apple framework
3. **Original character:** Hand-crafted penguin mascot with 6 expressions, drawn entirely in SwiftUI shapes (no image assets)
4. **Accessibility-first:** Full VoiceOver support, Dynamic Type at all sizes, Reduce Motion fallbacks, comprehensive accessibility labeling
5. **Design craft:** Pure black OLED canvas, time-aware accent colors, spring physics everywhere, custom sound design
6. **Privacy-respecting:** Voice processing stays on-device, no account required, no tracking
