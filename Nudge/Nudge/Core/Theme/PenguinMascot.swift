//
//  PenguinMascot.swift
//  Nudge
//
//  Character mascot drawn with SwiftUI bezier Path curves.
//  Matches the app icon penguin (generate_app_icon_v2.py) exactly.
//  See nudge-penguin-spec.md for the full character specification.
//
//  6 expression states: idle, happy, thinking, sleeping, celebrating, thumbsUp.
//  Adapts accent color via accentColor parameter.
//  All animations respect @Environment(\.accessibilityReduceMotion).
//

import SwiftUI

// MARK: - Penguin Expression State

enum PenguinExpression: String, CaseIterable {
    // Original states (rendering preserved)
    case idle         // Neutral — slow blink + gentle sway
    case happy        // Task done — crescent eyes, bounce
    case thinking     // Brain dump processing — tilted head, dots
    case sleeping     // Empty state — closed eyes, content
    case celebrating  // All clear — arms up, sparkles
    case thumbsUp     // Share saved — one arm raised
    
    // New interactive states (will get unique rendering in new penguin)
    // For now they fall through to closest existing expression in PenguinMascot
    case listening    // Brain dump — mic active, leaning forward
    case talking      // Speaking via speech bubble — beak open
    case waving       // Greeting on app open
    case nudging      // Tapping watch, pointing at a task
    case confused     // Voice input unclear / error state
    case typing       // Quick-add mode — pecking motion
}

// MARK: - Color Constants (matches icon generator palette)

private enum PenguinColors {
    static let plumageDark = Color(hex: "1A1A2E")
    static let plumageHighlight = Color(hex: "2A2A42")
    static let bellyTop = Color(hex: "F5F5F7")
    static let bellyBottom = Color(hex: "E8E8EC")
    static let eyeBlack = Color(hex: "0A0A0E")
    static let blush = Color(hex: "FF6B8A")
}

// MARK: - Penguin Mascot View

struct PenguinMascot: View {
    let expression: PenguinExpression
    let size: CGFloat
    var accentColor: Color = DesignTokens.accentActive
    
    @State private var blinkPhase = false
    @State private var swayOffset: CGFloat = 0
    @State private var bounceOffset: CGFloat = 0
    @State private var dotPhase = 0
    @State private var scarfSway: CGFloat = 0
    @State private var breatheScale: CGFloat = 1.0
    @State private var zzzOpacity: [Double] = [0.6, 0.4, 0.2]
    @State private var zzzOffset: [CGFloat] = [0, 0, 0]
    @State private var flipperSway: CGFloat = 0
    @State private var microRotation: Double = 0
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // Reference size — all proportions are fractions of `p`
    // Matches generate_app_icon_v2.py psize exactly.
    private var p: CGFloat { size }
    
    var body: some View {
        ZStack {
            penguinFeet
            penguinBody
            penguinBelly
            penguinWings
            penguinScarf
            penguinHead
            penguinFacePatch
            penguinCheekBlush
            penguinEyes
            penguinEyebrows
            penguinBeak
            penguinAccessories
        }
        .frame(width: size, height: size * 1.15)
        .scaleEffect(breatheScale)
        .rotationEffect(.degrees(reduceMotion ? 0 : microRotation))
        .offset(x: reduceMotion ? 0 : swayOffset, y: bounceOffset)
        .onAppear { startAnimations() }
        .nudgeAccessibility(
            label: penguinAccessibilityLabel,
            traits: .isImage
        )
    }
    
    // ┌────────────────────────────────────────────────────────────┐
    // │  All proportions below are direct ports from the Cairo    │
    // │  icon generator (generate_app_icon_v2.py). The `p`       │
    // │  variable equals `psize` in the Python code.             │
    // │  cx,cy in Python → center of the frame here.             │
    // │  Offsets are relative to frame center (0,0).              │
    // └────────────────────────────────────────────────────────────┘
    
    // MARK: - Body (egg/pear shape — bezier)
    //  Python: body_w = psize * 0.44, body_h = psize * 0.48, offset +8%
    
