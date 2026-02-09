//
//  AntarcticEnvironment.swift
//  Nudge
//
//  The Antarctic environment scene — Nudgy's immersive home world.
//
//  A rich, layered parallax scene that changes with time of day and reacts
//  to the user's productivity state (EnvironmentMood).
//
//  Visual layers (back → front):
//    0. Sky gradient (time-of-day driven, mood-modulated)
//    1. Celestial bodies (stars + moon at night, sun glow at dawn/dusk)
//    2. Aurora borealis (night + productive mood)
//    3. Far mountains (darkest, most blue-shifted, 5-6 peaks)
//    4. Mid mountains (medium detail, snow-capped, 4-5 peaks)
//    5. Cloud wisps (atmospheric depth)
//    6. Near mountains (closest, most detailed, 3-4 peaks)
//    7. Ice cliff platform (where Nudgy stands) + icicles below
//    8. Snow particles (code-driven particle system)
//    9. Storm overlay (stormy mood only)
//
//  Modular design: each layer is a separate computed property for easy
//  Phase 2 additions (fish bucket, stairs, furniture props, altitude HUD).
//
//  Time-of-day themes:
//    Dawn  (6am–10am)  — Pink/peach sky, warm mountain silhouettes
//    Day   (10am–5pm)  — Bright cerulean, crisp white peaks
//    Dusk  (5pm–8pm)   — Purple/amber glow, orange-edged ridges
//    Night (8pm–6am)   — Deep navy, aurora, stars, moonlit edges
//

import SwiftUI

// MARK: - Time of Day

/// Determines the visual theme for the Antarctic scene based on the current hour.
enum AntarcticTimeOfDay: CaseIterable {
    case dawn   // 6am – 10am
    case day    // 10am – 5pm
    case dusk   // 5pm – 8pm
    case night  // 8pm – 6am

