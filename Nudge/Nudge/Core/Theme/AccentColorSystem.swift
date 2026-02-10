//
//  AccentColorSystem.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftUI
import Combine

// MARK: - Accent Color System

/// Dynamic accent color engine that provides:
/// 1. Status-driven colors (blue, green, amber, red) based on task state
/// 2. Time-aware hue shift — the blue accent subtly shifts through the day
///    to combat time-blindness (±15° on the color wheel from base #007AFF)
@Observable
final class AccentColorSystem {
    
    // MARK: - Singleton
    
    static let shared = AccentColorSystem()
    
    // MARK: - Properties
    
    /// The current time-aware accent blue (shifts throughout the day)
    private(set) var currentAccentBlue: Color = DesignTokens.accentActive
    
    /// Base hue for system blue (#007AFF) in SwiftUI's 0-1 hue space
    /// #007AFF ≈ hue 0.583, saturation 1.0, brightness 1.0
    private let baseHue: Double = 0.583
    private let baseSaturation: Double = 0.85
    private let baseBrightness: Double = 1.0
    
    /// Maximum hue shift in either direction (±15° = ±0.042 in 0-1 space)
    private let maxHueShift: Double = 0.042
    
    // MARK: - Init
    
    private init() {
        updateTimeAwareAccent()
    }
    
    // MARK: - Status Colors (Static)
    
    /// Returns the accent color for a given item status
    func color(for status: AccentStatus) -> Color {
        switch status {
        case .active:
            return currentAccentBlue
        case .complete:
            return DesignTokens.accentComplete
        case .stale:
            return DesignTokens.accentStale
        case .overdue:
            return DesignTokens.accentOverdue
        }
    }
    
    /// Returns a hex string for the accent color (used by Live Activity widget)
    func hexString(for status: AccentStatus) -> String {
        switch status {
        case .active:   return "0A84FF"
        case .complete: return "30D158"
        case .stale:    return "FFD60A"
        case .overdue:  return "FF453A"
        }
    }
    
    // MARK: - Time-Aware Hue Shift
    
    /// Call this every ~5 minutes to update the accent blue based on time of day.
    /// The shift is intentionally subtle — users should feel it subconsciously,
    /// not notice it consciously.
    ///
    /// Morning (6am): cool blue-cyan (hue shifts negative / toward cyan)
    /// Midday (12pm): neutral blue (base hue, no shift)
    /// Evening (6pm): warmer blue-indigo (hue shifts positive / toward purple)
    /// Night (12am): back to neutral
    func updateTimeAwareAccent() {
        let hour = Calendar.current.component(.hour, from: Date())
        let minute = Calendar.current.component(.minute, from: Date())
        let fractionalHour = Double(hour) + Double(minute) / 60.0
        
        // Sine wave centered at noon, one full cycle per 24 hours
        // At 6am → sin(-π/2) = -1 → max cool shift (toward cyan)
        // At 12pm → sin(0) = 0 → no shift (base blue)
        // At 6pm → sin(π/2) = 1 → max warm shift (toward indigo)
        // At 12am → sin(π) = 0 → no shift
        let phase = (fractionalHour - 6.0) / 24.0 * 2.0 * .pi
        let shift = sin(phase) * maxHueShift
        
        let adjustedHue = baseHue + shift
        currentAccentBlue = Color(
            hue: adjustedHue,
            saturation: baseSaturation,
            brightness: baseBrightness
        )
    }
}

// MARK: - Accent Status

enum AccentStatus {
    case active   // Blue — ready for action
    case complete // Green — done
    case stale    // Amber — 3+ days untouched
    case overdue  // Red — past due
}

// MARK: - TimelineView Wrapper for Auto-Update

/// Wraps any view to automatically update the accent color every 5 minutes.
/// Use this at the root of your view hierarchy.
struct TimeAwareAccentWrapper<Content: View>: View {
    var accentSystem = AccentColorSystem.shared
    let content: () -> Content
    
    let timer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        content()
            .onReceive(timer) { _ in
                accentSystem.updateTimeAwareAccent()
            }
    }
}
