//
//  LottieNudgyView.swift
//  Nudge
//
//  Animated Nudgy mascot view.
//  Displays the Nudgy app icon with expression-driven SwiftUI animations.
//  A full animated version (Rive-powered) will replace this later.
//
//  Drop-in compatible with PenguinSceneView and all other consumers.
//

import SwiftUI

// MARK: - Nudgy Mascot View (Animated Static Icon)

/// Displays the Nudgy mascot using the app icon image, animated with
/// expression-driven SwiftUI modifiers (float, sway, bounce, wiggle, etc.).
///
/// Same init signature as before — all call sites work unchanged.
/// A fully animated Rive-powered version will replace this in the future.
struct LottieNudgyView: View {
    let expression: PenguinExpression
    let size: CGFloat
    var accentColor: Color = DesignTokens.accentActive
    
    // MARK: Animation State
    
    @State private var floatOffset: CGFloat = 0
    @State private var swayAngle: Double = 0
    @State private var breathScale: CGFloat = 1.0
    @State private var bounceOffset: CGFloat = 0
    @State private var wiggleAngle: Double = 0
    @State private var thinkTilt: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var isAnimating = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        PenguinMascot(
            expression: expression,
            size: size,
            accentColor: accentColor
        )
        // Expression-driven transforms (layered on top of PenguinMascot's own animations)
        .scaleEffect(breathScale)
        .offset(y: floatOffset + bounceOffset)
        .rotationEffect(.degrees(swayAngle + wiggleAngle + thinkTilt))
        // Subtle accent glow behind mascot
        .shadow(
            color: accentColor.opacity(glowOpacity),
            radius: size * 0.08
        )
        .accessibilityLabel(accessibilityLabel)
        .onAppear { startAnimations() }
        .onChange(of: expression) { _, _ in
            startAnimations()
        }
    }
    
    // MARK: - Animation Driver
    
    private func startAnimations() {
        // Skip all animation if reduce motion is on
        guard !reduceMotion else { return }
        
        // Reset one-shot states
        bounceOffset = 0
        wiggleAngle = 0
        thinkTilt = 0
        
        switch expression {
        case .idle:
            animateFloat()
            animateSway()
            animateBreath()
            animateGlow()
            
        case .happy, .celebrating, .thumbsUp:
            animateBounce()
            animateGlow()
            
        case .thinking:
            animateThinkTilt()
            animateBreath()
            animateGlow()
            
        case .sleeping:
            animateBreath()
            // No glow — calm, resting
            
        case .listening:
            animateFloat()
            animateBreath()
            animateGlow()
            
        case .talking, .typing:
            animateBounce()
            animateBreath()
            
        case .waving:
            animateSway()
            animateGlow()
            
        case .nudging:
            animateWiggle()
            animateGlow()
            
        case .confused:
            animateThinkTilt()
            animateSway()
        }
    }
    
    // MARK: - Individual Animations
    
    /// Gentle vertical float — dreamy idle feel
    private func animateFloat() {
        withAnimation(AnimationConstants.mascotFloat) {
            floatOffset = -AnimationConstants.mascotFloatAmplitude
        }
    }
    
    /// Slow rotation sway — playful idle
    private func animateSway() {
        withAnimation(AnimationConstants.mascotSway) {
            swayAngle = AnimationConstants.mascotSwayAngle
        }
    }
    
    /// Subtle breathing scale — alive feeling
    private func animateBreath() {
        withAnimation(AnimationConstants.mascotBreath) {
            breathScale = AnimationConstants.mascotBreathMax
        }
    }
    
    /// Accent glow pulse behind mascot
    private func animateGlow() {
        withAnimation(AnimationConstants.mascotGlow) {
            glowOpacity = AnimationConstants.mascotGlowMax
        }
    }
    
    /// Happy/celebrating bounce — single spring settle, not repeating
    private func animateBounce() {
        bounceOffset = AnimationConstants.mascotBounceDrop
        withAnimation(AnimationConstants.mascotBounceSpring) {
            bounceOffset = 0
        }
    }
    
    /// Quick wiggle burst — "nudging" the user
    private func animateWiggle() {
        let angle = AnimationConstants.mascotWiggleAngle
        let dur = AnimationConstants.mascotWiggleDuration
        let count = AnimationConstants.mascotWiggleCount
        
        Task {
            for i in 0..<(count * 2) {
                let target = (i % 2 == 0) ? angle : -angle
                withAnimation(.easeInOut(duration: dur)) {
                    wiggleAngle = target
                }
                try? await Task.sleep(for: .seconds(dur))
            }
            // Settle back to center
            withAnimation(.easeOut(duration: dur * 2)) {
                wiggleAngle = 0
            }
            // Repeat after pause
            try? await Task.sleep(for: .seconds(1.5))
            if !Task.isCancelled {
                animateWiggle()
            }
        }
    }
    
    /// Thinking tilt — gentle lean to one side
    private func animateThinkTilt() {
        withAnimation(AnimationConstants.mascotThinkAnimation) {
            thinkTilt = AnimationConstants.mascotThinkTilt
        }
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        switch expression {
        case .idle:        return String(localized: "Nudgy the penguin, relaxing")
        case .happy:       return String(localized: "Nudgy celebrating your progress")
        case .thinking:    return String(localized: "Nudgy thinking about what you said")
        case .sleeping:    return String(localized: "Nudgy resting, all tasks done")
        case .celebrating: return String(localized: "Nudgy celebrating, all tasks complete!")
        case .thumbsUp:    return String(localized: "Nudgy giving a thumbs up")
        case .listening:   return String(localized: "Nudgy listening to you")
        case .talking:     return String(localized: "Nudgy talking")
        case .waving:      return String(localized: "Nudgy waving hello")
        case .nudging:     return String(localized: "Nudgy nudging you to focus")
        case .confused:    return String(localized: "Nudgy looking confused")
        case .typing:      return String(localized: "Nudgy typing away")
        }
    }
}

// MARK: - Color Extension for Hue Extraction

extension Color {
    /// Extract the hue component (0.0-1.0) from a SwiftUI Color.
    var hueComponent: Float {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Float(hue)
    }
}

// MARK: - Previews

#Preview("Nudgy Idle") {
    ZStack {
        Color.black.ignoresSafeArea()
        LottieNudgyView(expression: .idle, size: 240)
    }
    .preferredColorScheme(.dark)
}

#Preview("Nudgy All Expressions") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 16) {
            ForEach(PenguinExpression.allCases, id: \.rawValue) { expr in
                VStack(spacing: 8) {
                    LottieNudgyView(expression: expr, size: 100)
                    Text(expr.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}
