# Nudge — Xcode Setup Checklist

> Complete these steps in Xcode to get the project compiling and ready to ship.

## 🔧 Prerequisites

- [ ] Xcode 15.2+ installed
- [ ] Apple Developer account (paid, $99/yr)
- [ ] iOS 17+ iPhone for testing

## 📁 Step 1: Add Files to Project

Open `Nudge.xcodeproj` in Xcode, then drag these folders into the Project Navigator (ensure "Create groups" is selected and target "Nudge" is checked):

```
Nudge/
├── Core/
│   ├── Constants.swift
│   ├── Theme/
│   │   ├── AppTheme.swift
│   │   ├── AnimationConstants.swift
│   │   ├── AccentColorSystem.swift
│   │   ├── DarkCard.swift
│   │   ├── PenguinMascot.swift
│   │   └── CompletionParticles.swift
│   ├── Accessibility/
│   │   ├── DynamicTypeModifiers.swift
│   │   └── VoiceOverHelpers.swift
│   ├── Extensions/
│   │   └── Extensions.swift
│   └── Tips/
│       └── NudgeTips.swift
├── Models/
│   ├── NudgeItem.swift
│   ├── BrainDump.swift
│   └── AppSettings.swift
├── Services/
│   ├── NudgeRepository.swift
│   ├── HapticService.swift
│   ├── SoundService.swift
│   ├── SoundGenerator.swift
│   ├── AccessibilityService.swift
│   ├── SpeechService.swift
│   ├── AIService.swift
│   ├── NotificationService.swift
│   ├── DraftService.swift
│   ├── ActionService.swift
│   ├── ContactService.swift
│   └── PurchaseService.swift
├── Features/
│   ├── OneThing/
│   │   ├── OneThingView.swift
│   │   └── CardView.swift
│   ├── BrainDump/
│   │   ├── BrainDumpView.swift
│   │   └── BrainDumpViewModel.swift
│   ├── AllItems/
│   │   ├── AllItemsView.swift
│   │   └── ItemRowView.swift
│   ├── Snooze/
│   │   └── SnoozePickerView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── PaywallView.swift
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   └── LiveActivity/
│       └── NudgeLiveActivity.swift
├── ContentView.swift
└── NudgeApp.swift
```

Share Extension files (target: **NudgeShareExtension**):
```
NudgeShareExtension/
├── ShareViewController.swift
├── ShareExtensionView.swift
├── NudgeShareExtension.entitlements
└── Info.plist
```

Widget Extension files (target: **NudgeWidgetExtension**):
```
NudgeWidgetExtension/
├── NudgeWidgetBundle.swift
└── NudgeLiveActivityWidget.swift
```

- [ ] Delete `Item.swift` from the project navigator if it still shows (file is already removed from disk)

## 🔑 Step 2: Create Secrets.xcconfig

1. Create a new file: `Nudge/Secrets.xcconfig`
2. Add your OpenAI API key:
   ```
   OPENAI_API_KEY = sk-your-key-here
   ```
3. In Xcode → Project → Info → Configurations:
   - Set Debug & Release to use `Secrets.xcconfig`
4. Add to Info.plist (or build settings):
   ```xml
   <key>OPENAI_API_KEY</key>
   <string>$(OPENAI_API_KEY)</string>
   ```
5. **Add `Secrets.xcconfig` to `.gitignore`** — never commit API keys!

⚠️ **IMPORTANT:** If you previously exposed an API key in code, REVOKE it at https://platform.openai.com/api-keys and generate a new one.

## 🏷 Step 3: Configure Signing & Capabilities

1. Select the Nudge target → Signing & Capabilities
2. Set Team to your Apple Developer account
3. Set Bundle Identifier to `com.nudge.app`
4. Add capabilities:
   - [ ] **App Groups** → `group.com.nudge.app`
   - [ ] **Push Notifications** (for UNUserNotificationCenter)
   - [ ] **Background Modes** → check "Remote notifications"
   - [ ] **Speech Recognition** (already in Info.plist)

## 📱 Step 4: Create Share Extension Target