    /// Determine from the current device time.
    static var current: AntarcticTimeOfDay {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 6..<10:  return .dawn
        case 10..<17: return .day
        case 17..<20: return .dusk
        default:      return .night
        }
    }

    // MARK: Sky Gradients

    var skyColors: [Color] {
        switch self {
        case .dawn:
            return [
                Color(hex: "1A0A2E"),   // Deep violet top
                Color(hex: "3D1A54"),   // Purple
                Color(hex: "8B3A62"),   // Rose
                Color(hex: "D4785A"),   // Warm peach
                Color(hex: "F2A65A"),   // Golden horizon
                Color(hex: "FFD4A0"),   // Pale gold
            ]
        case .day:
            return [
                Color(hex: "0A1628"),   // Deep space blue top
                Color(hex: "1B3A5C"),   // Ocean blue
                Color(hex: "2E6B9E"),   // Cerulean
                Color(hex: "4A9AC7"),   // Sky blue
                Color(hex: "7BBEE0"),   // Pale horizon
                Color(hex: "C4DFF0"),   // Near-white horizon
            ]
        case .dusk:
            return [
                Color(hex: "0D0D2B"),   // Deep indigo top
                Color(hex: "2B1B4E"),   // Purple
                Color(hex: "5C2D6B"),   // Violet
                Color(hex: "8B4A5C"),   // Mauve
                Color(hex: "CC6B3A"),   // Amber
                Color(hex: "E8944A"),   // Warm orange horizon
            ]
        case .night:
            return [
                Color(hex: "020810"),   // Near-black
                Color(hex: "061220"),   // Deep navy
                Color(hex: "0A1A30"),   // Dark navy
                Color(hex: "0E2240"),   // Navy
                Color(hex: "122A4A"),   // Slightly lighter navy
            ]
        }
    }

    // MARK: Mountain Tints

    /// Far mountains — darkest, most atmospheric.
    var farMountainColors: [Color] {
        switch self {
        case .dawn:
            return [Color(hex: "4A2A50").opacity(0.85), Color(hex: "3A1A3A").opacity(0.95)]
        case .day:
            return [Color(hex: "3A5570").opacity(0.75), Color(hex: "2A3A50").opacity(0.9)]
        case .dusk:
            return [Color(hex: "3A1A40").opacity(0.85), Color(hex: "2A1030").opacity(0.95)]
        case .night:
            return [Color(hex: "0A1520").opacity(0.9), Color(hex: "060D15").opacity(0.95)]
        }
    }

    /// Mid mountains — medium detail, snow visible.
    var midMountainColors: [Color] {
        switch self {
        case .dawn:
            return [Color(hex: "6B4A6B").opacity(0.8), Color(hex: "4A2A4A").opacity(0.9)]
        case .day:
            return [Color(hex: "4A6A85").opacity(0.7), Color(hex: "3A4A60").opacity(0.85)]
        case .dusk:
            return [Color(hex: "5A3050").opacity(0.8), Color(hex: "3A1A35").opacity(0.9)]
        case .night:
            return [Color(hex: "121E2E").opacity(0.85), Color(hex: "0A1520").opacity(0.95)]
        }
    }

    /// Near mountains — brightest, most detail.
    var nearMountainColors: [Color] {
        switch self {
        case .dawn:
            return [Color(hex: "8A6080").opacity(0.7), Color(hex: "5A3A55").opacity(0.85)]
        case .day:
            return [Color(hex: "5A8AA5").opacity(0.65), Color(hex: "3A5A75").opacity(0.8)]
        case .dusk:
            return [Color(hex: "7A4560").opacity(0.75), Color(hex: "4A2540").opacity(0.9)]
        case .night:
            return [Color(hex: "1A2A3A").opacity(0.8), Color(hex: "0E1A28").opacity(0.9)]
        }
    }

    /// Snow cap tint on mountain peaks.
    var snowCapColor: Color {
        switch self {
        case .dawn:  return Color(hex: "FFD4C0").opacity(0.6)  // Warm pink snow
        case .day:   return Color.white.opacity(0.7)            // Crisp white
        case .dusk:  return Color(hex: "FFB088").opacity(0.5)  // Amber-lit snow
        case .night: return Color(hex: "A0C0E0").opacity(0.35) // Moonlit blue
        }
    }

    // MARK: Ground / Ice Colors

    var iceCliffTopColor: Color {
        switch self {
        case .dawn:  return Color(hex: "D4B8C4").opacity(0.35)
        case .day:   return Color(hex: "C0D8E8").opacity(0.4)
        case .dusk:  return Color(hex: "B0888A").opacity(0.3)
        case .night: return Color(hex: "4A6A80").opacity(0.25)
        }
    }

    var iceCliffBodyColor: Color {
        switch self {
        case .dawn:  return Color(hex: "8A7A90").opacity(0.5)
        case .day:   return Color(hex: "7A9AB0").opacity(0.5)
        case .dusk:  return Color(hex: "6A4A5A").opacity(0.5)
        case .night: return Color(hex: "2A3A4A").opacity(0.5)
        }
    }

    var icicleColor: Color {
        switch self {
        case .dawn:  return Color(hex: "C0A0B0").opacity(0.4)
        case .day:   return Color(hex: "A0C8E0").opacity(0.5)
        case .dusk:  return Color(hex: "9A7080").opacity(0.35)
        case .night: return Color(hex: "3A5A70").opacity(0.3)
        }
    }

    // MARK: Celestial

    var showStars: Bool { self == .night || self == .dusk }
    var showMoon: Bool { self == .night }
    var showSunGlow: Bool { self == .dawn || self == .dusk }
    var showAurora: Bool { self == .night }
}

// MARK: - Environment Mood

/// Drives the visual mood of the Antarctic scene based on productivity.
/// Composes WITH TimeOfDay — mood adjusts brightness and intensity.
enum EnvironmentMood: Equatable {
    /// No tasks done today — cold, dark, lonely
    case cold
    /// 1-2 tasks done — dawn breaking, warming up
    case warming
    /// 3+ tasks done — bright day, aurora visible
    case productive
    /// All tasks cleared — golden hour, celebration
    case golden
    /// Overdue tasks (3+ days stale) — storm clouds
    case stormy

    /// Brightness multiplier applied to mountains and ground.
    var brightnessFactor: Double {
        switch self {
        case .cold:        return 0.7
        case .warming:     return 0.85
        case .productive:  return 1.0
        case .golden:      return 1.15
        case .stormy:      return 0.5
        }
    }

