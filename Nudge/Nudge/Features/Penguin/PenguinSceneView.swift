//
//  PenguinSceneView.swift
//  Nudge
//
//  The penguin scene — composes the penguin character + speech bubble +
//  task context overlay + interaction gestures into a single reusable unit.
//
//  This is the central character view that replaces the old "card + mascot"
//  layout. The penguin lives in the middle of the screen and the UI wraps
//  around it.
//
//  Usage:
//    PenguinSceneView(size: .hero)          // Main screen — full interactive
//    PenguinSceneView(size: .medium)        // Settings header, secondary screens
//    PenguinSceneView(size: .small)         // Inline decorative (list empty states)
//

import SwiftUI

// MARK: - Scene Size Preset

enum PenguinSceneSize {
    case hero       // 240pt — main screen, fully interactive
    case large      // 120pt — onboarding, paywall, brain dump
    case medium     //  80pt — settings header, secondary
    case small      //  40pt — inline, decorative
    
    var penguinSize: CGFloat {
        switch self {
        case .hero:   return DesignTokens.penguinSizeHero
        case .large:  return DesignTokens.penguinSizeLarge
        case .medium: return DesignTokens.penguinSizeMedium
        case .small:  return DesignTokens.penguinSizeSmall
        }
    }
    
    var showSpeechBubble: Bool {
        switch self {
        case .hero, .large: return true
        case .medium, .small: return false
        }
    }
    
    var isInteractive: Bool {
        self == .hero
    }
}

// MARK: - Penguin Scene View

struct PenguinSceneView: View {
    
    let size: PenguinSceneSize
    
    /// Optional override expression (if nil, reads from PenguinState environment)
    var expressionOverride: PenguinExpression?
    
    /// Optional override accent color
    var accentColorOverride: Color?
    
    /// Callback when penguin is tapped (hero mode)
    var onTap: (() -> Void)?
    
    /// Callback when chat bubble is tapped (hero mode)
    var onChatTap: (() -> Void)?
    
    @Environment(PenguinState.self) private var penguinState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var touchScale: CGFloat = 1.0
    
    private var activeExpression: PenguinExpression {
        expressionOverride ?? penguinState.expression
    }
    
    private var activeAccentColor: Color {
        accentColorOverride ?? penguinState.accentColor
    }
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            // Speech bubble (above penguin)
            if size.showSpeechBubble, let dialogue = penguinState.currentDialogue {
                SpeechBubbleView(
                    dialogue: dialogue,
                    maxWidth: size == .hero ? 280 : 220
                ) {
                    penguinState.dismissDialogue()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .bottom)))
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: dialogue)
            }
            
            // The penguin character
            // Uses NudgySprite (sprite animation engine with accessory overlays).
            // Falls back to PenguinMascot bezier when artist PNGs aren't available.
            VStack(spacing: DesignTokens.spacingXS) {
                NudgySprite(
                    expression: activeExpression,
                    size: size.penguinSize,
                    accentColor: activeAccentColor,
                    equippedAccessories: RewardService.shared.equippedAccessories,
                    useSpriteArt: false  // Flip to true when artist PNGs arrive
                )
                
                // "Nudgy" name label (hero/large only)
                if size == .hero || size == .large {
                    Text(String(localized: "Nudgy"))
                        .font(AppTheme.nudgyNameFont)
                        .foregroundStyle(DesignTokens.textTertiary.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(2.0)
                }
            }
            .scaleEffect(touchScale)
            .contentShape(Rectangle())  // Make entire frame tappable
            .onTapGesture {
                guard size.isInteractive else { return }
                
                // Bounce feedback
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    touchScale = 0.92
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1)) {
                    touchScale = 1.0
                }
                
                HapticService.shared.prepare()
                onTap?()
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.3)
                    .onChanged { _ in
                        guard size.isInteractive else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            touchScale = 0.9
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            touchScale = 1.0
                        }
                    }
            )
            
            // Task context strip (hero mode only, when presenting a task)
            if size == .hero, penguinState.interactionMode == .presentingTask {
                taskContextStrip
            }
        }
        .nudgeAccessibility(
            label: accessibilityLabel,
            hint: size.isInteractive
                ? String(localized: "Tap to interact with the penguin")
                : nil
        )
    }
    
    // MARK: - Chat FAB
    
    /// Small floating chat bubble near the penguin for discoverable chat access.
    private func chatFAB(action: @escaping () -> Void) -> some View {
        Button {
            HapticService.shared.prepare()
            action()
        } label: {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 14))
                .foregroundStyle(DesignTokens.accentActive)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(DesignTokens.cardSurface)
                        .overlay(
                            Circle()
                                .strokeBorder(DesignTokens.accentActive.opacity(0.3), lineWidth: 0.5)
                        )
                        .shadow(color: DesignTokens.accentActive.opacity(0.15), radius: 6, y: 2)
                )
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: String(localized: "Chat with Nudgy"),
            hint: String(localized: "Opens a conversation with your penguin assistant"),
            traits: .isButton
        )
    }
    
    // MARK: - Task Context Strip
    
    /// Shows the current task text below the penguin in a compact card.
    private var taskContextStrip: some View {
        VStack(spacing: DesignTokens.spacingXS) {
            // Queue position
            if let posText = penguinState.queuePositionText {
                Text(posText)
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            
            // Task content in a minimal card
            HStack(spacing: DesignTokens.spacingSM) {
                if let emoji = penguinState.currentTaskEmoji {
                    Text(emoji)
                        .font(.system(size: 20))
                }
                
                Text(penguinState.currentTaskContent ?? "")
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingMD)
            .frame(maxWidth: 300)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(DesignTokens.cardSurface.opacity(DesignTokens.cardOpacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                            .strokeBorder(activeAccentColor.opacity(0.3), lineWidth: DesignTokens.cardBorderWidth)
                    )
            )
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        var label = String(localized: "Nudgy the penguin")
        if let dialogue = penguinState.currentDialogue {
            label += ", " + String(localized: "saying: \(dialogue.text)")
        }
        if let task = penguinState.currentTaskContent {
            label += ", " + String(localized: "current task: \(task)")
        }
        return label
    }
}

// MARK: - Previews

#Preview("Hero — Presenting Task") {
    let state = PenguinState()
    state.presentTask(
        content: "Call the dentist",
        emoji: "📞",
        position: 1,
        total: 3,
        accentColor: DesignTokens.accentActive
    )
    state.say("Let's start with this one 👇")
    
    return ZStack {
        Color.black.ignoresSafeArea()
        PenguinSceneView(size: .hero)
    }
    .environment(state)
}

#Preview("Hero — All Clear") {
    let state = PenguinState()
    state.showAllClear(doneCount: 5)
    
    return ZStack {
        Color.black.ignoresSafeArea()
        PenguinSceneView(size: .hero)
    }
    .environment(state)
}

#Preview("Large — Thinking") {
    let state = PenguinState()
    state.startProcessing()
    
    return ZStack {
        Color.black.ignoresSafeArea()
        PenguinSceneView(size: .large)
    }
    .environment(state)
}

#Preview("Medium — Settings") {
    let state = PenguinState()
    
    return ZStack {
        Color.black.ignoresSafeArea()
        PenguinSceneView(size: .medium)
    }
    .environment(state)
}