1. File → New → Target → **Share Extension**
2. Name: `NudgeShareExtension`
3. Bundle ID: `com.nudge.app.share-extension`
4. Language: Swift
5. After creation:
   - **Delete** all generated files (ShareViewController.swift, storyboard, Info.plist)
   - Add these pre-built files to the NudgeShareExtension target:
     - `NudgeShareExtension/ShareViewController.swift`
     - `NudgeShareExtension/ShareExtensionView.swift`
   - Use the pre-built `NudgeShareExtension/Info.plist` (already configured with `NSExtensionPrincipalClass`)
   - Use the pre-built `NudgeShareExtension/NudgeShareExtension.entitlements`
   - Add `App Groups` capability → `group.com.nudge.app`

## 🔴 Step 5: Create App Group

1. Go to https://developer.apple.com → Certificates, Identifiers & Profiles
2. Register App Group: `group.com.nudge.app`
3. Add it to both the main app and share extension provisioning profiles

## 💰 Step 6: Configure StoreKit

### For Testing (Sandbox):
1. Create a StoreKit Configuration file:
   - File → New → File → StoreKit Configuration File
   - Name: `NudgeProducts.storekit`
   - Add products:
     - `com.nudge.pro.monthly` — Auto-Renewable Subscription, $9.99
     - `com.nudge.pro.yearly` — Auto-Renewable Subscription, $59.99
   - Create Subscription Group: "Nudge Pro"
2. In scheme → Run → Options → StoreKit Configuration → select `NudgeProducts.storekit`

### For Production:
1. In App Store Connect → My Apps → Nudge → In-App Purchases
2. Create the same two subscription products
3. Create Subscription Group "Nudge Pro"
4. Submit for review with the app

## 🏠 Step 7: Create Widget Extension Target (Live Activity)

Live Activities on Lock Screen + Dynamic Island **require** a Widget Extension target.

1. File → New → Target → **Widget Extension**
2. Name: `NudgeWidgetExtension`
3. Bundle ID: `com.nudge.app.widget`
4. ☑ Include Live Activity (check this box!)
5. Uncheck "Include Configuration App Intent" (not needed)
6. After creation:
   - **Delete** all generated files in the `NudgeWidgetExtension/` group
   - Add these files to the **NudgeWidgetExtension** target:
     - `NudgeWidgetExtension/NudgeWidgetBundle.swift`
     - `NudgeWidgetExtension/NudgeLiveActivityWidget.swift`
   - The widget has its own copy of `NudgeActivityAttributes`, `TimeOfDay`, and `Color(hex:)` so it compiles independently (widget extensions cannot import the main app module)
7. Ensure the main app's Info.plist has:
   ```xml
   <key>NSSupportsLiveActivities</key>
   <true/>
   ```

## 🧪 Step 8: Build & Test

1. Select an iPhone 15 Pro simulator (or physical device)
2. Build (⌘B) — fix any remaining issues
3. Run (⌘R) — verify:
   - [ ] App launches to onboarding (first run)
   - [ ] Onboarding completes → empty state with sleeping penguin
   - [ ] Brain dump flow works (mic → speech → cards)
   - [ ] Cards swipe correctly (done/snooze/skip)
   - [ ] Settings screen renders
   - [ ] VoiceOver works on all screens
   - [ ] Dynamic Type scales properly at all sizes

## 🚀 Step 9: Archive & Upload

1. Select "Any iOS Device" as destination
2. Product → Archive
3. Distribute App → App Store Connect
4. Upload
5. Go to App Store Connect → TestFlight → send to internal testers

## 📋 Quick Reference

| Item | Value |
|---|---|
| Deployment Target | iOS 17.0 |
| Swift Version | 5.9 |
| Main Framework | SwiftUI + SwiftData |
| Third-party Dependencies | None |
| Bundle ID (Main) | `com.nudge.app` |
| Bundle ID (Share Extension) | `com.nudge.app.share-extension` |
| Bundle ID (Widget Extension) | `com.nudge.app.widget` |
| App Group | `group.com.nudge.app` |
| StoreKit Products | `com.nudge.pro.monthly`, `com.nudge.pro.yearly` |
