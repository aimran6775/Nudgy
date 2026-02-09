//
//  NudgySpeechBubble.swift
//  Nudge
//
//  Speech bubble component for Nudgy the penguin.
//  Nudgy communicates via short, warm contextual messages — not a chatbot.
//  Bubbles appear above/beside Nudgy with a tail pointing to him.
//
//  Usage: NudgySpeechBubble(message: "Nice one!", style: .celebration)
//

import SwiftUI

// MARK: - Speech Bubble Style

enum NudgyBubbleStyle {
    case normal       // White text on dark card
    case celebration  // Green-tinted
    case encouragement // Blue-tinted (accent)
    case sleepy       // Dim, tertiary
    case alert        // Amber-tinted
    
    var backgroundColor: Color {
        switch self {
        case .normal:        return DesignTokens.cardSurface
        case .celebration:   return DesignTokens.accentComplete.opacity(0.15)
        case .encouragement: return DesignTokens.accentActive.opacity(0.12)
        case .sleepy:        return DesignTokens.cardSurface.opacity(0.6)
        case .alert:         return DesignTokens.accentStale.opacity(0.12)
        }
    }
    
    var borderColor: Color {
        switch self {
        case .normal:        return DesignTokens.cardBorder
        case .celebration:   return DesignTokens.accentComplete.opacity(0.4)
        case .encouragement: return DesignTokens.accentActive.opacity(0.3)
        case .sleepy:        return DesignTokens.cardBorder.opacity(0.4)
        case .alert:         return DesignTokens.accentStale.opacity(0.4)
        }
    }
    
    var textColor: Color {
        switch self {
        case .normal:        return DesignTokens.textPrimary
        case .celebration:   return DesignTokens.accentComplete
        case .encouragement: return DesignTokens.textPrimary
        case .sleepy:        return DesignTokens.textTertiary
        case .alert:         return DesignTokens.accentStale
        }
    }
}

// MARK: - Nudgy Messages (Contextual One-Liners)

enum NudgyMessages {
    
    // MARK: Greetings (app open)
    static let greetings: [String] = [
        String(localized: "Hey! What's on your mind?"),
        String(localized: "Ready when you are! 🐧"),
        String(localized: "Let's get something done today."),
        String(localized: "I'm here. What do you need?"),
        String(localized: "One thing at a time. Let's go!"),
    ]
    
    // MARK: Task Done
    static let taskDone: [String] = [
        String(localized: "Nice one! ✨"),
        String(localized: "Done! What's next?"),
        String(localized: "Boom! Crushed it."),
        String(localized: "That's one less thing!"),
        String(localized: "Look at you go! 🎉"),
        String(localized: "Another one bites the dust."),
    ]
    
    // MARK: All Clear (empty state)
    static let allClear: [String] = [
        String(localized: "All done! I'm taking a nap. 😴"),
        String(localized: "Your brain is clear. Go enjoy something."),
        String(localized: "Nothing left! Time to relax."),
        String(localized: "Zero tasks. You earned this. 🎉"),
        String(localized: "All clear! I'll be here when you need me."),
    ]
    
    // MARK: Brain Dump Idle (before recording)
    static let brainDumpIdle: [String] = [
        String(localized: "Tell me what's on your mind."),
        String(localized: "I'm listening! Just hit the mic."),
        String(localized: "Brain full? Let it all out."),
        String(localized: "Talk to me. I'll organize it."),
    ]
    
    // MARK: Brain Dump Processing
    static let processing: [String] = [
        String(localized: "Hmm, let me think about this..."),
        String(localized: "Sorting your thoughts..."),
        String(localized: "Breaking that down for you..."),
        String(localized: "One sec, organizing..."),
    ]
    
    // MARK: Brain Dump Results
    static func results(count: Int) -> String {
        switch count {
        case 1:
            return String(localized: "Got it! Just one thing.")
        case 2...3:
            return String(localized: "Found \(count) things in there!")
        default:
            return String(localized: "Wow, \(count) tasks! Let's tackle them one by one.")
        }
    }
    
    // MARK: Stale Item Nudge
    static let staleNudge: [String] = [
        String(localized: "This one's been sitting here a while..."),
        String(localized: "Hey, remember this one? 👀"),
        String(localized: "Still here! Want to do it or let it go?"),
        String(localized: "Gentle nudge — this is getting dusty."),
    ]
    
    // MARK: Snooze
    static let snooze: [String] = [
        String(localized: "See you later! 👋"),
        String(localized: "I'll remind you. Promise."),
        String(localized: "Snoozed. I've got your back."),
    ]
    