    private var penguinBody: some View {
        ZStack {
            PenguinBodyShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "343450"), // PLUMAGE_EDGE equivalent
                            PenguinColors.plumageDark,
                            PenguinColors.plumageDark,
                            Color(hex: "343450"),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // Radial gradient overlay for 3D depth
            PenguinBodyShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.04),
                            Color.clear,
                            Color.black.opacity(0.08)
                        ],
                        center: .init(x: 0.4, y: 0.35),
                        startRadius: 0,
                        endRadius: p * 0.5
                    )
                )
        }
        .frame(width: p * 0.88, height: p * 0.96)
        .offset(y: p * 0.08)
        // Subtle drop shadow to ground the penguin
        .shadow(color: Color.black.opacity(0.25), radius: p * 0.04, y: p * 0.03)
    }
    
    // MARK: - Belly (soft oval with vertical gradient)
    //  Python: belly_w = 0.30, belly_h = 0.38, offset +14%
    
    private var penguinBelly: some View {
        ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [PenguinColors.bellyTop, PenguinColors.bellyTop, PenguinColors.bellyBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Inner warmth glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.12), Color.clear],
                        center: .init(x: 0.45, y: 0.4),
                        startRadius: 0,
                        endRadius: p * 0.25
                    )
                )
        }
        .frame(width: p * 0.60, height: p * 0.76)
        .offset(y: p * 0.14)
    }
    
    // MARK: - Head (large round — chibi proportions)
    //  Python: head_r = 0.28, rx = head_r * 1.08, head_cy = -22%
    //  Total: w = 0.56 * 1.08 = ~0.605, h = 0.56
    
    private var penguinHead: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [PenguinColors.plumageHighlight, PenguinColors.plumageDark],
                    center: .init(x: 0.35, y: 0.3),
                    startRadius: 0,
                    endRadius: p * 0.34
                )
            )
            .frame(width: p * 0.605, height: p * 0.56)
            .rotationEffect(.degrees(headTilt))
            .offset(y: -p * 0.22)
    }
    
    // MARK: - Face Patch (white area for eyes/beak)
    //  Python: face_w = 0.20, face_h = 0.17, face_cy = head_cy + 4%
    
    private var penguinFacePatch: some View {
        Ellipse()
            .fill(Color.white)
            .frame(width: p * 0.40, height: p * 0.34)
            .rotationEffect(.degrees(headTilt))
            .offset(y: -p * 0.18)
    }
    
    // MARK: - Eyes
    //  Python: eye_y = head_cy + 1%, eye_spacing = 9.5%
    
    private var penguinEyes: some View {
        HStack(spacing: p * 0.095) {
            eyeView(isRight: false)
            eyeView(isRight: true)
        }
        .rotationEffect(.degrees(headTilt))
        .offset(y: -p * 0.21)
    }
    
    @ViewBuilder
    private func eyeView(isRight: Bool) -> some View {
        // Python: base_r = psize * 0.042, er = base_r * (1.05 if right else 1.0)
        // Diameter = 0.084 (left) / 0.0882 (right)
        let eyeSize = p * (isRight ? 0.088 : 0.084)
        
        switch expression {
        case .idle, .listening, .waving, .nudging, .typing:
            // Round eyes with shine — blink animates height
            ZStack {
                // Eye white ring
                Circle()
                    .fill(Color.white)
                    .frame(width: eyeSize * 1.15, height: blinkPhase ? p * 0.008 : eyeSize * 1.15)
                
                // Pupil
                Circle()
                    .fill(PenguinColors.eyeBlack)
                    .frame(width: eyeSize, height: blinkPhase ? p * 0.006 : eyeSize)
                
                if !blinkPhase {
                    // Main shine (top-right)
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: eyeSize * 0.38, height: eyeSize * 0.38)
                        .offset(x: eyeSize * 0.28, y: -eyeSize * 0.30)
                    
                    // Secondary shine (bottom-left)
                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: eyeSize * 0.18, height: eyeSize * 0.18)
                        .offset(x: -eyeSize * 0.22, y: eyeSize * 0.28)
                }
            }
            
        case .happy, .celebrating, .talking:
            // Crescent "smile" eyes — upward arcs
            CrescentEye()
                .fill(PenguinColors.eyeBlack)
                .frame(width: eyeSize * 1.1, height: eyeSize * 0.45)
            
        case .sleeping:
            // Closed — gentle downward arcs with lash
            SleepingEye()
                .stroke(PenguinColors.eyeBlack, style: StrokeStyle(lineWidth: p * 0.008, lineCap: .round))
                .frame(width: eyeSize * 0.9, height: eyeSize * 0.35)
            
        case .thinking, .confused:
            // Wide open, looking up-right
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: eyeSize * 1.2, height: eyeSize * 1.2)
                Circle()
                    .fill(PenguinColors.eyeBlack)
                    .frame(width: eyeSize * 1.05, height: eyeSize * 1.05)
                    .offset(x: p * 0.006, y: -p * 0.008)
                // Shine
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: eyeSize * 0.38, height: eyeSize * 0.38)
                    .offset(x: eyeSize * 0.18, y: -eyeSize * 0.20)
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: eyeSize * 0.18, height: eyeSize * 0.18)
                    .offset(x: -eyeSize * 0.12, y: eyeSize * 0.18)
            }
            
        case .thumbsUp:
            // Warm, normal, with wink on right eye
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: eyeSize * 1.15, height: eyeSize * 1.15)
                Circle()
                    .fill(PenguinColors.eyeBlack)
                    .frame(width: eyeSize, height: isRight ? eyeSize * 0.25 : eyeSize)
                if !isRight {
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: eyeSize * 0.38, height: eyeSize * 0.38)
                        .offset(x: eyeSize * 0.28, y: -eyeSize * 0.30)
                }
            }
        }
    }
    
    // MARK: - Beak (rounded triangle, accent blue)
    //  Python: beak_w = 0.042, beak_h = 0.035, beak_cy = head_cy + 9.5%
    
    private var penguinBeak: some View {
        BeakShape()
            .fill(
                LinearGradient(
                    colors: [Color(hex: "3399FF"), accentColor],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: p * 0.084, height: p * 0.07)
            .rotationEffect(.degrees(headTilt))
            .offset(y: -p * 0.125)
    }
    
    // MARK: - Cheek Blush
    
    /// Blush intensity increases on happy/celebrating expressions
    private var blushIntensity: Double {
        switch expression {
        case .happy, .celebrating, .talking:  return 0.35
        case .thumbsUp:                        return 0.28
        default:                               return 0.18
        }
    }
    
    //  Python: blush_y = head_cy + 4%, spacing = 14.5%, r = 3.5%
    private var penguinCheekBlush: some View {
        HStack(spacing: p * 0.22) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [PenguinColors.blush.opacity(blushIntensity), PenguinColors.blush.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: p * 0.035
                    )
                )
                .frame(width: p * 0.07, height: p * 0.07)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [PenguinColors.blush.opacity(blushIntensity), PenguinColors.blush.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: p * 0.035
                    )
                )
                .frame(width: p * 0.07, height: p * 0.07)
        }
        .rotationEffect(.degrees(headTilt))
        .offset(y: -p * 0.18)
    }
    
    // MARK: - Eyebrows (expression-specific)
    
    private var penguinEyebrows: some View {
        Group {
            switch expression {
            case .confused:
                HStack(spacing: p * 0.095) {
                    Capsule()
                        .fill(PenguinColors.plumageDark)
                        .frame(width: p * 0.04, height: p * 0.008)
                        .rotationEffect(.degrees(-12))
                    Capsule()
                        .fill(PenguinColors.plumageDark)
                        .frame(width: p * 0.04, height: p * 0.008)
                        .rotationEffect(.degrees(8))
                }
                .offset(y: -p * 0.29)
                
            case .listening:
                HStack(spacing: p * 0.095) {
                    Capsule()
                        .fill(PenguinColors.plumageDark.opacity(0.6))
                        .frame(width: p * 0.035, height: p * 0.007)
                        .rotationEffect(.degrees(-5))
                    Capsule()
                        .fill(PenguinColors.plumageDark.opacity(0.6))
                        .frame(width: p * 0.035, height: p * 0.007)
                        .rotationEffect(.degrees(5))
                }
                .offset(y: -p * 0.29)
                
            case .nudging:
                HStack(spacing: p * 0.095) {
                    Capsule()
                        .fill(PenguinColors.plumageDark)
                        .frame(width: p * 0.038, height: p * 0.008)
                        .rotationEffect(.degrees(8))
                    Capsule()
                        .fill(PenguinColors.plumageDark)
                        .frame(width: p * 0.038, height: p * 0.008)
                        .rotationEffect(.degrees(-8))
                }
                .offset(y: -p * 0.29)
                
            default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Wings (bezier flippers)
    //  Python: wing_w = 0.10, wing_h = 0.22, wing_y = +2%, spacing = 0.74
    
    private var penguinWings: some View {
        HStack(spacing: p * 0.54) {
            // Left wing
            WingShape()
                .fill(
                    LinearGradient(
                        colors: [PenguinColors.plumageDark, PenguinColors.plumageHighlight],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: p * 0.10, height: p * 0.22)
                .rotationEffect(.degrees(leftWingAngle + (reduceMotion ? 0 : Double(flipperSway))))
            
            // Right wing
            WingShape()
                .fill(
                    LinearGradient(
                        colors: [PenguinColors.plumageHighlight, PenguinColors.plumageDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: p * 0.10, height: p * 0.22)
                .scaleEffect(x: -1, y: 1)
                .rotationEffect(.degrees(rightWingAngle - (reduceMotion ? 0 : Double(flipperSway))))
        }
        .offset(y: p * 0.02)
    }
    
    // MARK: - Scarf (accent blue, wraps neck area)
    //  Python: scarf_w = 0.30, scarf_h = 0.035, scarf_y = -6.5%
    //  Thin elegant band, not a giant bib.
    
    private var penguinScarf: some View {
        ScarfShape()
            .fill(
                LinearGradient(
                    colors: [accentColor, accentColor, Color(hex: "0055CC")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                ScarfShape()
                    .stroke(Color(hex: "3399FF").opacity(0.5), lineWidth: p * 0.003)
            )
            .frame(width: p * 0.60, height: p * 0.10)
            .offset(x: reduceMotion ? 0 : scarfSway * 0.5, y: -p * 0.065)
    }
    
    // MARK: - Feet
    //  Python: foot_w = 0.065, foot_h = 0.025, spacing = 0.08, at body_bottom = +50%
    
    private var penguinFeet: some View {
        HStack(spacing: p * 0.10) {
            Capsule()
                .fill(accentColor.opacity(0.7))
                .frame(width: p * 0.065, height: p * 0.025)
                .rotationEffect(.degrees(-8))
            
            Capsule()
                .fill(accentColor.opacity(0.7))
                .frame(width: p * 0.065, height: p * 0.025)
                .rotationEffect(.degrees(8))
        }
        .offset(y: p * 0.50)
    }
    
    // MARK: - Expression-Driven Properties
    
    private var headTilt: Double {
        switch expression {
        case .idle, .waving:   return 3
        case .happy, .talking: return 0
        case .thinking:        return -10
        case .sleeping:        return 6
        case .celebrating:     return 0
        case .thumbsUp:        return -3
        case .listening:       return -5
        case .nudging:         return -8
        case .confused:        return 12
        case .typing:          return -3
        }
    }
    
    private var leftWingAngle: Double {
        switch expression {
        case .celebrating:      return -25
        case .thumbsUp:         return 0
        case .waving:           return -20
        case .nudging:          return -15
        default:                return 8
        }
    }
    
    private var rightWingAngle: Double {
        switch expression {
        case .celebrating:      return 25
        case .thumbsUp:         return -35
        case .waving:           return 30
        case .nudging:          return -20
        default:                return -8
        }
    }
    
    // MARK: - Accessories (expression-dependent overlays)
    
    @ViewBuilder
    private var penguinAccessories: some View {
        switch expression {
        case .thinking:
            // Animated thought dots
            HStack(spacing: p * 0.025) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(accentColor)
                        .frame(width: p * 0.022 + CGFloat(i) * p * 0.005)
                        .opacity(dotPhase == i ? 1.0 : 0.25)
                }
            }
            .offset(x: p * 0.22, y: -p * 0.38)
            
        case .celebrating:
            // Confetti sparkles
            let sparkles: [(CGFloat, CGFloat, Color)] = [
                (-p * 0.28, -p * 0.42, accentColor),
                (p * 0.24, -p * 0.38, DesignTokens.accentComplete),
                (-p * 0.08, -p * 0.50, DesignTokens.accentStale),
                (p * 0.32, -p * 0.28, accentColor),
            ]
            ForEach(0..<sparkles.count, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: p * 0.045, weight: .semibold))
                    .foregroundStyle(sparkles[i].2)
                    .offset(x: sparkles[i].0, y: sparkles[i].1)
                    .opacity(0.85)
            }
            
        case .sleeping:
            // Floating zzz
            ForEach(0..<3, id: \.self) { i in
                Text("z")
                    .font(.system(size: p * (0.045 + CGFloat(i) * 0.010), weight: .medium, design: .rounded))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .opacity(zzzOpacity[i])
                    .offset(
                        x: p * (0.22 + CGFloat(i) * 0.04),
                        y: -p * (0.30 + CGFloat(i) * 0.08) + zzzOffset[i]
                    )
            }
            
        case .thumbsUp:
            // Small heart floating up from right wing
            Image(systemName: "heart.fill")
                .font(.system(size: p * 0.035))
                .foregroundStyle(accentColor)
                .offset(x: p * 0.30, y: -p * 0.05)
                .opacity(0.8)
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        guard !reduceMotion else { return }
        
        // Universal micro-life: subtle breathing on ALL expressions
        // (sleeping overrides with bigger breath below)
        if expression != .sleeping {
            withAnimation(
                .easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
            ) {
                breatheScale = 1.008
            }
        }
        
        // Universal: very subtle micro-rotation (alive feel)
        withAnimation(
            .easeInOut(duration: 5.0)
            .repeatForever(autoreverses: true)
        ) {
            microRotation = 0.8
        }
        
        // Universal: flipper idle sway (±5° gentle oscillation)
        if [.idle, .listening, .talking, .nudging, .typing, .thinking, .confused, .waving].contains(expression) {
            withAnimation(
                .easeInOut(duration: 2.5)
                .repeatForever(autoreverses: true)
            ) {
                flipperSway = 5
            }
        }
        
        switch expression {
        case .idle, .listening, .nudging, .typing:
            startBlinkLoop()
            // Body sway
            withAnimation(
                .easeInOut(duration: AnimationConstants.penguinSwayDuration / 2)
                .repeatForever(autoreverses: true)
            ) {
                swayOffset = AnimationConstants.penguinSwayAmplitude
            }
            // Scarf counter-sway (secondary motion, phase offset)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(
                    .easeInOut(duration: AnimationConstants.penguinSwayDuration / 2)
                    .repeatForever(autoreverses: true)
                ) {
                    scarfSway = -AnimationConstants.penguinSwayAmplitude * 1.5
                }
            }
            
        case .happy:
            withAnimation(AnimationConstants.penguinBounce) {
                bounceOffset = -AnimationConstants.penguinBounceHeight
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(AnimationConstants.penguinBounce) {
                    bounceOffset = 0
                }
            }
            
        case .celebrating, .waving:
            // Double bounce
            withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                bounceOffset = -AnimationConstants.penguinBounceHeight * 1.5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                    bounceOffset = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                        bounceOffset = -AnimationConstants.penguinBounceHeight
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                            bounceOffset = 0
                        }
                    }
                }
            }
            // Excited rapid flap (±15°, 4 cycles)
            startExcitedFlap()
            
        case .thinking, .confused:
            startDotCycle()
            
        case .sleeping:
            // Override breathing to bigger, slower
            breatheScale = 1.0
            withAnimation(
                .easeInOut(duration: 4.0)
                .repeatForever(autoreverses: true)
            ) {
                breatheScale = 1.015
            }
            startZzzAnimation()
            
        case .thumbsUp:
            // Quick nod-like bounce
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                bounceOffset = -4
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    bounceOffset = 0
                }
            }
            
        case .talking:
            // Rhythmic head bob — penguin "talks" with body language
            startTalkingBob()
            // Subtle sway while talking
            withAnimation(
                .easeInOut(duration: 1.8)
                .repeatForever(autoreverses: true)
            ) {
                swayOffset = AnimationConstants.penguinSwayAmplitude * 0.6
            }
        }
    }
    
    private func startBlinkLoop() {
        // Blink for any expression with round open eyes
        let blinkExpressions: [PenguinExpression] = [.idle, .listening, .waving, .nudging, .typing, .thumbsUp]
        guard blinkExpressions.contains(expression), !reduceMotion else { return }
        
        // Add randomness to blink interval (±1.5s) for lifelike feel
        let interval = AnimationConstants.penguinBlinkInterval + Double.random(in: -1.5...1.5)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [self] in
            withAnimation(.easeOut(duration: AnimationConstants.penguinBlinkClose)) { blinkPhase = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + AnimationConstants.penguinBlinkClose + AnimationConstants.penguinBlinkHold) { [self] in
                withAnimation(.easeOut(duration: AnimationConstants.penguinBlinkOpen)) { blinkPhase = false }
                // Occasionally do a double-blink (20% chance) for extra life
                if Bool.random() && Int.random(in: 0...4) == 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.08)) { blinkPhase = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            withAnimation(.easeOut(duration: 0.1)) { blinkPhase = false }
                        }
                    }
                }
                startBlinkLoop()
            }
        }
    }
    
    private func startDotCycle() {
        guard (expression == .thinking || expression == .confused), !reduceMotion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            withAnimation(.easeOut(duration: 0.2)) {
                dotPhase = (dotPhase + 1) % 3
            }
            startDotCycle()
        }
    }
    
    private func startZzzAnimation() {
        guard expression == .sleeping, !reduceMotion else { return }
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            zzzOffset = [-p * 0.02, -p * 0.03, -p * 0.04]
            zzzOpacity = [0.7, 0.5, 0.3]
        }
    }
    
    /// Rhythmic head bob while the penguin "talks"
    private func startTalkingBob() {
        guard expression == .talking, !reduceMotion else { return }
        
        // Small rapid bobs — 3 quick nods with decreasing amplitude
        let bobSequence: [(CGFloat, TimeInterval)] = [
            (-5, 0.0),
            (0, 0.15),
            (-3.5, 0.30),
            (0, 0.42),
            (-2, 0.52),
            (0, 0.62),
        ]
        
        for (offset, delay) in bobSequence {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                    self.bounceOffset = offset
                }
            }
        }
        
        // Loop after a pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [self] in
            startTalkingBob()
        }
    }
    
    /// Excited rapid wing flap for celebrating/happy expressions
    private func startExcitedFlap() {
        guard [.celebrating, .waving, .happy].contains(expression), !reduceMotion else { return }
        
        // 4 rapid flaps: ±15° at 0.15s period
        let flapSequence: [(CGFloat, TimeInterval)] = [
            (15, 0.0), (-15, 0.15), (15, 0.30), (-15, 0.45),
            (10, 0.60), (-10, 0.75), (5, 0.85), (0, 0.95),
        ]
        
        for (angle, delay) in flapSequence {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
                    self.flipperSway = angle
                }
            }
        }
    }
    
    // MARK: - Accessibility
    
    private var penguinAccessibilityLabel: String {
        switch expression {
        case .idle:        return String(localized: "Nudgy the penguin, relaxing")
        case .happy:       return String(localized: "Nudgy celebrating your progress")
        case .thinking:    return String(localized: "Nudgy thinking about your brain dump")
        case .sleeping:    return String(localized: "Nudgy resting, all tasks done")
        case .celebrating: return String(localized: "Nudgy celebrating, all tasks complete!")
        case .thumbsUp:    return String(localized: "Nudgy giving a thumbs up, item saved")
        case .listening:   return String(localized: "Nudgy listening to you")
        case .talking:     return String(localized: "Nudgy talking to you")
        case .waving:      return String(localized: "Nudgy waving hello")
        case .nudging:     return String(localized: "Nudgy reminding you about a task")
        case .confused:    return String(localized: "Nudgy looking confused")
        case .typing:      return String(localized: "Nudgy helping you type")
        }
    }
}