    /// Aurora intensity (only visible at night).
    var auroraOpacity: Double {
        switch self {
        case .cold:        return 0
        case .warming:     return 0.15
        case .productive:  return 0.4
        case .golden:      return 0.65
        case .stormy:      return 0
        }
    }

    /// Snow particle density multiplier.
    var snowIntensity: Double {
        switch self {
        case .cold:        return 1.0
        case .warming:     return 0.6
        case .productive:  return 0.3
        case .golden:      return 0.15
        case .stormy:      return 1.5
        }
    }
}

// MARK: - Snow Particle

private struct SnowParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let opacity: Double
    let speed: CGFloat
    let drift: CGFloat
    let wobbleAmplitude: CGFloat
    let wobbleSpeed: CGFloat
    var wobblePhase: CGFloat
}

// MARK: - Star

private struct Star: Identifiable {
    let id = UUID()
    let x: CGFloat       // 0–1 fraction
    let y: CGFloat       // 0–1 fraction
    let size: CGFloat
    let brightness: Double
    let twinkleSpeed: Double
}

// MARK: - Antarctic Environment View

struct AntarcticEnvironment: View {

    let mood: EnvironmentMood
    let unlockedProps: Set<String>

    var sceneWidth: CGFloat = 390
    var sceneHeight: CGFloat = 844

    /// Override time of day for previews.
    var timeOverride: AntarcticTimeOfDay?

    /// The Y fraction (from top) where the cliff surface sits.
    /// Nudgy should be positioned at or just above this line.
    static let cliffSurfaceY: CGFloat = 0.78

    @State private var snowParticles: [SnowParticle] = []
    @State private var snowTimer: Timer?
    @State private var stars: [Star] = []
    @State private var auroraPhase: Double = 0
    @State private var twinklePhase: Double = 0
    @State private var windPhase: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var time: AntarcticTimeOfDay { timeOverride ?? .current }

    var body: some View {
        ZStack {
            // Layer 0: Sky gradient
            skyLayer

            // Layer 1: Stars (night/dusk)
            if time.showStars {
                starField
            }

            // Layer 1b: Moon (night)
            if time.showMoon {
                moonLayer
            }

            // Layer 1c: Sun glow (dawn/dusk)
            if time.showSunGlow {
                sunGlowLayer
            }

            // Layer 2: Aurora (night + productive)
            if time.showAurora && mood.auroraOpacity > 0 {
                auroraLayer
            }

            // Layer 3: Far mountains
            farMountains

            // Layer 4: Mid mountains with snow caps
            midMountains

            // Layer 5: Cloud wisps
            if time == .day || time == .dawn {
                cloudWisps
            }

            // Layer 6: Near mountains
            nearMountains

            // Layer 7: Ice cliff platform (where Nudgy stands)
            iceCliffPlatform

            // Layer 8: Snow particles
            if !reduceMotion {
                snowLayer
            }

            // Layer 9: Storm overlay
            if mood == .stormy {
                stormOverlay
            }
        }
        .clipped()
        .onAppear {
            generateStars()
            startSnow()
            startAnimations()
        }
        .onDisappear {
            stopSnow()
        }
        .onChange(of: mood) { _, _ in
            stopSnow()
            startSnow()
        }
    }

    // MARK: - Layer 0: Sky