    // MARK: Skip
    static let skip: [String] = [
        String(localized: "No worries, moving on!"),
        String(localized: "Next!"),
        String(localized: "Skipped — I'll bring it back later."),
    ]
    
    // MARK: Error / Confused
    static let confused: [String] = [
        String(localized: "Hmm, I didn't catch that. Try again?"),
        String(localized: "Something went wrong. One more time?"),
        String(localized: "Oops! Let's try that again."),
    ]
    
    // MARK: Listening (during recording)
    static let listening: [String] = [
        String(localized: "I'm all ears! 🎤"),
        String(localized: "Keep going, I'm listening..."),
        String(localized: "Mhm, mhm... 🐧"),
    ]
    
    /// Pick a random message from a category
    static func random(from messages: [String]) -> String {
        messages.randomElement() ?? messages[0]
    }
}

// MARK: - Speech Bubble Shape (with tail)

struct SpeechBubbleShape: Shape {
    var tailPosition: CGFloat = 0.5 // 0 = left, 1 = right
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 12
        let tailWidth: CGFloat = 14
        let tailHeight: CGFloat = 10
        
        let bodyRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height - tailHeight
        )
        
        return Path { p in
            // Rounded rect body
            p.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: radius, height: radius))
            
            // Tail triangle at bottom
            let tailCenter = bodyRect.minX + bodyRect.width * tailPosition
            p.move(to: CGPoint(x: tailCenter - tailWidth / 2, y: bodyRect.maxY - 1))
            p.addLine(to: CGPoint(x: tailCenter, y: rect.maxY))
            p.addLine(to: CGPoint(x: tailCenter + tailWidth / 2, y: bodyRect.maxY - 1))
            p.closeSubpath()
        }
    }
}

// MARK: - Speech Bubble View

struct NudgySpeechBubble: View {
    let message: String
    var style: NudgyBubbleStyle = .normal
    var maxWidth: CGFloat = 220
    
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Text(message)
            .font(AppTheme.nudgyBubbleFont)
            .foregroundStyle(style.textColor)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingMD)
            .padding(.bottom, DesignTokens.spacingMD + 8) // Extra for tail
            .frame(maxWidth: maxWidth)
            .background(
                SpeechBubbleShape(tailPosition: 0.5)
                    .fill(style.backgroundColor)
                    .overlay(
                        SpeechBubbleShape(tailPosition: 0.5)
                            .stroke(style.borderColor, lineWidth: 0.5)
                    )
            )
            .scaleEffect(appeared ? 1.0 : 0.3)
            .opacity(appeared ? 1.0 : 0)
            .onAppear {
                withAnimation(
                    reduceMotion
                        ? .easeOut(duration: 0.2)
                        : .spring(response: 0.35, dampingFraction: 0.65)
                ) {
                    appeared = true
                }
            }
            .nudgeAccessibility(
                label: message,
                traits: .isStaticText
            )
    }
}

// MARK: - Nudgy with Bubble (Composite View)

/// A convenient composite: Nudgy + speech bubble above him.
/// Use this instead of separate PenguinMascot + NudgySpeechBubble in most places.
struct NudgyWithBubble: View {
    let expression: PenguinExpression
    let message: String
    var bubbleStyle: NudgyBubbleStyle = .normal
    var penguinSize: CGFloat = DesignTokens.penguinSizeLarge
    var accentColor: Color = DesignTokens.accentActive
    var showBubble: Bool = true
    
    var body: some View {
        VStack(spacing: -4) { // Negative spacing so tail overlaps Nudgy's head area
            if showBubble {
                NudgySpeechBubble(
                    message: message,
                    style: bubbleStyle
                )
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
            
            PenguinMascot(
                expression: expression,
                size: penguinSize,
                accentColor: accentColor
            )
        }
    }
}

// MARK: - Previews

#Preview("Speech Bubble Styles") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 24) {
            NudgySpeechBubble(message: "Hey! What's on your mind?", style: .normal)
            NudgySpeechBubble(message: "Nice one! ✨", style: .celebration)
            NudgySpeechBubble(message: "Let's go!", style: .encouragement)
            NudgySpeechBubble(message: "zzz...", style: .sleepy)
            NudgySpeechBubble(message: "This one's been sitting here...", style: .alert)
        }
    }
}

#Preview("Nudgy with Bubble") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        NudgyWithBubble(
            expression: .idle,
            message: "Hey! What's on your mind?",
            bubbleStyle: .encouragement,
            penguinSize: 120
        )
    }
}