// MARK: - Custom Shapes (Bezier Paths — matches icon generator)

/// Egg/pear body shape — wider at bottom, smooth taper to top
struct PenguinBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        
        return Path { p in
            p.move(to: CGPoint(x: cx, y: 0))
            // Right side — bulge outward
            p.addCurve(
                to: CGPoint(x: cx + w * 0.48, y: h * 0.55),
                control1: CGPoint(x: cx + w * 0.30, y: 0),
                control2: CGPoint(x: cx + w * 0.55, y: h * 0.25)
            )
            // Right bottom curve
            p.addCurve(
                to: CGPoint(x: cx, y: h * 0.95),
                control1: CGPoint(x: cx + w * 0.42, y: h * 0.82),
                control2: CGPoint(x: cx + w * 0.20, y: h)
            )
            // Left bottom curve (mirror)
            p.addCurve(
                to: CGPoint(x: cx - w * 0.48, y: h * 0.55),
                control1: CGPoint(x: cx - w * 0.20, y: h),
                control2: CGPoint(x: cx - w * 0.42, y: h * 0.82)
            )
            // Left side — taper back to top
            p.addCurve(
                to: CGPoint(x: cx, y: 0),
                control1: CGPoint(x: cx - w * 0.55, y: h * 0.25),
                control2: CGPoint(x: cx - w * 0.30, y: 0)
            )
            p.closeSubpath()
        }
    }
}

