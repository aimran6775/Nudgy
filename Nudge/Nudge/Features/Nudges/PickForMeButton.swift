//
//  PickForMeButton.swift
//  Nudge
//
//  "Pick For Me" — a decision paralysis killer for ADHD brains.
//
//  ADHD research backing:
//  • Decision paralysis is the #1 barrier to starting (Barkley, 2012)
//  • The "Wall of Awful" prevents initiating even easy tasks (Dodson, 2022)
//  • Removing the decision = removing the barrier to action
//  • Randomness adds playfulness → dopamine hit → motivation (Volkow et al., 2009)
//
//  UX: Floating button → tap → slot-machine spin → lands on a task → focus card.
//

import SwiftUI

// MARK: - Pick For Me Button

/// A floating action button that picks a random task from the Today group.
/// Shown when there are 2+ items in Today (picking from 1 item isn't useful).
struct PickForMeButton: View {
    
    let onPick: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var wigglePhase: Double = 0
    
    var body: some View {
        Button {
            HapticService.shared.actionButtonTap()
            onPick()
        } label: {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .rotationEffect(.degrees(reduceMotion ? 0 : sin(wigglePhase) * 3))
                
                Text(String(localized: "Pick for me"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingMD)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "5E5CE6"),
                                DesignTokens.accentActive
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: DesignTokens.accentActive.opacity(0.4), radius: 12, y: 4)
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.2)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                wigglePhase = .pi * 2
            }
        }
        .nudgeAccessibility(
            label: String(localized: "Pick a random task for me"),
            hint: String(localized: "Randomly selects a task from your Today list"),
            traits: .isButton
        )
    }
}

// MARK: - Picked Task Card (Focus Overlay)

/// The focus card that appears after "Pick For Me" selects a task.
/// Shows the picked task prominently with action buttons.
struct PickedTaskCard: View {
    
    let item: NudgeItem
    var onDone: () -> Void
    var onSnooze: () -> Void
    var onStartFocus: () -> Void
    var onDismiss: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var glowPhase: CGFloat = 0
    
    var body: some View {
            // Focus card (dimmed background handled by parent for hero morph)
            VStack(spacing: DesignTokens.spacingXL) {
                // Nudgy says
                HStack(spacing: DesignTokens.spacingSM) {
                    Image("NudgyMascot")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    Text(pickMessage)
                        .font(AppTheme.footnote)
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DesignTokens.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
                
                // The picked task
                VStack(spacing: DesignTokens.spacingMD) {
                    TaskIconView(emoji: item.emoji, actionType: item.actionType, size: .large, accentColor: DesignTokens.accentActive)
                        .scaleEffect(appeared ? 1.0 : 0.3)
                        .opacity(appeared ? 1 : 0)
                    
                    Text(item.content)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .offset(y: appeared ? 0 : 10)
                        .opacity(appeared ? 1 : 0)
                    
                    if let contact = item.contactName, !contact.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 11))
                            Text(contact)
                                .font(AppTheme.footnote)
                        }
                        .foregroundStyle(DesignTokens.textSecondary)
                    }
                    
                    if item.isStale {
                        Text(String(localized: "\(item.ageInDays) days old — been here a while 🧊"))
                            .font(AppTheme.footnote)
                            .foregroundStyle(DesignTokens.accentStale)
                    }
                }
                .padding(.vertical, DesignTokens.spacingMD)
                
                // Action buttons
                VStack(spacing: DesignTokens.spacingSM) {
                    // Primary: Start focusing on this
                    Button {
                        onStartFocus()
                    } label: {
                        HStack(spacing: DesignTokens.spacingSM) {
                            Image(systemName: "scope")
                                .font(.system(size: 14, weight: .semibold))
                            Text(String(localized: "Focus on this"))
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(DesignTokens.accentActive)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Secondary row
                    HStack(spacing: DesignTokens.spacingSM) {
                        // Done
                        Button {
                            onDone()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                Text(String(localized: "Done"))
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(DesignTokens.accentComplete)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                Capsule()
                                    .fill(DesignTokens.accentComplete.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Snooze
                        Button {
                            onSnooze()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(String(localized: "Later"))
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(DesignTokens.accentStale)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                Capsule()
                                    .fill(DesignTokens.accentStale.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(DesignTokens.spacingXL)
            .background {
                // Accent glow visible through glass
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "5E5CE6").opacity(0.08 + glowPhase * 0.04),
                                DesignTokens.accentActive.opacity(0.04),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
            .shadow(color: Color(hex: "5E5CE6").opacity(0.15), radius: 24, y: 8)
            .padding(.horizontal, DesignTokens.spacingXL)
        .onAppear {
            withAnimation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.75)) {
                appeared = true
            }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                glowPhase = 1
            }
        }
        .nudgeAccessibilityElement(
            label: String(localized: "Nudgy picked: \(item.content)"),
            hint: String(localized: "Choose to focus, mark done, or snooze")
        )
    }
    
    // MARK: - Pick Messages
    
    private var pickMessage: String {
        // Use SmartPickEngine's contextual reason — already in Nudgy's voice
        SmartPickEngine.reason(for: item)
    }
}

// MARK: - Preview

#Preview("Pick For Me Button") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            PickForMeButton { }
                .padding(.bottom, 40)
        }
    }
    .preferredColorScheme(.dark)
}