    private var skyLayer: some View {
        LinearGradient(
            colors: time.skyColors,
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 3.0), value: time)
    }

    // MARK: - Layer 1: Stars

    private var starField: some View {
        Canvas { context, size in
            for star in stars {
                let x = star.x * size.width
                let y = star.y * size.height

                // Twinkle: vary brightness with sin wave
                let twinkle = sin(twinklePhase * star.twinkleSpeed) * 0.3 + 0.7
                let alpha = star.brightness * twinkle * (time == .night ? 1.0 : 0.4)

                context.opacity = alpha
                let rect = CGRect(
                    x: x - star.size / 2,
                    y: y - star.size / 2,
                    width: star.size,
                    height: star.size
                )
                context.fill(Circle().path(in: rect), with: .color(.white))

                // Larger stars get a soft glow
                if star.size > 2.0 {
                    let glowRect = CGRect(
                        x: x - star.size * 1.5,
                        y: y - star.size * 1.5,
                        width: star.size * 3,
                        height: star.size * 3
                    )
                    context.opacity = alpha * 0.2
                    context.fill(Circle().path(in: glowRect), with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Layer 1b: Moon

    private var moonLayer: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "C0D8FF").opacity(0.15),
                            Color(hex: "A0B8E0").opacity(0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)

            // Moon body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "E8F0FF"),
                            Color(hex: "C0D0E8"),
                            Color(hex: "A0B0C8"),
                        ],
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: 18
                    )
                )
                .frame(width: 32, height: 32)

            // Subtle craters
            Circle()
                .fill(Color(hex: "90A0B8").opacity(0.3))
                .frame(width: 6, height: 6)
                .offset(x: 4, y: -3)

            Circle()
                .fill(Color(hex: "90A0B8").opacity(0.2))
                .frame(width: 4, height: 4)
                .offset(x: -5, y: 5)
        }
        .position(x: sceneWidth * 0.8, y: sceneHeight * 0.1)
    }

    // MARK: - Layer 1c: Sun Glow

    private var sunGlowLayer: some View {
        let yPos = time == .dawn ? sceneHeight * 0.38 : sceneHeight * 0.35
        let xPos = time == .dawn ? sceneWidth * 0.7 : sceneWidth * 0.25

        return ZStack {
            // Wide atmospheric glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: time == .dawn ? "FFD080" : "FF8040").opacity(0.3),
                            Color(hex: time == .dawn ? "FFA050" : "CC5020").opacity(0.1),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 250)

            // Core glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: time == .dawn ? "FFF0D0" : "FFB060").opacity(0.5),
                            Color(hex: time == .dawn ? "FFD080" : "FF8040").opacity(0.2),
                            .clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
        }
        .position(x: xPos, y: yPos)
    }

    // MARK: - Layer 2: Aurora Borealis

    private var auroraLayer: some View {
        ZStack {
            AuroraBand(
                color1: Color(hex: "00FF88").opacity(0.25),
                color2: Color(hex: "00AAFF").opacity(0.15),
                phase: auroraPhase
            )
            .offset(y: -sceneHeight * 0.28)

            AuroraBand(
                color1: Color(hex: "AA44FF").opacity(0.12),
                color2: Color(hex: "00FF88").opacity(0.15),
                phase: auroraPhase + 1.8
            )
            .offset(y: -sceneHeight * 0.22)

            AuroraBand(
                color1: Color(hex: "00CCAA").opacity(0.1),
                color2: Color(hex: "4488FF").opacity(0.1),
                phase: auroraPhase + 3.5
            )
            .offset(y: -sceneHeight * 0.16)
        }
        .opacity(mood.auroraOpacity)
    }

    // MARK: - Layer 3: Far Mountains

    private var farMountains: some View {
        VStack(spacing: 0) {
            Spacer()

            MountainRange(
                peaks: [
                    MountainPeak(x: 0.0,  height: 0.2),
                    MountainPeak(x: 0.12, height: 0.55),
                    MountainPeak(x: 0.25, height: 0.35),
                    MountainPeak(x: 0.4,  height: 0.7),
                    MountainPeak(x: 0.55, height: 0.45),
                    MountainPeak(x: 0.7,  height: 0.65),
                    MountainPeak(x: 0.85, height: 0.5),
                    MountainPeak(x: 1.0,  height: 0.3),
                ]
            )
            .fill(
                LinearGradient(
                    colors: time.farMountainColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: sceneHeight * 0.38)
            .opacity(mood.brightnessFactor)
        }
    }

    // MARK: - Layer 4: Mid Mountains

    private var midMountains: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack(alignment: .top) {
                // Mountain body
                MountainRange(
                    peaks: [
                        MountainPeak(x: 0.0,  height: 0.15),
                        MountainPeak(x: 0.15, height: 0.45),
                        MountainPeak(x: 0.3,  height: 0.65),
                        MountainPeak(x: 0.45, height: 0.4),
                        MountainPeak(x: 0.6,  height: 0.75),
                        MountainPeak(x: 0.78, height: 0.5),
                        MountainPeak(x: 1.0,  height: 0.25),
                    ]
                )
                .fill(
                    LinearGradient(
                        colors: time.midMountainColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: sceneHeight * 0.3)
                .opacity(mood.brightnessFactor)

                // Snow caps on mid-range peaks
                MountainSnowCaps(
                    peaks: [
                        MountainPeak(x: 0.15, height: 0.45),
                        MountainPeak(x: 0.3,  height: 0.65),
                        MountainPeak(x: 0.6,  height: 0.75),
                        MountainPeak(x: 0.78, height: 0.5),
                    ],
                    snowDepth: 0.12
                )
                .fill(time.snowCapColor)
                .frame(height: sceneHeight * 0.3)
            }
        }
    }

    // MARK: - Layer 5: Cloud Wisps

    private var cloudWisps: some View {
        Canvas { context, size in
            let baseY = size.height * 0.25
            let clouds: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, alpha: Double)] = [
                (0.15, baseY - 20, 120, 25, 0.08),
                (0.45, baseY + 10, 150, 20, 0.06),
                (0.75, baseY - 35, 100, 22, 0.07),
                (0.3,  baseY + 40, 130, 18, 0.05),
            ]

            for cloud in clouds {
                let x = cloud.x * size.width + CGFloat(sin(windPhase * 0.3 + cloud.x * 10)) * 8
                let rect = CGRect(x: x, y: cloud.y, width: cloud.w, height: cloud.h)
                context.opacity = cloud.alpha
                context.fill(
                    Capsule().path(in: rect),
                    with: .color(.white)
                )
                // Softer inner cloud
                let innerRect = CGRect(
                    x: x + cloud.w * 0.15,
                    y: cloud.y - cloud.h * 0.3,
                    width: cloud.w * 0.7,
                    height: cloud.h * 1.2
                )
                context.opacity = cloud.alpha * 0.6
                context.fill(
                    Capsule().path(in: innerRect),
                    with: .color(.white)
                )
            }
        }
        .blur(radius: 12)
        .allowsHitTesting(false)
    }

    // MARK: - Layer 6: Near Mountains

    private var nearMountains: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack(alignment: .top) {
                MountainRange(
                    peaks: [
                        MountainPeak(x: 0.0,  height: 0.2),
                        MountainPeak(x: 0.2,  height: 0.55),
                        MountainPeak(x: 0.4,  height: 0.35),
                        MountainPeak(x: 0.65, height: 0.6),
                        MountainPeak(x: 0.85, height: 0.4),
                        MountainPeak(x: 1.0,  height: 0.2),
                    ]
                )
                .fill(
                    LinearGradient(
                        colors: time.nearMountainColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: sceneHeight * 0.22)
                .opacity(mood.brightnessFactor)

                // Snow caps on near peaks
                MountainSnowCaps(
                    peaks: [
                        MountainPeak(x: 0.2,  height: 0.55),
                        MountainPeak(x: 0.65, height: 0.6),
                    ],
                    snowDepth: 0.15
                )
                .fill(time.snowCapColor)
                .frame(height: sceneHeight * 0.22)
            }
        }
    }

    // MARK: - Layer 7: Ice Cliff Platform

    /// The ice cliff — a flat-top icy platform that anchors the bottom of the scene.
    /// Nudgy stands on top of this surface. Future Phase 2: fish bucket, stairs, props sit here.
    private var iceCliffPlatform: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack(alignment: .top) {
                // Snow drift on top of cliff
                IceCliffSnowDrift()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25 * mood.brightnessFactor),
                                time.iceCliffTopColor,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 20)
                    .offset(y: -6)

                // Main cliff body
                IceCliffBody()
                    .fill(
                        LinearGradient(
                            colors: [
                                time.iceCliffTopColor,
                                time.iceCliffBodyColor,
                                Color(hex: "0A1520").opacity(0.6),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: sceneHeight * 0.18)

                // Icicles hanging from cliff edge
                IcicleRow(count: 12, maxLength: 35, color: time.icicleColor)
                    .frame(height: 40)
                    .offset(y: 8)

                // Ice texture lines
                IceTextureLines(color: time.icicleColor)
                    .frame(height: sceneHeight * 0.18)
                    .allowsHitTesting(false)
            }
            .frame(height: sceneHeight * (1 - Self.cliffSurfaceY) + 10)
        }
    }

    // MARK: - Layer 8: Snow Particles

    private var snowLayer: some View {
        Canvas { context, size in
            for flake in snowParticles {
                let wobble = sin(flake.wobblePhase) * flake.wobbleAmplitude
                let x = flake.x + wobble
                let rect = CGRect(
                    x: x - flake.size / 2,
                    y: flake.y - flake.size / 2,
                    width: flake.size,
                    height: flake.size
                )
                context.opacity = flake.opacity
                context.fill(Circle().path(in: rect), with: .color(.white))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Layer 9: Storm Overlay

    private var stormOverlay: some View {
        ZStack {
            Color(hex: "0A0A15").opacity(0.35)

            // Wind streaks
            Canvas { context, size in
                for i in 0..<8 {
                    let y = CGFloat(i) * size.height / 8 + CGFloat.random(in: -20...20)
                    let startX = CGFloat.random(in: -50...size.width * 0.3)
                    let path = Path { p in
                        p.move(to: CGPoint(x: startX, y: y))
                        p.addLine(to: CGPoint(
                            x: startX + CGFloat.random(in: 80...200),
                            y: y + CGFloat.random(in: -5...5)
                        ))
                    }
                    context.opacity = 0.08
                    context.stroke(path, with: .color(.white), lineWidth: 1)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Animation Engine

    private func generateStars() {
        stars = (0..<60).map { _ in
            Star(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...0.45),
                size: CGFloat.random(in: 1...3.5),
                brightness: Double.random(in: 0.4...1.0),
                twinkleSpeed: Double.random(in: 0.3...1.5)
            )
        }
    }

    private func startAnimations() {
        guard !reduceMotion else { return }

        withAnimation(.easeInOut(duration: 10.0).repeatForever(autoreverses: true)) {
            auroraPhase = .pi * 2
        }

        withAnimation(.linear(duration: 20.0).repeatForever(autoreverses: false)) {
            windPhase = .pi * 2
        }

        // Twinkle timer
        Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { _ in
            twinklePhase += 0.05
        }
    }

    private func startSnow() {
        guard !reduceMotion else { return }

        let baseCount = Int(25 * mood.snowIntensity)
        snowParticles = (0..<baseCount).map { _ in
            SnowParticle(
                x: CGFloat.random(in: 0...sceneWidth),
                y: CGFloat.random(in: -50...sceneHeight),
                size: CGFloat.random(in: 1.5...4.5),
                opacity: Double.random(in: 0.2...0.6),
                speed: CGFloat.random(in: 12...35),
                drift: CGFloat.random(in: -8...8),
                wobbleAmplitude: CGFloat.random(in: 2...8),
                wobbleSpeed: CGFloat.random(in: 1...3),
                wobblePhase: CGFloat.random(in: 0...(.pi * 2))
            )
        }

        snowTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            let dt: CGFloat = 1.0 / 30.0
            for i in snowParticles.indices {
                snowParticles[i].y += snowParticles[i].speed * dt
                snowParticles[i].x += snowParticles[i].drift * dt
                snowParticles[i].wobblePhase += snowParticles[i].wobbleSpeed * dt

                if snowParticles[i].y > sceneHeight + 10 {
                    snowParticles[i].y = CGFloat.random(in: -30 ... -5)
                    snowParticles[i].x = CGFloat.random(in: 0...sceneWidth)
                }
            }
        }
    }

    private func stopSnow() {
        snowTimer?.invalidate()
        snowTimer = nil
    }
}

// MARK: - Aurora Band Shape

private struct AuroraBand: View {
    let color1: Color
    let color2: Color
    let phase: Double

    var body: some View {
        Canvas { context, size in
            let path = Path { p in
                p.move(to: CGPoint(x: 0, y: size.height * 0.5))

                let steps = 24
                for i in 0...steps {
                    let x = size.width * CGFloat(i) / CGFloat(steps)
                    let wave1 = sin(Double(i) * 0.4 + phase) * 15
                    let wave2 = sin(Double(i) * 0.7 + phase * 0.6) * 8
                    let y = size.height * 0.5 + CGFloat(wave1 + wave2)
                    p.addLine(to: CGPoint(x: x, y: y))
                }

                p.addLine(to: CGPoint(x: size.width, y: size.height))
                p.addLine(to: CGPoint(x: 0, y: size.height))
                p.closeSubpath()
            }

            context.fill(path, with: .linearGradient(
                Gradient(colors: [color1, color2, .clear]),
                startPoint: CGPoint(x: size.width * 0.2, y: 0),
                endPoint: CGPoint(x: size.width * 0.8, y: size.height)
            ))
        }
        .frame(height: 90)
        .blur(radius: 25)
    }
}

// MARK: - Mountain Peak Data

private struct MountainPeak {
    let x: CGFloat      // 0–1 fraction across width
    let height: CGFloat  // 0–1 fraction of available height
}

// MARK: - Mountain Range Shape

private struct MountainRange: Shape {
    let peaks: [MountainPeak]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard peaks.count >= 2 else { return path }

        path.move(to: CGPoint(x: 0, y: rect.height))

        for (i, peak) in peaks.enumerated() {
            let x = peak.x * rect.width
            let y = rect.height * (1 - peak.height)

            if i == 0 {
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                let prev = peaks[i - 1]
                let prevX = prev.x * rect.width
                let prevY = rect.height * (1 - prev.height)

                // Smooth curve between peaks with a valley dip
                let midX = (prevX + x) / 2
                let valleyY = max(prevY, y) + rect.height * 0.08

                path.addCurve(
                    to: CGPoint(x: x, y: y),
                    control1: CGPoint(x: midX - (x - prevX) * 0.1, y: valleyY),
                    control2: CGPoint(x: midX + (x - prevX) * 0.1, y: y + rect.height * 0.02)
                )
            }
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Mountain Snow Caps Shape

private struct MountainSnowCaps: Shape {
    let peaks: [MountainPeak]
    let snowDepth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        for peak in peaks {
            let peakX = peak.x * rect.width
            let peakY = rect.height * (1 - peak.height)
            let snowBottom = peakY + rect.height * peak.height * snowDepth
            let capWidth = rect.width * 0.06

            path.move(to: CGPoint(x: peakX, y: peakY))
            path.addQuadCurve(
                to: CGPoint(x: peakX + capWidth, y: snowBottom),
                control: CGPoint(x: peakX + capWidth * 0.8, y: peakY + (snowBottom - peakY) * 0.3)
            )
            path.addQuadCurve(
                to: CGPoint(x: peakX + capWidth * 0.5, y: snowBottom + 3),
                control: CGPoint(x: peakX + capWidth * 0.8, y: snowBottom + 2)
            )
            path.addQuadCurve(
                to: CGPoint(x: peakX - capWidth * 0.5, y: snowBottom + 2),
                control: CGPoint(x: peakX, y: snowBottom + 5)
            )
            path.addQuadCurve(
                to: CGPoint(x: peakX - capWidth, y: snowBottom),
                control: CGPoint(x: peakX - capWidth * 0.8, y: snowBottom + 1)
            )
            path.addQuadCurve(
                to: CGPoint(x: peakX, y: peakY),
                control: CGPoint(x: peakX - capWidth * 0.8, y: peakY + (snowBottom - peakY) * 0.3)
            )
        }

        return path
    }
}

// MARK: - Ice Cliff Body (the platform from the sketch)

private struct IceCliffBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Top surface — mostly flat with slight undulation
        path.move(to: CGPoint(x: 0, y: rect.height * 0.15))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.08),
            control: CGPoint(x: rect.width * 0.08, y: rect.height * 0.12)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.4, y: rect.height * 0.05),
            control: CGPoint(x: rect.width * 0.28, y: rect.height * 0.03)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.7, y: rect.height * 0.07),
            control: CGPoint(x: rect.width * 0.55, y: rect.height * 0.04)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.12),
            control: CGPoint(x: rect.width * 0.88, y: rect.height * 0.06)
        )

        // Right cliff edge — rough, jagged
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.4))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.92, y: rect.height * 0.6),
            control: CGPoint(x: rect.width * 0.98, y: rect.height * 0.5)
        )
        path.addLine(to: CGPoint(x: rect.width * 0.95, y: rect.height))

        // Bottom — extends off screen
        path.addLine(to: CGPoint(x: 0, y: rect.height))

        // Left cliff edge
        path.addLine(to: CGPoint(x: 0, y: rect.height * 0.4))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.05, y: rect.height * 0.2),
            control: CGPoint(x: rect.width * 0.02, y: rect.height * 0.3)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Ice Cliff Snow Drift