/// Rounded triangular beak
struct BeakShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        
        return Path { p in
            // Bottom point
            p.move(to: CGPoint(x: cx, y: h))
            // Curve to top-left
            p.addCurve(
                to: CGPoint(x: cx - w * 0.4, y: h * 0.1),
                control1: CGPoint(x: cx - w * 0.15, y: h * 0.4),
                control2: CGPoint(x: cx - w * 0.45, y: h * 0.3)
            )
            // Top arc
            p.addCurve(
                to: CGPoint(x: cx + w * 0.4, y: h * 0.1),
                control1: CGPoint(x: cx - w * 0.2, y: -h * 0.15),
                control2: CGPoint(x: cx + w * 0.2, y: -h * 0.15)
            )
            // Curve back to bottom
            p.addCurve(
                to: CGPoint(x: cx, y: h),
                control1: CGPoint(x: cx + w * 0.45, y: h * 0.3),
                control2: CGPoint(x: cx + w * 0.15, y: h * 0.4)
            )
            p.closeSubpath()
        }
    }
}

/// Crescent "happy" eye — upward curve
struct CrescentEye: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        return Path { p in
            p.move(to: CGPoint(x: 0, y: h * 0.7))
            p.addCurve(
                to: CGPoint(x: w, y: h * 0.7),
                control1: CGPoint(x: w * 0.2, y: -h * 0.3),
                control2: CGPoint(x: w * 0.8, y: -h * 0.3)
            )
            p.addCurve(
                to: CGPoint(x: 0, y: h * 0.7),
                control1: CGPoint(x: w * 0.75, y: h * 0.35),
                control2: CGPoint(x: w * 0.25, y: h * 0.35)
            )
            p.closeSubpath()
        }
    }
}

