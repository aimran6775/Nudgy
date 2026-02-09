//
//  NudgeTips.swift
//  Nudge
//
//  TipKit tip definitions — contextual hints that teach features.
//  Display frequency: monthly. Invalidated after first use of each feature.
//

import TipKit

// MARK: - Brain Dump Tip

/// Shows on empty One-Thing View: "Tap the mic to brain dump"
struct BrainDumpTip: Tip {
    
    /// Event: user has done at least one brain dump
    static let brainDumpCompleted = Event(id: "brainDumpCompleted")
    
    var title: Text {
        Text("Talk, don't type")
    }
    
    var message: Text? {
        Text("Tap the mic button to brain dump everything on your mind. AI splits it into tasks.")
    }
    
    var image: Image? {
        Image(systemName: "mic.fill")
    }
    
    var rules: [Rule] {
        #Rule(Self.brainDumpCompleted) {
            $0.donations.count == 0
        }
    }
}

// MARK: - Swipe Right Tip

/// Shows on first card interaction: "Swipe right to complete"
struct SwipeRightTip: Tip {
    
    static let swipeDoneCompleted = Event(id: "swipeDoneCompleted")
    
    var title: Text {
        Text("Swipe right to complete")
    }
    
    var message: Text? {
        Text("Done with this task? Swipe the card right. Swipe left to snooze for later.")
    }
    
    var image: Image? {
        Image(systemName: "hand.draw.fill")
    }
    
    var rules: [Rule] {
        #Rule(Self.swipeDoneCompleted) {
            $0.donations.count == 0
        }
    }
}

// MARK: - Share Tip

/// Shows after first brain dump: "Share from any app to save here"
struct ShareTip: Tip {
    
    static let shareCompleted = Event(id: "shareCompleted")
    static let firstBrainDumpDone = Event(id: "firstBrainDumpDoneForShare")
    
    var title: Text {
        Text("Share from any app")
    }
    
    var message: Text? {
        Text("Tap the share button in Safari, Twitter, or anywhere — save it to Nudge and pick when to be reminded.")
    }
    
    var image: Image? {
        Image(systemName: "square.and.arrow.up.fill")
    }
    
    var rules: [Rule] {
        #Rule(Self.firstBrainDumpDone) {
            $0.donations.count >= 1
        }
        #Rule(Self.shareCompleted) {
            $0.donations.count == 0
        }
    }
}

// MARK: - Live Activity Tip

/// Shows in Settings near the toggle: "Show your task on Lock Screen"
struct LiveActivityTip: Tip {
    
    static let liveActivityEnabled = Event(id: "liveActivityEnabled")
    
    var title: Text {
        Text("See your task on Lock Screen")
    }
    
    var message: Text? {
        Text("Enable Live Activity to keep your current task visible on your Lock Screen and Dynamic Island.")
    }
    
    var image: Image? {
        Image(systemName: "lock.rectangle.on.rectangle")
    }
    
    var rules: [Rule] {
        #Rule(Self.liveActivityEnabled) {
            $0.donations.count == 0
        }
    }
}
