//
//  HapticService.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import UIKit

/// Centralized haptic engine. Pre-warms generators for zero-latency feedback.
/// Maps every PRD-defined interaction to its haptic pattern.
final class HapticService {
    
    static let shared = HapticService()
    
    // Pre-warmed generators (call prepare() to reduce first-fire latency)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    private init() {}
    
    /// Call on app launch to pre-warm all generators
    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        softImpact.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    // MARK: - Mapped Interactions (from PRD Haptic Design System)
    
    /// Swipe Done — satisfying "done" thud
    func swipeDone() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }
    
    /// Swipe Snooze — soft caution
    func swipeSnooze() {
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }
    
    /// Swipe Skip — quick, weightless tap
    func swipeSkip() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }
    
    /// Mic tap (start recording) — firm press
    func micStart() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }
    
    /// Mic tap (stop recording) — gentle release
    func micStop() {
        softImpact.impactOccurred()
        softImpact.prepare()
    }
    
    /// Card appears — subtle arrival
    func cardAppear() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }
    
    /// Snooze time selected — picker tick
    func snoozeTimeSelected() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
    
    /// Share saved — confirmed
    func shareSaved() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }
    
    /// Action button tap — intentional press
    func actionButtonTap() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }
    
    /// Error or limit hit — something's wrong
    func error() {
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }
}