/// Sleeping eye — gentle closed arc with tiny lash mark
struct SleepingEye: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        return Path { p in
            // Main closed curve
            p.move(to: CGPoint(x: 0, y: h * 0.5))
            p.addCurve(
                to: CGPoint(x: w, y: h * 0.5),
                control1: CGPoint(x: w * 0.3, y: h * 1.2),
                control2: CGPoint(x: w * 0.7, y: h * 1.2)
            )
            // Tiny lash at outer edge
            p.move(to: CGPoint(x: w * 0.9, y: h * 0.6))
            p.addLine(to: CGPoint(x: w, y: h * 0.85))
        }
    }
}

/// Wing/flipper shape — teardrop
struct WingShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        return Path { p in
            p.move(to: CGPoint(x: w * 0.5, y: 0))
            // Outer curve
            p.addCurve(
                to: CGPoint(x: w * 0.7, y: h),
                control1: CGPoint(x: w * 1.1, y: h * 0.15),
                control2: CGPoint(x: w * 1.2, y: h * 0.7)
            )
            // Rounded tip
            p.addCurve(
                to: CGPoint(x: w * 0.3, y: h * 0.92),
                control1: CGPoint(x: w * 0.55, y: h * 1.08),
                control2: CGPoint(x: w * 0.35, y: h * 1.05)
            )
            // Inner curve back to top
            p.addCurve(
                to: CGPoint(x: w * 0.5, y: 0),
                control1: CGPoint(x: w * 0.15, y: h * 0.5),
                control2: CGPoint(x: w * 0.1, y: h * 0.1)
            )
            p.closeSubpath()
        }
    }
}