private struct IceCliffSnowDrift: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: 0, y: rect.height))

        let drifts: [(x: CGFloat, y: CGFloat)] = [
            (0.0, 0.8), (0.1, 0.4), (0.2, 0.6), (0.3, 0.3),
            (0.4, 0.5), (0.5, 0.2), (0.6, 0.4), (0.7, 0.3),
            (0.8, 0.5), (0.9, 0.35), (1.0, 0.7),
        ]

        for (i, drift) in drifts.enumerated() {
            let x = drift.x * rect.width
            let y = rect.height * drift.y

            if i == 0 {
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                let prev = drifts[i - 1]
                let prevX = prev.x * rect.width
                path.addQuadCurve(
                    to: CGPoint(x: x, y: y),
                    control: CGPoint(x: (prevX + x) / 2, y: y + 4)
                )
            }
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Icicle Row

private struct IcicleRow: View {
    let count: Int
    let maxLength: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, size in
            let spacing = size.width / CGFloat(count + 1)

            for i in 1...count {
                let x = spacing * CGFloat(i) + CGFloat.random(in: -8...8)
                let length = CGFloat.random(in: maxLength * 0.3...maxLength)
                let width = CGFloat.random(in: 2...5)

                let path = Path { p in
                    p.move(to: CGPoint(x: x - width / 2, y: 0))
                    p.addQuadCurve(
                        to: CGPoint(x: x, y: length),
                        control: CGPoint(x: x - width * 0.3, y: length * 0.7)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: x + width / 2, y: 0),
                        control: CGPoint(x: x + width * 0.3, y: length * 0.3)
                    )
                    p.closeSubpath()
                }

                context.opacity = Double.random(in: 0.3...0.7)
                context.fill(path, with: .color(color))
            }
        }
    }
}

