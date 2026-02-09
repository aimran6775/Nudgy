//
//  SwipeableRow.swift
//  Nudge
//
//  A lightweight swipe-to-action wrapper for card-style rows in a ScrollView.
//  Since .swipeActions only works inside List, this provides the same UX
//  for our LazyVStack-based layouts.
//
//  Swipe left  → trailing action (snooze, amber)
//  Swipe right → leading action  (done, green)
//
//  ADHD-friendly: full swipe triggers the action with haptic feedback,
//  reducing the number of taps needed. Partial swipe reveals the button.
//

import SwiftUI

struct SwipeableRow<Content: View>: View {
    
    @ViewBuilder let content: () -> Content
    
    /// Action triggered on full swipe right (leading)
    var onSwipeLeading: (() -> Void)?
    var leadingLabel: String = "Done"
    var leadingIcon: String = "checkmark"
    var leadingColor: Color = DesignTokens.accentComplete
    
    /// Action triggered on full swipe left (trailing)
    var onSwipeTrailing: (() -> Void)?
    var trailingLabel: String = "Snooze"
    var trailingIcon: String = "clock.fill"
    var trailingColor: Color = DesignTokens.accentStale
    
    @State private var offset: CGFloat = 0
    @State private var activeSwipe: SwipeDirection = .none
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let triggerThreshold: CGFloat = 100
    private let buttonRevealWidth: CGFloat = 70
    
    private enum SwipeDirection {
        case none, leading, trailing
    }
    
    var body: some View {
        ZStack {
            // Background action indicators
            HStack(spacing: 0) {
                // Leading (swipe right) — Done
                if onSwipeLeading != nil {
                    HStack(spacing: 6) {
                        Spacer()
                        Image(systemName: leadingIcon)
                            .font(.system(size: 14, weight: .bold))
                        if offset > triggerThreshold * 0.6 {
                            Text(leadingLabel)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: max(0, offset))
                    .background(leadingColor.opacity(min(1, offset / triggerThreshold)))
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: DesignTokens.cornerRadiusCard,
                            bottomLeadingRadius: DesignTokens.cornerRadiusCard
                        )
                    )
                }
                
                Spacer()
                
                // Trailing (swipe left) — Snooze
                if onSwipeTrailing != nil {
                    HStack(spacing: 6) {
                        if -offset > triggerThreshold * 0.6 {
                            Text(trailingLabel)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Image(systemName: trailingIcon)
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .frame(width: max(0, -offset))
                    .background(trailingColor.opacity(min(1, -offset / triggerThreshold)))
                    .clipShape(
                        UnevenRoundedRectangle(
                            bottomTrailingRadius: DesignTokens.cornerRadiusCard,
                            topTrailingRadius: DesignTokens.cornerRadiusCard
                        )
                    )
                }
            }
            
            // Main content
            content()
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let translation = value.translation.width
                            
                            // Only allow swipe in directions that have actions
                            if translation > 0 && onSwipeLeading == nil { return }
                            if translation < 0 && onSwipeTrailing == nil { return }
                            
                            // Apply rubber-band resistance past the threshold
                            if abs(translation) > triggerThreshold {
                                let excess = abs(translation) - triggerThreshold
                                let dampened = triggerThreshold + excess * 0.3
                                offset = translation > 0 ? dampened : -dampened
                            } else {
                                offset = translation
                            }
                            
                            // Track direction
                            activeSwipe = translation > 0 ? .leading : (translation < 0 ? .trailing : .none)
                            
                            // Haptic at threshold crossing
                            if abs(translation) > triggerThreshold - 2 && abs(translation) < triggerThreshold + 5 {
                                HapticService.shared.prepare()
                            }
                        }
                        .onEnded { value in
                            let translation = value.translation.width
                            
                            if translation > triggerThreshold, let action = onSwipeLeading {
                                // Full swipe right — trigger leading action
                                HapticService.shared.swipeDone()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    offset = 0
                                }
                                action()
                            } else if translation < -triggerThreshold, let action = onSwipeTrailing {
                                // Full swipe left — trigger trailing action
                                HapticService.shared.prepare()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    offset = 0
                                }
                                action()
                            } else {
                                // Snap back
                                withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8)) {
                                    offset = 0
                                }
                            }
                            
                            activeSwipe = .none
                        }
                )
        }
        .clipped()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            SwipeableRow(
                content: {
                    HStack {
                        Text("📬 Email Sarah about meeting")
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "1C1C1E")))
                },
                onSwipeLeading: { print("Done!") },
                onSwipeTrailing: { print("Snooze!") }
            )
            
            SwipeableRow(
                content: {
                    HStack {
                        Text("🐶 Buy dog food")
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "1C1C1E")))
                },
                onSwipeLeading: { print("Done!") }
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
