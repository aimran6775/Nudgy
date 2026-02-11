//
//  SpeechBubbleView.swift
//  Nudge
//
//  Speech bubble that floats above the penguin character.
//  Supports multiple styles: speech, thought, announcement, whisper.
//  Designed for the character-centric paradigm — the penguin "speaks" through this.
//

import SwiftUI

struct SpeechBubbleView: View {
    
    let dialogue: PenguinDialogue
    var maxWidth: CGFloat = 260
    var onTap: (() -> Void)?
    
    @State private var appeared = false
    @State private var typingProgress: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    /// The text to display (typing animation or full)
    private var displayedText: String {
        if reduceMotion || dialogue.style == .announcement {
            return dialogue.text
        }
        // Typing effect — reveal characters progressively
        let chars = Array(dialogue.text)
        let count = min(typingProgress, chars.count)
        return String(chars.prefix(count))
    }
    
    /// Whether typing animation is complete
    private var isFullyTyped: Bool {
        typingProgress >= dialogue.text.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            bubbleContent
                .onTapGesture {
                    if !isFullyTyped {
                        // Skip typing animation on tap
                        typingProgress = dialogue.text.count
                    } else {
                        onTap?()
                    }
                }
            
            // Tail pointing down toward penguin
            bubbleTail
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.8, anchor: .bottom)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                appeared = true
            }
            startTypingAnimation()
        }
        .nudgeAccessibility(
            label: dialogue.text,
            hint: String(localized: "Tap to dismiss"),
            traits: .isStaticText
        )
    }
    
    // MARK: - Bubble Content
    
    @ViewBuilder
    private var bubbleContent: some View {
        switch dialogue.style {
        case .speech:
            speechBubble
        case .thought:
            thoughtBubble
        case .announcement:
            announcementBubble
        case .whisper:
            whisperBubble
        }
    }
    
    // MARK: - Speech Style (standard bubble)
    
    private var speechBubble: some View {
        Text(displayedText)
            .font(AppTheme.body)
            .foregroundStyle(DesignTokens.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingMD)
            .frame(maxWidth: maxWidth)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignTokens.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(DesignTokens.cardBorder, lineWidth: 0.5)
                    )
            )
    }
    
    // MARK: - Thought Style (softer, with dot trail)
    
    private var thoughtBubble: some View {
        VStack(spacing: 0) {
            Text(displayedText)
                .font(AppTheme.body.italic())
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.vertical, DesignTokens.spacingMD)
                .frame(maxWidth: maxWidth)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(DesignTokens.cardSurface.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(DesignTokens.cardBorder.opacity(0.4), lineWidth: 0.5)
                        )
                )
        }
    }
    
    // MARK: - Announcement Style (bold, accent-tinted)
    
    private var announcementBubble: some View {
        Text(displayedText)
            .font(AppTheme.headline)
            .foregroundStyle(DesignTokens.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DesignTokens.spacingXL)
            .padding(.vertical, DesignTokens.spacingLG)
            .frame(maxWidth: maxWidth + 40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(DesignTokens.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(DesignTokens.accentActive.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: DesignTokens.accentActive.opacity(0.15), radius: 16, y: 4)
            )
    }
    
    // MARK: - Whisper Style (small, muted)
    
    private var whisperBubble: some View {
        Text(displayedText)
            .font(AppTheme.caption)
            .foregroundStyle(DesignTokens.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM)
            .frame(maxWidth: maxWidth - 40)
            .background(
                Capsule()
                    .fill(DesignTokens.cardSurface.opacity(0.5))
            )
    }
    
    // MARK: - Tail
    
    private var bubbleTail: some View {
        Group {
            switch dialogue.style {
            case .speech, .announcement:
                // Triangular tail pointing down
                Triangle()
                    .fill(DesignTokens.cardSurface)
                    .frame(width: 16, height: 8)
                    .rotationEffect(.degrees(180))
                    .offset(x: -10)
            case .thought:
                // Thought dots trailing down
                VStack(spacing: 3) {
                    Circle()
                        .fill(DesignTokens.cardSurface.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(DesignTokens.cardSurface.opacity(0.35))
                        .frame(width: 5, height: 5)
                }
                .offset(x: -15)
            case .whisper:
                // No tail for whispers
                EmptyView()
            }
        }
    }
    
    // MARK: - Typing Animation
    
    private func startTypingAnimation() {
        guard !reduceMotion, dialogue.style != .announcement else {
            typingProgress = dialogue.text.count
            return
        }
        
        typingProgress = 0
        let totalChars = dialogue.text.count
        let charDelay: TimeInterval = 0.03  // 30ms per character
        
        Task {
            for i in 1...totalChars {
                guard !Task.isCancelled else { break }
                try? await Task.sleep(for: .seconds(charDelay))
                typingProgress = i
            }
        }
    }
}

// MARK: - Preview

#Preview("Speech") {
    ZStack {
        Color.black.ignoresSafeArea()
        SpeechBubbleView(
            dialogue: PenguinDialogue("Hey! Tap me to unload your brain 🧠", style: .speech)
        )
    }
}

#Preview("Thought") {
    ZStack {
        Color.black.ignoresSafeArea()
        SpeechBubbleView(
            dialogue: PenguinDialogue("Hmm, let me sort that out...", style: .thought)
        )
    }
}

#Preview("Announcement") {
    ZStack {
        Color.black.ignoresSafeArea()
        SpeechBubbleView(
            dialogue: PenguinDialogue("5 done today. Go enjoy something! 🎉", style: .announcement)
        )
    }
}

#Preview("Whisper") {
    ZStack {
        Color.black.ignoresSafeArea()
        SpeechBubbleView(
            dialogue: PenguinDialogue("I'll remind you later 💤", style: .whisper)
        )
    }
}