/// Scarf wrapping neck with trailing tail
struct ScarfShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        return Path { p in
            // Main wrap (left to right across neck)
            p.move(to: CGPoint(x: 0, y: h * 0.25))
            // Top edge curves up
            p.addCurve(
                to: CGPoint(x: w * 0.75, y: h * 0.20),
                control1: CGPoint(x: w * 0.25, y: 0),
                control2: CGPoint(x: w * 0.55, y: 0)
            )
            // Into the tail
            p.addCurve(
                to: CGPoint(x: w, y: h * 0.65),
                control1: CGPoint(x: w * 0.90, y: h * 0.25),
                control2: CGPoint(x: w * 1.0, y: h * 0.45)
            )
            // Tail tip curves down
            p.addCurve(
                to: CGPoint(x: w * 0.72, y: h),
                control1: CGPoint(x: w * 1.0, y: h * 0.80),
                control2: CGPoint(x: w * 0.85, y: h * 0.95)
            )
            // Tail underside back
            p.addCurve(
                to: CGPoint(x: w * 0.65, y: h * 0.50),
                control1: CGPoint(x: w * 0.65, y: h * 0.85),
                control2: CGPoint(x: w * 0.60, y: h * 0.60)
            )
            // Bottom edge of main wrap
            p.addCurve(
                to: CGPoint(x: 0, y: h * 0.55),
                control1: CGPoint(x: w * 0.45, y: h * 0.55),
                control2: CGPoint(x: w * 0.15, y: h * 0.50)
            )
            p.closeSubpath()
        }
    }
}

