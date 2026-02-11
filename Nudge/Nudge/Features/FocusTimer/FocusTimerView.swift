//
//  FocusTimerView.swift
//  Nudge
//
//  "Antarctic Focus" — an immersive, ADHD-optimized deep work experience.
//
//  Phase flow: Setup → 3-2-1 Countdown → Focusing → (Break) → Completion
//  - Breathing ring animation anchors attention (combats time agnosia)
//  - Nudgy companion reacts in real-time (body doubling effect)
//  - Distraction parking lot captures stray thoughts without leaving focus
//  - Session summary celebrates the effort, not just the outcome
//  - Pomodoro-aware: configurable focus/break intervals
//

import SwiftUI
import SwiftData

// MARK: - Session Phase

enum FocusPhase: Equatable {
    case setup
    case countdown
    case focusing
    case paused
    case breakTime
    case completed
}

// MARK: - Focus Timer State

@Observable
final class FocusTimerState {
    // Configuration
    var focusMinutes: Int = 25
    var breakMinutes: Int = 5
    var sessionsTarget: Int = 1
    var sessionsCompleted: Int = 0
    
    // Timing
    var totalSeconds: Int = 0
    var remainingSeconds: Int = 0
    var breakTotalSeconds: Int = 0
    var breakRemainingSeconds: Int = 0
    var phase: FocusPhase = .setup
    
    // Tracking
    var distractions: [String] = []
    var totalFocusedSeconds: Int = 0  // Across all sessions in this sitting
    