// MARK: - Ice Texture Lines

private struct IceTextureLines: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            // Horizontal cracks
            for i in 0..<5 {
                let y = size.height * CGFloat(i + 1) / 6
                let startX = CGFloat.random(in: 0...size.width * 0.3)
                let endX = startX + CGFloat.random(in: size.width * 0.2...size.width * 0.5)

                let path = Path { p in
                    p.move(to: CGPoint(x: startX, y: y))
                    p.addQuadCurve(
                        to: CGPoint(x: endX, y: y + CGFloat.random(in: -8...8)),
                        control: CGPoint(x: (startX + endX) / 2, y: y + CGFloat.random(in: -5...5))
                    )
                }

                context.opacity = 0.12
                context.stroke(path, with: .color(color), lineWidth: 0.5)
            }

            // Vertical veins
            for i in 0..<3 {
                let x = size.width * CGFloat(i + 1) / 4
                let startY = CGFloat.random(in: 0...size.height * 0.2)
                let endY = startY + CGFloat.random(in: size.height * 0.3...size.height * 0.6)

                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: startY))
                    p.addQuadCurve(
                        to: CGPoint(x: x + CGFloat.random(in: -15...15), y: endY),
                        control: CGPoint(x: x + CGFloat.random(in: -10...10), y: (startY + endY) / 2)
                    )
                }

                context.opacity = 0.08
                context.stroke(path, with: .color(color), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Previews

#Preview("Dawn — Warming") {
    AntarcticEnvironment(mood: .warming, unlockedProps: [], timeOverride: .dawn)
        .ignoresSafeArea()
}

#Preview("Day — Productive") {
    AntarcticEnvironment(mood: .productive, unlockedProps: ["igloo"], timeOverride: .day)
        .ignoresSafeArea()
}

#Preview("Dusk — Cold") {
    AntarcticEnvironment(mood: .cold, unlockedProps: [], timeOverride: .dusk)
        .ignoresSafeArea()
}

#Preview("Night — Golden") {
    AntarcticEnvironment(mood: .golden, unlockedProps: ["igloo", "campfire"], timeOverride: .night)
        .ignoresSafeArea()
}

#Preview("Night — Stormy") {
    AntarcticEnvironment(mood: .stormy, unlockedProps: [], timeOverride: .night)
        .ignoresSafeArea()
}