/// Triangle beak (legacy — kept for backward compatibility)
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

// MARK: - Previews

#Preview("All Expressions") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        LazyVGrid(columns: [.init(), .init(), .init()], spacing: 32) {
            ForEach(PenguinExpression.allCases, id: \.rawValue) { expr in
                VStack(spacing: 8) {
                    PenguinMascot(expression: expr, size: 80)
                    Text(expr.rawValue)
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
        }
        .padding()
    }
}

#Preview("Large Idle") {
    ZStack {
        Color.black.ignoresSafeArea()
        PenguinMascot(expression: .idle, size: 200)
    }
}

/// Interactive preview — tap to cycle through every expression at hero size.
/// Use this to test all animations in real time.
#Preview("🎬 Animation Tester") {
    struct AnimationTester: View {
        @State private var current = 0
        private let expressions = PenguinExpression.allCases
        
        private let descriptions: [PenguinExpression: String] = [
            .idle:        "Gentle sway · blink every ~3.5s · occasional double-blink",
            .happy:       "Single bounce · crescent smile eyes · warm blush",
            .thinking:    "Head tilted left · cycling thought dots · wide eyes",
            .sleeping:    "Slow breathing scale · floating zzz · closed lash eyes",
            .celebrating: "Double bounce · crescent eyes · sparkle accessories",
            .thumbsUp:    "Quick nod · right wink · floating heart",
            .listening:   "Sway + blink · attentive eyebrows · head tilt left",
            .talking:     "Rhythmic head bob (3 nods) · sway · crescent eyes · extra blush",
            .waving:      "Double bounce + blink · arms spread · head tilted right",
            .nudging:     "Stern eyebrows · sway + blink · arms pointing",
            .confused:    "Asymmetric eyebrows · cycling dots · head tilted right 12°",
            .typing:      "Sway + blink · head tilt left · arms at rest",
        ]
        
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Tap Nudgy to cycle expressions")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Spacer()
                    
                    // Expression name
                    Text(expressions[current].rawValue.uppercased())
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    
                    // The penguin at hero size
                    PenguinMascot(
                        expression: expressions[current],
                        size: 240,
                        accentColor: DesignTokens.accentActive
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            current = (current + 1) % expressions.count
                        }
                    }
                    .id(current) // Force re-create to restart animations
                    
                    // "NUDGY" label
                    Text("NUDGY")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                        .tracking(2.0)
                    
                    Spacer()
                    
                    // Animation description
                    Text(descriptions[expressions[current]] ?? "")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // Expression counter
                    Text("\(current + 1) / \(expressions.count)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.bottom, 20)
                }
            }
        }
    }
    
    return AnimationTester()
}
