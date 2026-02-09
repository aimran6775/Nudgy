//
//  Constants.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftUI

// MARK: - Design Tokens

enum DesignTokens {
    
    // MARK: Colors
    
    /// Pure black OLED canvas — app background
    static let canvas = Color.black
    
    /// Dark translucent card surface
    static let cardSurface = Color(hex: "1C1C1E")
    
    /// Card border color (before accent tinting)
    static let cardBorder = Color(hex: "2C2C2E")
    
    /// Card surface opacity
    static let cardOpacity: Double = 0.80
    
    /// Card border width
    static let cardBorderWidth: CGFloat = 0.5
    
    // MARK: Text Colors
    
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8E8E93")
    static let textTertiary = Color(hex: "636366")
    
    // MARK: Accent Colors (Status-Driven)
    
    /// Active / interactive — task ready for action
    static let accentActive = Color(hex: "007AFF")
    
    /// Complete / success — done state
    static let accentComplete = Color(hex: "30D158")
    
    /// Stale — item aging 3+ days
    static let accentStale = Color(hex: "FF9F0A")
    
    /// Overdue — urgent items
    static let accentOverdue = Color(hex: "FF453A")
    
    // MARK: Spacing (4pt grid)
    
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 24
    static let spacingXXL: CGFloat = 32
    static let spacingXXXL: CGFloat = 48
    
    // MARK: Corner Radii
    
    static let cornerRadiusCard: CGFloat = 16
    static let cornerRadiusButton: CGFloat = 12
    static let cornerRadiusChip: CGFloat = 8
    
    // MARK: Sizing
    
    static let penguinSizeHero: CGFloat = 240   // Central character on main screen
    static let penguinSizeLarge: CGFloat = 120
    static let penguinSizeMedium: CGFloat = 80
    static let penguinSizeSmall: CGFloat = 40
}

// MARK: - Free Tier Limits

enum FreeTierLimits {
    static let maxDailyBrainDumps = 3
    static let maxSavedItems = 5
    
    // Aliases used by AppSettings
    static let brainDumpsPerDay = maxDailyBrainDumps
    static let savedItems = maxSavedItems
}

// MARK: - Recording

nonisolated enum RecordingConfig {
    /// Max brain dump duration in seconds (Apple SFSpeechRecognizer limit workaround)
    static let maxDuration: TimeInterval = 55
    
    /// Countdown warning threshold (show timer in last N seconds)
    static let countdownThreshold: TimeInterval = 10
}

// MARK: - Notifications

enum NotificationConfig {
    static let maxDailyNudges = 3
    static let defaultQuietHoursStart = 21 // 9pm
    static let defaultQuietHoursEnd = 8    // 8am
    static let staleThresholdDays = 3
}

// MARK: - StoreKit Product IDs

nonisolated enum StoreKitProducts {
    static let proMonthly = "com.nudge.pro.monthly"
    static let proYearly = "com.nudge.pro.yearly"
    static let allProducts = [proMonthly, proYearly]
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