    // Computed
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }
    
    var breakProgress: Double {
        guard breakTotalSeconds > 0 else { return 0 }
        return Double(breakTotalSeconds - breakRemainingSeconds) / Double(breakTotalSeconds)
    }
    
    var elapsedSeconds: Int { totalSeconds - remainingSeconds }
    
    var formattedRemaining: String {
        let t = phase == .breakTime ? breakRemainingSeconds : remainingSeconds
        let mins = t / 60
        let secs = t % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    var formattedElapsed: String {
        let mins = elapsedSeconds / 60
        let secs = elapsedSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    var isActive: Bool {
        switch phase {
        case .focusing, .paused, .breakTime: return true
        default: return false
        }
    }
}

// MARK: - Focus Timer View

struct FocusTimerView: View {
    
    let item: NudgeItem
    @Binding var isPresented: Bool
    
    @Environment(PenguinState.self) private var penguinState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var timer = FocusTimerState()
    @State private var tickTimer: Timer?
    
    // Animations
    @State private var ringBreathing = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var countdownNumber: Int = 3
    @State private var countdownVisible = false
    
    // Encouragement
    @State private var encouragementText: String = ""
    @State private var showEncouragement = false
    @State private var lastEncouragementElapsed: Int = 0
    
    // Nudgy companion
    @State private var nudgyExpression: PenguinExpression = .idle
    @State private var nudgyMessage: String = ""
    @State private var showNudgyBubble = false
    
    // Distraction capture
    @State private var showDistractionCapture = false
    @State private var distractionText: String = ""
    
    // Completion
    @State private var showCompletionParticles = false
    @State private var completionAppeared = false
    
    // Background glow
    @State private var glowPhase = false
    
    // Aurora / particles
    @State private var auroraOffset: CGFloat = 0
    @State private var snowflakes: [FocusSnowflake] = []
    @State private var snowTimer: Timer?
    
    // Ring breathing
    @State private var ringScale: CGFloat = 1.0
    @State private var ringGlowIntensity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Immersive background
            focusBackground
                .ignoresSafeArea()
            
            switch timer.phase {
            case .setup:
                setupPhaseView
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                
            case .countdown:
                countdownOverlay
                    .transition(.opacity)
                
            case .focusing, .paused:
                focusingPhaseView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                
            case .breakTime:
                breakPhaseView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                
            case .completed:
                completionPhaseView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Distraction capture overlay
            if showDistractionCapture {
                distractionCaptureOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
            
            // Completion particles
            if showCompletionParticles {
                CompletionParticles(isActive: $showCompletionParticles)
                    .allowsHitTesting(false)
                    .zIndex(99)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            glowPhase = true
            auroraOffset = 1
            spawnSnowflakes()
            // Set default from AI estimate
            if let estimate = item.estimatedMinutes, estimate > 0 {
                timer.focusMinutes = estimate
            }
        }
        .onDisappear {
            tickTimer?.invalidate()
            tickTimer = nil
            snowTimer?.invalidate()
            snowTimer = nil
        }
    }
    
    // MARK: - Immersive Antarctic Background
    
    private var focusBackground: some View {
        let accent = ringAccentColor
        
        return ZStack {
            // Deep Antarctic night sky gradient — NOT pure black
            LinearGradient(
                colors: [
                    Color(hex: "020B1A"),  // Very dark navy (not pure black)
                    Color(hex: "0A1628"),  // Dark blue-gray
                    Color(hex: "0E1F3D"),  // Midnight blue
                    Color(hex: "0A1628"),
                    Color(hex: "050E1E"),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Stars — tiny dots scattered
            starsLayer
            
            // Aurora borealis band — the hero visual
            auroraLayer(accent: accent)
            
            // Central accent glow (follows ring color)
            RadialGradient(
                colors: [
                    accent.opacity(glowPhase ? 0.15 : 0.06),
                    accent.opacity(0.04),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 4).repeatForever(autoreverses: true),
                value: glowPhase
            )
            
            // Floating snowflake particles
            snowflakeLayer
            
            // Horizon mountain silhouette
            mountainSilhouette
        }
    }
    
    // MARK: - Stars Layer
    
    private var starsLayer: some View {
        Canvas { context, size in
            // Deterministic star field
            var rng = StableRNG(seed: 42)
            for _ in 0..<80 {
                let x = CGFloat(rng.next()) * size.width
                let y = CGFloat(rng.next()) * size.height * 0.6 // Stars in top 60%
                let brightness = CGFloat(rng.next()) * 0.5 + 0.15
                let starSize = CGFloat(rng.next()) * 1.8 + 0.5
                
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: starSize, height: starSize)),
                    with: .color(.white.opacity(brightness))
                )
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Aurora Layer
    
    private func auroraLayer(accent: Color) -> some View {
        ZStack {
            // Primary aurora band
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.0),
                            accent.opacity(0.12),
                            Color(hex: "00FFAA").opacity(0.08),
                            DesignTokens.accentFocus.opacity(0.10),
                            accent.opacity(0.0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 600, height: 120)
                .blur(radius: 40)
                .offset(x: auroraOffset * 30, y: -180)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 8).repeatForever(autoreverses: true),
                    value: auroraOffset
                )
            
            // Secondary shimmer band
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            Color(hex: "4FFFCF").opacity(0.06),
                            DesignTokens.accentFocus.opacity(0.08),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 500, height: 80)
                .blur(radius: 30)
                .offset(x: -auroraOffset * 20, y: -140)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 6).repeatForever(autoreverses: true),
                    value: auroraOffset
                )
        }
    }
    
    // MARK: - Snowflake Layer
    
    private var snowflakeLayer: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for flake in snowflakes {
                    let age = now - flake.spawnTime
                    let yTravel = age * Double(flake.speed)
                    let y = flake.startY + CGFloat(yTravel)
                    let x = flake.startX + sin(CGFloat(age) * flake.wobbleFreq) * flake.wobbleAmp
                    
                    guard y < size.height + 20 else { continue }
                    
                    let opacity = min(1, age / 0.5) * Double(flake.opacity) // fade in
                    let rect = CGRect(x: x, y: y, width: flake.size, height: flake.size)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Mountain Silhouette
    
    private var mountainSilhouette: some View {
        VStack {
            Spacer()
            Canvas { context, size in
                var path = Path()
                let w = size.width
                let h = size.height
                
                path.move(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: 0, y: h * 0.4))
                path.addQuadCurve(
                    to: CGPoint(x: w * 0.15, y: h * 0.2),
                    control: CGPoint(x: w * 0.08, y: h * 0.25)
                )
                path.addQuadCurve(
                    to: CGPoint(x: w * 0.3, y: h * 0.35),
                    control: CGPoint(x: w * 0.22, y: h * 0.15)
                )
                path.addQuadCurve(
                    to: CGPoint(x: w * 0.5, y: h * 0.15),
                    control: CGPoint(x: w * 0.38, y: h * 0.3)
                )
                path.addQuadCurve(
                    to: CGPoint(x: w * 0.7, y: h * 0.3),
                    control: CGPoint(x: w * 0.62, y: h * 0.1)
                )
                path.addQuadCurve(
                    to: CGPoint(x: w * 0.85, y: h * 0.25),
                    control: CGPoint(x: w * 0.78, y: h * 0.35)
                )
                path.addQuadCurve(
                    to: CGPoint(x: w, y: h * 0.4),
                    control: CGPoint(x: w * 0.95, y: h * 0.15)
                )
                path.addLine(to: CGPoint(x: w, y: h))
                path.closeSubpath()
                
                context.fill(path, with: .color(Color(hex: "060F20").opacity(0.9)))
            }
            .frame(height: 160)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Snowflake Spawner
    
    private func spawnSnowflakes() {
        // Initial batch
        let now = Date.timeIntervalSinceReferenceDate
        snowflakes = (0..<30).map { _ in
            FocusSnowflake(
                startX: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                startY: CGFloat.random(in: -50...UIScreen.main.bounds.height),
                speed: CGFloat.random(in: 8...25),
                size: CGFloat.random(in: 1.5...4),
                opacity: CGFloat.random(in: 0.15...0.5),
                wobbleFreq: CGFloat.random(in: 0.3...1.2),
                wobbleAmp: CGFloat.random(in: 3...12),
                spawnTime: now - Double.random(in: 0...15)
            )
        }
        
        // Continuous spawning
        snowTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            Task { @MainActor in
                let now = Date.timeIntervalSinceReferenceDate
                
                // Remove off-screen flakes
                snowflakes.removeAll { flake in
                    let age = now - flake.spawnTime
                    return flake.startY + CGFloat(age * Double(flake.speed)) > UIScreen.main.bounds.height + 30
                }
                
                // Spawn new
                if snowflakes.count < 35 {
                    snowflakes.append(FocusSnowflake(
                        startX: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        startY: CGFloat.random(in: -40 ... -10),
                        speed: CGFloat.random(in: 8...25),
                        size: CGFloat.random(in: 1.5...4),
                        opacity: CGFloat.random(in: 0.15...0.5),
                        wobbleFreq: CGFloat.random(in: 0.3...1.2),
                        wobbleAmp: CGFloat.random(in: 3...12),
                        spawnTime: now
                    ))
                }
            }
        }
    }
    
    // MARK: - Setup Phase
    
    private var setupPhaseView: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle().fill(Color.white.opacity(0.10))
                        }
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                
                Spacer()
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingMD)
            
            Spacer()
            
            // Task info — hero treatment with Nudgy
            VStack(spacing: DesignTokens.spacingLG) {
                // Nudgy greeting
                PenguinSceneView(
                    size: .medium,
                    expressionOverride: .waving,
                    accentColorOverride: DesignTokens.accentActive
                )
                
                VStack(spacing: DesignTokens.spacingMD) {
                    TaskIconView(
                    emoji: item.emoji,
                    actionType: item.actionType,
                    size: .large,
                    accentColor: DesignTokens.accentActive
                )
                
                Text(item.content)
                    .font(AppTheme.title2)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, DesignTokens.spacingXXL)
                
                if let duration = item.durationLabel {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(String(localized: "Estimated: \(duration)"))
                    }
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
                }
                } // inner VStack
            } // Task info + Nudgy VStack
            
            Spacer()
            
            // Duration selector — glass pills
            VStack(spacing: DesignTokens.spacingLG) {
                Text(String(localized: "Focus duration"))
                    .font(AppTheme.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .textCase(.uppercase)
                
                // Preset durations
                HStack(spacing: DesignTokens.spacingSM) {
                    ForEach(focusPresets, id: \.minutes) { preset in
                        durationPill(
                            label: preset.label,
                            minutes: preset.minutes,
                            isSelected: timer.focusMinutes == preset.minutes
                        )
                    }
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                
                // Custom stepper — only if none of the presets match
                if !focusPresets.map(\.minutes).contains(timer.focusMinutes) {
                    customDurationStepper
                }
                
                // AI estimate pill
                if let estimate = item.estimatedMinutes, !focusPresets.map(\.minutes).contains(estimate) {
                    Button {
                        withAnimation(AnimationConstants.springSmooth) {
                            timer.focusMinutes = estimate
                        }
                        HapticService.shared.actionButtonTap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                            Text(String(localized: "AI estimate: \(estimate) min"))
                                .font(AppTheme.footnote.weight(.medium))
                        }
                        .foregroundStyle(DesignTokens.accentFocus)
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM)
                        .background {
                            Capsule().fill(DesignTokens.accentFocus.opacity(0.1))
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
            }
            
            Spacer()
            
            // Start button — prominent, inviting
            VStack(spacing: DesignTokens.spacingMD) {
                Button {
                    beginCountdown()
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                        Text(String(localized: "Start Focus"))
                            .font(AppTheme.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [DesignTokens.accentActive, DesignTokens.accentFocus],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DesignTokens.spacingXXL)
                
                Text(String(localized: "\(timer.focusMinutes) min focus"))
                    .font(AppTheme.hintFont)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(.bottom, DesignTokens.spacingXXXL)
        }
        .nudgeAccessibility(
            label: String(localized: "Focus timer setup for \(item.content)"),
            hint: String(localized: "Choose a duration and start focusing")
        )
    }
    
    // MARK: - Countdown Overlay (3-2-1)
    
    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
            
            VStack(spacing: DesignTokens.spacingLG) {
                Text("\(countdownNumber)")
                    .font(.system(size: 120, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(DesignTokens.accentActive)
                    .opacity(countdownVisible ? 1 : 0)
                    .scaleEffect(countdownVisible ? 1 : 1.5)
                    .contentTransition(.numericText())
                
                Text(String(localized: "Get ready…"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
    }
    
    // MARK: - Focusing Phase
    
    private var focusingPhaseView: some View {
        VStack(spacing: 0) {
            // Top controls — minimal chrome
            focusTopBar
            
            Spacer()
            
            // The Ring — the heart of the experience
            focusRing
            
            // Encouragement slot
            encouragementBanner
                .frame(height: 60)
            
            Spacer()
            
            // Nudgy companion strip
            nudgyCompanionStrip
            
            // Bottom controls
            focusBottomControls
                .padding(.bottom, DesignTokens.spacingXL)
        }
    }
    
    // MARK: - Focus Ring
    
    private var focusRing: some View {
        ZStack {
            // Outer breathing glow — visible pulsing halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ringAccentColor.opacity(ringGlowIntensity),
                            ringAccentColor.opacity(ringGlowIntensity * 0.3),
                            .clear
                        ],
                        center: .center,
                        startRadius: 120,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .scaleEffect(ringScale)
            
            // Track ring — visible!
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 8)
                .frame(width: 260, height: 260)
            
            // Shadow/depth ring behind progress
            Circle()
                .stroke(ringAccentColor.opacity(0.08), lineWidth: 14)
                .frame(width: 260, height: 260)
                .blur(radius: 4)
            
            // Progress ring — thicker, brighter
            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(
                    AngularGradient(
                        colors: [
                            ringAccentColor.opacity(0.5),
                            ringAccentColor,
                            ringAccentColor
                        ],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * max(0.01, timer.progress))
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(-90))
                .shadow(color: ringAccentColor.opacity(0.5), radius: 8)
                .animation(reduceMotion ? .none : .easeOut(duration: 0.5), value: timer.progress)
            
            // Progress endpoint dot with glow
            if timer.progress > 0.02 {
                ZStack {
                    Circle()
                        .fill(ringAccentColor)
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(ringAccentColor.opacity(0.4))
                        .frame(width: 24, height: 24)
                        .blur(radius: 4)
                }
                .offset(y: -130) // radius
                .rotationEffect(.degrees(360 * timer.progress - 90))
                .animation(reduceMotion ? .none : .easeOut(duration: 0.5), value: timer.progress)
            }
            
            // Center content
            VStack(spacing: DesignTokens.spacingSM) {
                // Remaining time — large, prominent
                Text(timer.formattedRemaining)
                    .font(.system(size: 56, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(DesignTokens.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: timer.remainingSeconds)
                
                // Task label
                HStack(spacing: 6) {
                    if let emoji = item.emoji {
                        Text(emoji)
                            .font(.system(size: 16))
                    }
                    Text(item.content)
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: 180)
                
                // Session progress (if multi-session)
                if timer.sessionsTarget > 1 {
                    HStack(spacing: 4) {
                        ForEach(0..<timer.sessionsTarget, id: \.self) { i in
                            Circle()
                                .fill(i < timer.sessionsCompleted
                                    ? DesignTokens.accentComplete
                                    : i == timer.sessionsCompleted
                                        ? ringAccentColor
                                        : Color.white.opacity(0.15)
                                )
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .onAppear {
            ringBreathing = true
            startRingBreathingAnimation()
        }
    }
    
    // MARK: - Encouragement Banner
    
    private var encouragementBanner: some View {
        Group {
            if showEncouragement {
                Text(encouragementText)
                    .font(AppTheme.rounded(.callout, weight: .medium))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.spacingXXL)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .animation(AnimationConstants.springSmooth, value: showEncouragement)
    }
    
    // MARK: - Focus Top Bar
    
    private var focusTopBar: some View {
        HStack {
            // End session
            Button {
                endSession()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                    Text(String(localized: "End"))
                        .font(AppTheme.caption.weight(.medium))
                }
                .foregroundStyle(DesignTokens.textTertiary)
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM)
                .background {
                    Capsule().fill(Color.white.opacity(0.10))
                }
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            
            Spacer()
            
            // Elapsed time badge
            HStack(spacing: 4) {
                Circle()
                    .fill(timer.phase == .paused ? DesignTokens.accentStale : DesignTokens.accentComplete)
                    .frame(width: 6, height: 6)
                
                Text(timer.formattedElapsed)
                    .font(AppTheme.rounded(.caption2, weight: .bold))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, DesignTokens.spacingSM + 2)
            .padding(.vertical, DesignTokens.spacingXS + 2)
            .background {
                Capsule().fill(Color.white.opacity(0.10))
            }
            .glassEffect(.regular.interactive(), in: .capsule)
            
            Spacer()
            
            // Distraction parking lot button
            Button {
                withAnimation(AnimationConstants.springSmooth) {
                    showDistractionCapture.toggle()
                }
                HapticService.shared.actionButtonTap()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.min")
                        .font(.system(size: 12, weight: .medium))
                    if !timer.distractions.isEmpty {
                        Text("\(timer.distractions.count)")
                            .font(AppTheme.rounded(.caption2, weight: .bold))
                    }
                }
                .foregroundStyle(DesignTokens.accentStale)
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM)
                .background {
                    Capsule().fill(DesignTokens.accentStale.opacity(0.08))
                }
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .nudgeAccessibility(
                label: String(localized: "Park a distraction"),
                hint: String(localized: "Capture a thought to deal with later"),
                traits: .isButton
            )
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.top, DesignTokens.spacingMD)
    }
    
    // MARK: - Nudgy Companion Strip
    
    private var nudgyCompanionStrip: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            // Nudgy — medium size so it's actually visible
            PenguinSceneView(
                size: .medium,
                expressionOverride: nudgyExpression,
                accentColorOverride: ringAccentColor
            )
            
            if showNudgyBubble {
                Text(nudgyMessage)
                    .font(AppTheme.nudgyBubbleFont)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(2)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM + 2)
                    .background {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.12))
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.bottom, DesignTokens.spacingSM)
        .animation(AnimationConstants.springSmooth, value: showNudgyBubble)
    }
    
    // MARK: - Bottom Controls
    
    private var focusBottomControls: some View {
        HStack(spacing: DesignTokens.spacingXXL) {
            // +5 min extend
            Button {
                extendTimer()
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 52, height: 52)
                            .glassEffect(.regular.interactive(), in: .circle)
                        
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    Text(String(localized: "+5 min"))
                        .font(AppTheme.hintFont)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            .nudgeAccessibility(
                label: String(localized: "Add 5 minutes"),
                hint: String(localized: "Extend the focus session by 5 minutes"),
                traits: .isButton
            )
            
            // Play/Pause — hero button
            Button {
                togglePause()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ringAccentColor,
                                    ringAccentColor.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: ringAccentColor.opacity(0.3), radius: 12, y: 4)
                    
                    Image(systemName: timer.phase == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .scaleEffect(pulseScale)
            .nudgeAccessibility(
                label: timer.phase == .paused ? String(localized: "Resume") : String(localized: "Pause"),
                traits: .isButton
            )
            
            // Done early
            Button {
                withAnimation(AnimationConstants.springSmooth) {
                    timer.totalFocusedSeconds += timer.elapsedSeconds
                    timer.phase = .completed
                }
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 52, height: 52)
                            .glassEffect(.regular.interactive(), in: .circle)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(DesignTokens.accentComplete)
                    }
                    Text(String(localized: "Done"))
                        .font(AppTheme.hintFont)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            .nudgeAccessibility(
                label: String(localized: "Finish early"),
                hint: String(localized: "End focus and see your results"),
                traits: .isButton
            )
        }
    }
    
    // MARK: - Break Phase
    
    private var breakPhaseView: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            // Top bar
            HStack {
                Button {
                    skipBreak()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 11))
                        Text(String(localized: "Skip break"))
                            .font(AppTheme.caption.weight(.medium))
                    }
                    .foregroundStyle(DesignTokens.textTertiary)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .background {
                        Capsule().fill(Color.white.opacity(0.10))
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                Spacer()
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingMD)
            
            Spacer()
            
            // Break content
            VStack(spacing: DesignTokens.spacingLG) {
                PenguinSceneView(
                    size: .medium,
                    expressionOverride: .happy,
                    accentColorOverride: DesignTokens.accentComplete
                )
                
                VStack(spacing: DesignTokens.spacingSM) {
                    Text(String(localized: "Nice work! Take a breather 🧊"))
                        .font(AppTheme.title3)
                        .foregroundStyle(DesignTokens.textPrimary)
                    
                    Text(String(localized: "Session \(timer.sessionsCompleted) of \(timer.sessionsTarget) complete"))
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                
                // Break countdown ring — smaller, calming
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 4)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: timer.breakProgress)
                        .stroke(DesignTokens.accentComplete.opacity(0.5), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? .none : .easeOut(duration: 0.5), value: timer.breakProgress)
                    
                    VStack(spacing: 2) {
                        Text(breakFormattedRemaining)
                            .font(.system(size: 28, weight: .light, design: .rounded))
                            .foregroundStyle(DesignTokens.textPrimary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        
                        Text(String(localized: "break"))
                            .font(AppTheme.hintFont)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                
                // Distraction count (if any captured)
                if !timer.distractions.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.min.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignTokens.accentStale)
                        Text(String(localized: "\(timer.distractions.count) thoughts parked — review after"))
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    .padding(.top, DesignTokens.spacingSM)
                }
            }
            
            Spacer()
            
            // Return to focus button
            Button {
                startNextSession()
            } label: {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14))
                    Text(String(localized: "Start Next Session"))
                        .font(AppTheme.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(DesignTokens.accentActive.opacity(0.2))
                }
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignTokens.spacingXXL)
            .padding(.bottom, DesignTokens.spacingXXXL)
        }
    }
    
    private var breakFormattedRemaining: String {
        let mins = timer.breakRemainingSeconds / 60
        let secs = timer.breakRemainingSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    // MARK: - Completion Phase
    
    private var completionPhaseView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: DesignTokens.spacingXL) {
                // Celebration penguin
                PenguinSceneView(
                    size: .large,
                    expressionOverride: .celebrating,
                    accentColorOverride: DesignTokens.accentComplete
                )
                .scaleEffect(completionAppeared ? 1 : 0.8)
                .opacity(completionAppeared ? 1 : 0)
                
                // Title
                VStack(spacing: DesignTokens.spacingSM) {
                    Text(String(localized: "Focus complete! 🎉"))
                        .font(AppTheme.displayFont)
                        .foregroundStyle(DesignTokens.textPrimary)
                    
                    Text(String(localized: "You stayed focused. That's a win."))
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                .opacity(completionAppeared ? 1 : 0)
                .offset(y: completionAppeared ? 0 : 20)
                
                // Session summary card
                sessionSummaryCard
                    .opacity(completionAppeared ? 1 : 0)
                    .offset(y: completionAppeared ? 0 : 30)
                
                // Parked distractions reminder
                if !timer.distractions.isEmpty {
                    distractionsSummary
                        .opacity(completionAppeared ? 1 : 0)
                        .offset(y: completionAppeared ? 0 : 30)
                }
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: DesignTokens.spacingSM) {
                Button {
                    completeTask()
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text(String(localized: "Mark Task Done"))
                            .font(AppTheme.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(DesignTokens.accentComplete.opacity(0.2))
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                
                Button {
                    endSession()
                } label: {
                    Text(String(localized: "Not done yet — close timer"))
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textTertiary)
                        .padding(.vertical, DesignTokens.spacingMD)
                }
            }
            .padding(.horizontal, DesignTokens.spacingXXL)
            .padding(.bottom, DesignTokens.spacingXXXL)
        }
        .onAppear {
            tickTimer?.invalidate()
            tickTimer = nil
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                completionAppeared = true
            }
            showCompletionParticles = true
            HapticService.shared.swipeDone()
            SoundService.shared.play(.allClear)
        }
    }
    
    // MARK: - Session Summary Card
    
    private var sessionSummaryCard: some View {
        HStack(spacing: DesignTokens.spacingLG) {
            // Total focus time
            statBubble(
                icon: "timer",
                value: "\(totalFocusMinutes)",
                unit: String(localized: "min focused"),
                color: DesignTokens.accentActive
            )
            
            // Sessions
            statBubble(
                icon: "flame.fill",
                value: "\(max(1, timer.sessionsCompleted))",
                unit: timer.sessionsCompleted <= 1 ? String(localized: "session") : String(localized: "sessions"),
                color: DesignTokens.streakOrange
            )
            
            // Distractions parked
            statBubble(
                icon: "lightbulb.min.fill",
                value: "\(timer.distractions.count)",
                unit: String(localized: "parked"),
                color: DesignTokens.accentStale
            )
        }
        .padding(DesignTokens.spacingLG)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                .fill(Color.white.opacity(0.03))
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        .padding(.horizontal, DesignTokens.spacingLG)
    }
    
    private func statBubble(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(DesignTokens.textPrimary)
            
            Text(unit)
                .font(AppTheme.hintFont)
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var totalFocusMinutes: Int {
        max(1, timer.totalFocusedSeconds / 60)
    }
    
    // MARK: - Distractions Summary
    
    private var distractionsSummary: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.min.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.accentStale)
                Text(String(localized: "Parked thoughts"))
                    .font(AppTheme.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .textCase(.uppercase)
            }
            
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                ForEach(Array(timer.distractions.enumerated()), id: \.offset) { _, thought in
                    HStack(spacing: DesignTokens.spacingSM) {
                        Circle()
                            .fill(DesignTokens.accentStale.opacity(0.4))
                            .frame(width: 4, height: 4)
                        Text(thought)
                            .font(AppTheme.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                .fill(Color.white.opacity(0.03))
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        .padding(.horizontal, DesignTokens.spacingLG)
    }
    
    // MARK: - Distraction Capture Overlay
    
    private var distractionCaptureOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: DesignTokens.spacingMD) {
                HStack {
                    Image(systemName: "lightbulb.min.fill")
                        .foregroundStyle(DesignTokens.accentStale)
                    Text(String(localized: "Park a thought"))
                        .font(AppTheme.headline)
                        .foregroundStyle(DesignTokens.textPrimary)
                    Spacer()
                    Button {
                        withAnimation(AnimationConstants.springSmooth) {
                            showDistractionCapture = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                
                Text(String(localized: "Write it down, come back to it later. Stay focused."))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
                
                HStack(spacing: DesignTokens.spacingSM) {
                    TextField(
                        String(localized: "What popped into your head?"),
                        text: $distractionText
                    )
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM + 2)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.12))
                    }
                    .submitLabel(.done)
                    .onSubmit {
                        commitDistraction()
                    }
                    
                    Button {
                        commitDistraction()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                distractionText.isEmpty
                                    ? DesignTokens.textTertiary
                                    : DesignTokens.accentActive
                            )
                    }
                    .disabled(distractionText.isEmpty)
                }
                
                // Parked list
                if !timer.distractions.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                            ForEach(Array(timer.distractions.enumerated()), id: \.offset) { _, thought in
                                HStack(spacing: DesignTokens.spacingSM) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(DesignTokens.accentComplete.opacity(0.5))
                                    Text(thought)
                                        .font(AppTheme.footnote)
                                        .foregroundStyle(DesignTokens.textSecondary)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }
            .padding(DesignTokens.spacingLG)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.03))
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.bottom, DesignTokens.spacingXXL)
        }
        .background {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(AnimationConstants.springSmooth) {
                        showDistractionCapture = false
                    }
                }
        }
    }
    
    // MARK: - Duration Pill
    
    private func durationPill(label: String, minutes: Int, isSelected: Bool) -> some View {
        Button {
            withAnimation(AnimationConstants.springSmooth) {
                timer.focusMinutes = minutes
            }
            HapticService.shared.actionButtonTap()
        } label: {
            Text(label)
                .font(AppTheme.rounded(.callout, weight: .semibold))
                .foregroundStyle(isSelected ? .white : DesignTokens.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.spacingMD)
                .background {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                        .fill(isSelected ? ringAccentColor.opacity(0.25) : Color.white.opacity(0.10))
                }
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusButton))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                            .strokeBorder(ringAccentColor.opacity(0.4), lineWidth: 1)
                    }
                }
        }
    }
    
    private var customDurationStepper: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            Text(String(localized: "\(timer.focusMinutes) min"))
                .font(AppTheme.rounded(.body, weight: .semibold))
                .foregroundStyle(DesignTokens.textPrimary)
                .monospacedDigit()
            
            Stepper("", value: $timer.focusMinutes, in: 1...120, step: 5)
                .labelsHidden()
                .tint(DesignTokens.accentActive)
        }
        .padding(.horizontal, DesignTokens.spacingXXL)
        .transition(.opacity)
    }
    
    // MARK: - Presets
    
    private var focusPresets: [(label: String, minutes: Int)] {
        [
            ("5", 5),
            ("15", 15),
            ("25", 25),
            ("45", 45),
            ("60", 60)
        ]
    }
    
    // MARK: - Ring Color
    
    private var ringAccentColor: Color {
        switch timer.phase {
        case .setup, .countdown:
            return DesignTokens.accentActive
        case .focusing, .paused:
            if timer.progress < 0.5 {
                return DesignTokens.accentActive
            } else if timer.progress < 0.85 {
                return DesignTokens.accentFocus
            } else {
                return DesignTokens.accentComplete
            }
        case .breakTime:
            return DesignTokens.accentComplete
        case .completed:
            return DesignTokens.accentComplete
        }
    }
    
    // MARK: - Timer Logic
    
    private func beginCountdown() {
        timer.phase = .countdown
        countdownNumber = 3
        countdownVisible = true
        HapticService.shared.micStart()
        
        // 3-2-1 countdown sequence
        Task { @MainActor in
            for i in stride(from: 3, through: 1, by: -1) {
                countdownNumber = i
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    countdownVisible = true
                }
                HapticService.shared.actionButtonTap()
                try? await Task.sleep(for: .seconds(0.8))
                withAnimation(.easeOut(duration: 0.15)) {
                    countdownVisible = false
                }
                try? await Task.sleep(for: .seconds(0.2))
            }
            
            startFocusing()
        }
    }
    
    private func startFocusing() {
        timer.totalSeconds = timer.focusMinutes * 60
        timer.remainingSeconds = timer.totalSeconds
        timer.phase = .focusing
        lastEncouragementElapsed = 0
        
        nudgyExpression = .thinking
        showNudgyMessage(String(localized: "I'll be right here. You've got this! 🐧"))
        
        HapticService.shared.actionButtonTap()
        SoundService.shared.play(.micStart)
        
        startTick()
    }
    
    private func startTick() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                tick()
            }
        }
    }
    
    @MainActor
    private func tick() {
        switch timer.phase {
        case .focusing:
            guard timer.remainingSeconds > 0 else {
                focusSessionComplete()
                return
            }
            timer.remainingSeconds -= 1
            checkEncouragement()
            updateNudgyExpression()
            
        case .breakTime:
            guard timer.breakRemainingSeconds > 0 else {
                breakComplete()
                return
            }
            timer.breakRemainingSeconds -= 1
            
        default:
            break
        }
    }
    
    private func togglePause() {
        if timer.phase == .paused {
            timer.phase = .focusing
            startTick()
            nudgyExpression = .thinking
            showNudgyMessage(String(localized: "Welcome back! Let's keep going 💪"))
        } else {
            timer.phase = .paused
            tickTimer?.invalidate()
            tickTimer = nil
            nudgyExpression = .idle
            showNudgyMessage(String(localized: "Taking a pause. No rush."))
        }
        HapticService.shared.snoozeTimeSelected()
    }
    
    private func extendTimer() {
        timer.totalSeconds += 300  // +5 min
        timer.remainingSeconds += 300
        HapticService.shared.actionButtonTap()
        showNudgyMessage(String(localized: "Added 5 more minutes. You're on a roll! 🔥"))
    }
    
    private func focusSessionComplete() {
        tickTimer?.invalidate()
        tickTimer = nil
        timer.sessionsCompleted += 1
        timer.totalFocusedSeconds += timer.totalSeconds
        
        HapticService.shared.swipeDone()
        SoundService.shared.play(.taskDone)
        
        if timer.sessionsCompleted >= timer.sessionsTarget {
            // All sessions done
            withAnimation(AnimationConstants.springSmooth) {
                timer.phase = .completed
            }
        } else {
            // Start break
            timer.breakTotalSeconds = timer.breakMinutes * 60
            timer.breakRemainingSeconds = timer.breakTotalSeconds
            withAnimation(AnimationConstants.springSmooth) {
                timer.phase = .breakTime
            }
            startTick()
        }
    }
    
    private func breakComplete() {
        tickTimer?.invalidate()
        tickTimer = nil
        HapticService.shared.actionButtonTap()
        SoundService.shared.play(.nudgeKnock)
        showNudgyMessage(String(localized: "Break's over — ready for round \(timer.sessionsCompleted + 1)?"))
    }
    
    private func skipBreak() {
        tickTimer?.invalidate()
        tickTimer = nil
        startNextSession()
    }
    
    private func startNextSession() {
        timer.totalSeconds = timer.focusMinutes * 60
        timer.remainingSeconds = timer.totalSeconds
        withAnimation(AnimationConstants.springSmooth) {
            timer.phase = .focusing
        }
        nudgyExpression = .thinking
        showNudgyMessage(String(localized: "Session \(timer.sessionsCompleted + 1) — let's go! 🔥"))
        startTick()
    }
    
    private func endSession() {
        recordFocusTime()
        tickTimer?.invalidate()
        tickTimer = nil
        
        // Convert parked distractions to new tasks
        if !timer.distractions.isEmpty {
            let repo = NudgeRepository(modelContext: modelContext)
            for thought in timer.distractions {
                _ = repo.createManual(content: thought)
            }
        }
        
        isPresented = false
    }
    
    private func completeTask() {
        recordFocusTime()
        tickTimer?.invalidate()
        tickTimer = nil
        
        let repo = NudgeRepository(modelContext: modelContext)
        repo.markDone(item)
        
        let isAllClear = repo.activeCount() == 0
        RewardService.shared.recordCompletion(context: modelContext, item: item, isAllClear: isAllClear)
        
        HapticService.shared.swipeDone()
        SoundService.shared.play(.taskDone)
        SoundService.shared.play(.fishCaught)
        
        // Convert distractions to tasks
        if !timer.distractions.isEmpty {
            for thought in timer.distractions {
                _ = repo.createManual(content: thought)
            }
        }
        
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        isPresented = false
    }
    
    private func recordFocusTime() {
        guard timer.isActive || timer.phase == .completed else { return }
        let elapsed = timer.totalFocusedSeconds + timer.elapsedSeconds
        if elapsed > 30 {
            item.actualMinutes = (item.actualMinutes ?? 0) + max(1, elapsed / 60)
            item.updatedAt = Date()
            try? modelContext.save()
        }
    }
    
    // MARK: - Distraction Capture
    
    private func commitDistraction() {
        let text = distractionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        timer.distractions.append(text)
        distractionText = ""
        HapticService.shared.actionButtonTap()
        
        showNudgyMessage(String(localized: "Parked it! Back to focus 🎯"))
    }
    
    // MARK: - Nudgy Companion Logic
    
    private func updateNudgyExpression() {
        let progress = timer.progress
        
        if progress > 0.9 {
            nudgyExpression = .celebrating
        } else if progress > 0.75 {
            nudgyExpression = .happy
        } else if progress > 0.5 {
            nudgyExpression = .nudging
        } else {
            nudgyExpression = .thinking
        }
    }
    
    private func showNudgyMessage(_ message: String) {
        nudgyMessage = message
        withAnimation(AnimationConstants.springSmooth) {
            showNudgyBubble = true
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.3)) {
                showNudgyBubble = false
            }
        }
    }
    
    // MARK: - Encouragement System
    
    private let encouragements: [String] = [
        String(localized: "You're doing amazing 🐧"),
        String(localized: "One thing at a time. You've got this."),
        String(localized: "Focus looks good on you ✨"),
        String(localized: "Almost there, stay with it!"),
        String(localized: "Your future self is thanking you."),
        String(localized: "Breathe. You're exactly where you need to be."),
        String(localized: "Small progress is still progress 💪"),
        String(localized: "The hardest part was starting. Look at you go!"),
        String(localized: "Deep breaths. You're doing the thing. 🌊"),
        String(localized: "Time well spent. Keep it up!"),
    ]
    
    private func checkEncouragement() {
        let elapsed = timer.elapsedSeconds
        let interval = 300 // Every 5 minutes
        
        guard elapsed > 0,
              elapsed % interval == 0,
              elapsed != lastEncouragementElapsed else { return }
        
        lastEncouragementElapsed = elapsed
        encouragementText = encouragements.randomElement() ?? ""
        
        withAnimation(.easeOut(duration: 0.5)) {
            showEncouragement = true
        }
        
        // Pulse the play/pause button
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            pulseScale = 1.1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                pulseScale = 1.0
            }
        }
        
        // Auto-hide
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            withAnimation(.easeOut(duration: 0.5)) {
                showEncouragement = false
            }
        }
    }
    
    // MARK: - Ring Breathing Animation
    
    private func startRingBreathingAnimation() {
        guard !reduceMotion else { return }
        // Inhale
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            ringScale = 1.06
            ringGlowIntensity = 0.45
        }
    }
}

// MARK: - Focus Snowflake

private struct FocusSnowflake: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let startY: CGFloat
    let speed: CGFloat
    let size: CGFloat
    let opacity: CGFloat
    let wobbleFreq: CGFloat
    let wobbleAmp: CGFloat
    let spawnTime: TimeInterval
}

// MARK: - Stable RNG for deterministic star field

private struct StableRNG {
    private var state: UInt64
    
    init(seed: UInt64) {
        state = seed
    }
    
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 33) ^ state) / Double(UInt64.max)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var presented = true
    let item = NudgeItem(content: "Call the dentist about appointment", emoji: "📞", estimatedMinutes: 15)
    FocusTimerView(item: item, isPresented: $presented)
        .environment(PenguinState())
}
