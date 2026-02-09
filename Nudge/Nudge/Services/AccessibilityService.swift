//
//  AccessibilityService.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftUI
import Combine

/// Monitors system accessibility settings and provides reactive access
/// so views can adapt to user preferences.
@Observable
final class AccessibilityService {
    
    static let shared = AccessibilityService()
    
    // MARK: - Observed Settings
    
    /// True when user has Reduce Motion enabled in Settings
    private(set) var reduceMotionEnabled: Bool
    
    /// True when user has Bold Text enabled
    private(set) var boldTextEnabled: Bool
    
    /// True when VoiceOver is running
    private(set) var voiceOverRunning: Bool
    
    /// True when user has Increase Contrast enabled
    private(set) var increaseContrastEnabled: Bool
    
    /// Current Dynamic Type content size category
    private(set) var contentSizeCategory: UIContentSizeCategory
    
    /// True if any accessibility Large Content Size is active (Accessibility1-5)
    var isAccessibilitySize: Bool {
        contentSizeCategory >= .accessibilityMedium
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Read initial values
        self.reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        self.boldTextEnabled = UIAccessibility.isBoldTextEnabled
        self.voiceOverRunning = UIAccessibility.isVoiceOverRunning
        self.increaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        self.contentSizeCategory = UIApplication.shared.preferredContentSizeCategory
        
        // Subscribe to change notifications
        observeChanges()
    }
    
    private func observeChanges() {
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIAccessibility.boldTextStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.boldTextEnabled = UIAccessibility.isBoldTextEnabled
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.voiceOverRunning = UIAccessibility.isVoiceOverRunning
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.increaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.contentSizeCategory = UIApplication.shared.preferredContentSizeCategory
            }
            .store(in: &cancellables)
    }
}
