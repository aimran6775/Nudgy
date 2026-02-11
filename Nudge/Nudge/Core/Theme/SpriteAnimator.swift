//
//  SpriteAnimator.swift
//  Nudge
//
//  Core sprite animation engine.
//  Cycles through numbered PNG frames in Asset Catalogs at a configurable FPS.
//
//  Usage:
//    SpriteAnimator(baseName: "nudgy-idle", frameCount: 8, fps: 12, loops: true)
//
//  The view looks for images named "{baseName}-{frameNumber}" in the asset catalog.
//  e.g. "nudgy-idle-1", "nudgy-idle-2", ... "nudgy-idle-8"
//
//  When artist PNGs aren't available yet, set `usePlaceholder: true` to render
//  a colored circle with the frame number — useful for development.
//

import SwiftUI

// MARK: - Sprite Animation Definition

/// Describes a single animation clip (e.g. "idle", "walking", "happy").
struct SpriteAnimation: Equatable {
    /// Base name for asset lookup — frames are "{baseName}-1", "{baseName}-2", etc.
    let baseName: String
    
    /// Total number of frames in this animation
    let frameCount: Int
    
    /// Playback speed in frames per second
    let fps: Double
    
    /// Whether the animation loops forever or plays once
    let loops: Bool
    
    /// Duration of one full cycle
    var cycleDuration: TimeInterval {
        Double(frameCount) / fps
    }
    
    // MARK: Preset Animations
    
    // These base names match the folder structure the artist will deliver.
    // Frame counts are initial estimates — update when art arrives.
    
    static let idle = SpriteAnimation(baseName: "nudgy-idle", frameCount: 8, fps: 10, loops: true)
    static let walking = SpriteAnimation(baseName: "nudgy-walk", frameCount: 8, fps: 12, loops: true)
    static let happy = SpriteAnimation(baseName: "nudgy-happy", frameCount: 8, fps: 12, loops: false)
    static let listening = SpriteAnimation(baseName: "nudgy-listen", frameCount: 6, fps: 10, loops: true)
    static let thinking = SpriteAnimation(baseName: "nudgy-think", frameCount: 6, fps: 8, loops: true)
    static let sleeping = SpriteAnimation(baseName: "nudgy-sleep", frameCount: 4, fps: 6, loops: true)
    static let waving = SpriteAnimation(baseName: "nudgy-wave", frameCount: 6, fps: 12, loops: false)
    static let talking = SpriteAnimation(baseName: "nudgy-talk", frameCount: 6, fps: 10, loops: true)
    static let celebrating = SpriteAnimation(baseName: "nudgy-celebrate", frameCount: 8, fps: 12, loops: false)
    static let summoned = SpriteAnimation(baseName: "nudgy-summoned", frameCount: 6, fps: 12, loops: false)
    
    /// Map PenguinExpression → SpriteAnimation
    static func from(expression: PenguinExpression) -> SpriteAnimation {
        switch expression {
        case .idle:         return .idle
        case .happy:        return .happy
        case .thinking:     return .thinking
        case .sleeping:     return .sleeping
        case .celebrating:  return .celebrating
        case .thumbsUp:     return .happy       // Reuse happy until artist draws thumbsUp
        case .listening:    return .listening
        case .talking:      return .talking
        case .waving:       return .waving
        case .nudging:      return .talking      // Reuse talking for nudging
        case .confused:     return .thinking     // Reuse thinking for confused
        case .typing:       return .idle         // Reuse idle for typing
        case .shy:          return .idle         // Reuse idle for shy
        case .mischievous:  return .idle         // Reuse idle for mischievous
        }
    }
}

// MARK: - Sprite Animator View

/// Displays an animated sprite by cycling through numbered PNG frames.
/// Uses `TimelineView` for smooth, display-linked frame updates.
struct SpriteAnimator: View {
    
    let animation: SpriteAnimation
    let size: CGFloat
    
    /// When true, shows a placeholder circle instead of looking for image assets.
    /// Set to false once artist delivers the actual PNGs.
    var usePlaceholder: Bool = true
    
    /// Callback fired when a non-looping animation finishes its last frame.
    var onComplete: (() -> Void)?
    
    @State private var currentFrame: Int = 1
    @State private var hasCompleted: Bool = false
    @State private var animationTimer: Timer?
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Group {
            if usePlaceholder || !assetExists(for: currentFrame) {
                placeholderView
            } else {
                Image("\(animation.baseName)-\(currentFrame)")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(width: size, height: size)
        .onAppear { startAnimation() }
        .onDisappear { stopAnimation() }
        .onChange(of: animation) { _, _ in
            restartAnimation()
        }
    }
    
    // MARK: - Placeholder
    
    /// Development placeholder — shows the expression name and frame counter.
    private var placeholderView: some View {
        // Use the existing PenguinMascot as the placeholder (it's the current bezier penguin)
        // This way the app looks identical until artist PNGs are dropped in
        PenguinMascot(
            expression: expressionFromAnimation,
            size: size,
            accentColor: DesignTokens.accentActive
        )
    }
    
    /// Reverse-map the animation back to a PenguinExpression for the placeholder.
    private var expressionFromAnimation: PenguinExpression {
        switch animation.baseName {
        case "nudgy-idle":      return .idle
        case "nudgy-walk":      return .idle   // Walking reuses idle in placeholder
        case "nudgy-happy":     return .happy
        case "nudgy-listen":    return .listening
        case "nudgy-think":     return .thinking
        case "nudgy-sleep":     return .sleeping
        case "nudgy-wave":      return .waving
        case "nudgy-talk":      return .talking
        case "nudgy-celebrate": return .celebrating
        case "nudgy-summoned":  return .waving
        default:                return .idle
        }
    }
    
    // MARK: - Animation Control
    
    private func startAnimation() {
        guard !reduceMotion else {
            // For reduce motion: just show frame 1 (static)
            currentFrame = 1
            return
        }
        
        currentFrame = 1
        hasCompleted = false
        
        let interval = 1.0 / animation.fps
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            advanceFrame()
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func restartAnimation() {
        stopAnimation()
        startAnimation()
    }
    
    private func advanceFrame() {
        if currentFrame >= animation.frameCount {
            if animation.loops {
                currentFrame = 1
            } else if !hasCompleted {
                hasCompleted = true
                stopAnimation()
                onComplete?()
            }
        } else {
            currentFrame += 1
        }
    }
    
    // MARK: - Asset Check
    
    /// Check if an image asset exists in the catalog for this frame.
    private func assetExists(for frame: Int) -> Bool {
        UIImage(named: "\(animation.baseName)-\(frame)") != nil
    }
}

// MARK: - Preview

#Preview("Sprite Animator — Placeholder") {
    VStack(spacing: 20) {
        SpriteAnimator(animation: .idle, size: 240, usePlaceholder: true)
        SpriteAnimator(animation: .happy, size: 120, usePlaceholder: true)
        SpriteAnimator(animation: .sleeping, size: 80, usePlaceholder: true)
    }
    .background(Color.black)
}
