//
//  StageEvolution.swift
//  Nudge
//
//  Stage evolution system — the ice cliff transforms as the player levels up.
//
//  Each "stage" is a tier of levels that changes the cliff's visual theme:
//    Stage 1 (Lv 1–3):  Bare Ice        — plain cliff, no extras
//    Stage 2 (Lv 4–6):  Snow Nest       — snow buildup, cozy nook, warmer glow
//    Stage 3 (Lv 7–9):  Fishing Pier    — wooden dock extension, fishing line, more fish
//    Stage 4 (Lv 10–14): Cozy Camp      — tent/igloo backdrop, campfire warmth, stargazing
//    Stage 5 (Lv 15+):  Summit Lodge    — full lodge silhouette, smoke chimney, aurora crown
//
//  The AntarcticEnvironment reads the current stage and overlays the appropriate
//  decorations on top of the base cliff platform.
//

import SwiftUI

// MARK: - Stage Tier

enum StageTier: Int, CaseIterable, Comparable {
    case bareIce     = 1  // Lv 1–3
    case snowNest    = 2  // Lv 4–6
    case fishingPier = 3  // Lv 7–9
    case cozyCamp    = 4  // Lv 10–14
    case summitLodge = 5  // Lv 15+

    static func from(level: Int) -> StageTier {
        switch level {
        case 1...3:   return .bareIce
        case 4...6:   return .snowNest
        case 7...9:   return .fishingPier
        case 10...14: return .cozyCamp
        default:      return .summitLodge
        }
    }

    static func < (lhs: StageTier, rhs: StageTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .bareIce:     return String(localized: "Bare Ice")
        case .snowNest:    return String(localized: "Snow Nest")
        case .fishingPier: return String(localized: "Fishing Pier")
        case .cozyCamp:    return String(localized: "Cozy Camp")
        case .summitLodge: return String(localized: "Summit Lodge")
        }
    }

    var stageNumber: Int { rawValue }
}

// MARK: - Stage Decorations View

/// Decorative overlays drawn on the ice cliff based on the current stage tier.
/// Positioned in the AntarcticEnvironment at the cliff surface.
struct StageDecorations: View {
    let stage: StageTier
    let time: AntarcticTimeOfDay
    let mood: EnvironmentMood

    var body: some View {
        ZStack {
            switch stage {
            case .bareIce:
                // Stage 1: just a few extra snow mounds
                bareIceDecorations

            case .snowNest:
                // Stage 2: cozy snow walls + small shelter outline
                snowNestDecorations

            case .fishingPier:
                // Stage 3: wooden dock extending off the cliff
                fishingPierDecorations

            case .cozyCamp:
                // Stage 4: igloo silhouette + campfire
                cozyCampDecorations

            case .summitLodge:
                // Stage 5: full lodge + chimney smoke
                summitLodgeDecorations
            }
        }
    }

    // MARK: - Stage 1: Bare Ice

    private var bareIceDecorations: some View {
        Canvas { context, size in
            // Small snow mounds scattered on cliff surface
            let mounds: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = [
                (0.2, 0.85, 30, 8),
                (0.65, 0.9, 25, 6),
                (0.45, 0.88, 20, 5),
            ]

            for mound in mounds {
                let cx = size.width * mound.x
                let cy = size.height * mound.y
                let rect = CGRect(
                    x: cx - mound.w / 2,
                    y: cy - mound.h / 2,
                    width: mound.w,
                    height: mound.h
                )
                context.opacity = 0.2
                context.fill(
                    Ellipse().path(in: rect),
                    with: .color(.white)
                )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Stage 2: Snow Nest

    private var snowNestDecorations: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Snow wall (left side) — curved barrier
            let wallPath = Path { p in
                p.move(to: CGPoint(x: w * 0.03, y: h * 0.75))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.18, y: h * 0.72),
                    control: CGPoint(x: w * 0.1, y: h * 0.65))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.22, y: h * 0.78),
                    control: CGPoint(x: w * 0.21, y: h * 0.7))
                p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.82))
                p.addLine(to: CGPoint(x: w * 0.03, y: h * 0.82))
                p.closeSubpath()
            }
            context.opacity = 0.25
            context.fill(wallPath, with: .color(.white))
            context.opacity = 0.15
            context.stroke(wallPath, with: .color(.white), lineWidth: 0.5)

            // Small snow shelter nook (right side)
            let nookPath = Path { p in
                p.move(to: CGPoint(x: w * 0.78, y: h * 0.78))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.88, y: h * 0.68),
                    control: CGPoint(x: w * 0.82, y: h * 0.68))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.96, y: h * 0.76),
                    control: CGPoint(x: w * 0.94, y: h * 0.66))
                p.addLine(to: CGPoint(x: w * 0.96, y: h * 0.82))
                p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.82))
                p.closeSubpath()
            }
            context.opacity = 0.2
            context.fill(nookPath, with: .color(.white))

            // Extra snow mounds near the nest
            let mounds: [(CGFloat, CGFloat, CGFloat)] = [
                (0.3, 0.81, 15), (0.5, 0.83, 12), (0.7, 0.8, 18),
            ]
            for (mx, my, r) in mounds {
                let rect = CGRect(
                    x: w * mx - r, y: h * my - r * 0.4,
                    width: r * 2, height: r * 0.8
                )
                context.opacity = 0.15
                context.fill(Ellipse().path(in: rect), with: .color(.white))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Stage 3: Fishing Pier

    private var fishingPierDecorations: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let boardColor = Color(hex: "5A3E1A").opacity(0.5)
            let ropeColor = Color(hex: "8B7355").opacity(0.4)

            // Wooden dock extending from cliff edge (left side)
            // Planks
            for i in 0..<5 {
                let y = h * 0.76 + CGFloat(i) * 3
                let plank = CGRect(
                    x: w * 0.02, y: y,
                    width: w * 0.2, height: 2
                )
                context.opacity = 0.5
                context.fill(
                    RoundedRectangle(cornerRadius: 0.5).path(in: plank),
                    with: .color(boardColor)
                )
            }

            // Support posts
            for xFrac in [0.05, 0.15] as [CGFloat] {
                let post = CGRect(
                    x: w * xFrac - 1.5, y: h * 0.75,
                    width: 3, height: h * 0.2
                )
                context.opacity = 0.4
                context.fill(
                    RoundedRectangle(cornerRadius: 1).path(in: post),
                    with: .color(boardColor)
                )
            }

            // Fishing line — thin diagonal line from dock end
            let linePath = Path { p in
                p.move(to: CGPoint(x: w * 0.04, y: h * 0.74))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.08, y: h * 0.98),
                    control: CGPoint(x: w * 0.02, y: h * 0.88))
            }
            context.opacity = 0.3
            context.stroke(linePath, with: .color(ropeColor), lineWidth: 0.7)

            // Tiny bobber at line end
            let bobber = CGRect(
                x: w * 0.07, y: h * 0.96,
                width: 4, height: 4
            )
            context.opacity = 0.6
            context.fill(Circle().path(in: bobber), with: .color(Color(hex: "FF453A")))

            // Right side: rope railing
            let ropePath = Path { p in
                p.move(to: CGPoint(x: w * 0.8, y: h * 0.73))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.95, y: h * 0.72),
                    control: CGPoint(x: w * 0.87, y: h * 0.76))
            }
            context.opacity = 0.25
            context.stroke(ropePath, with: .color(ropeColor), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Stage 4: Cozy Camp

    private var cozyCampDecorations: some View {
        ZStack {
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // Igloo silhouette (back-right)
                let igloo = Path { p in
                    p.addArc(
                        center: CGPoint(x: w * 0.82, y: h * 0.78),
                        radius: w * 0.08,
                        startAngle: .degrees(180),
                        endAngle: .degrees(0),
                        clockwise: false
                    )
                    p.addLine(to: CGPoint(x: w * 0.9, y: h * 0.82))
                    p.addLine(to: CGPoint(x: w * 0.74, y: h * 0.82))
                    p.closeSubpath()
                }
                context.opacity = 0.2
                context.fill(igloo, with: .color(.white))
                context.opacity = 0.3
                context.stroke(igloo, with: .color(.white), lineWidth: 0.8)

                // Igloo entrance (dark semicircle)
                let entrance = Path { p in
                    p.addArc(
                        center: CGPoint(x: w * 0.82, y: h * 0.82),
                        radius: w * 0.025,
                        startAngle: .degrees(180),
                        endAngle: .degrees(0),
                        clockwise: false
                    )
                    p.closeSubpath()
                }
                context.opacity = 0.3
                context.fill(entrance, with: .color(Color(hex: "0A1520")))

                // Block lines on igloo
                for row in 1...3 {
                    let lineY = h * 0.78 - CGFloat(row) * 4
                    let linePath = Path { p in
                        let angle1 = Double(row) * 15 + 180
                        let angle2 = 360 - Double(row) * 15
                        let r = w * 0.08
                        let cx = w * 0.82
                        let cy = h * 0.78
                        let x1 = cx + r * cos(angle1 * .pi / 180)
                        let x2 = cx + r * cos(angle2 * .pi / 180)
                        p.move(to: CGPoint(x: x1, y: lineY))
                        p.addLine(to: CGPoint(x: x2, y: lineY))
                    }
                    context.opacity = 0.1
                    context.stroke(linePath, with: .color(.white), lineWidth: 0.3)
                }
            }

            // Campfire (animated warm glow)
            campfireGlow
        }
        .allowsHitTesting(false)
    }

    private var campfireGlow: some View {
        GeometryReader { geo in
            let cx = geo.size.width * 0.35
            let cy = geo.size.height * 0.77

            ZStack {
                // Warm ground glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "FF6B00").opacity(0.15),
                                Color(hex: "FF4500").opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 30
                        )
                    )
                    .frame(width: 60, height: 60)

                // Fire core
                Canvas { context, size in
                    // Logs (X shape)
                    let logPath = Path { p in
                        p.move(to: CGPoint(x: size.width * 0.3, y: size.height * 0.7))
                        p.addLine(to: CGPoint(x: size.width * 0.7, y: size.height * 0.5))
                        p.move(to: CGPoint(x: size.width * 0.7, y: size.height * 0.7))
                        p.addLine(to: CGPoint(x: size.width * 0.3, y: size.height * 0.5))
                    }
                    context.opacity = 0.4
                    context.stroke(logPath, with: .color(Color(hex: "5A3E1A")), lineWidth: 2)

                    // Flame shapes
                    let flamePath = Path { p in
                        p.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.2))
                        p.addQuadCurve(
                            to: CGPoint(x: size.width * 0.6, y: size.height * 0.6),
                            control: CGPoint(x: size.width * 0.7, y: size.height * 0.35))
                        p.addQuadCurve(
                            to: CGPoint(x: size.width * 0.4, y: size.height * 0.6),
                            control: CGPoint(x: size.width * 0.5, y: size.height * 0.65))
                        p.addQuadCurve(
                            to: CGPoint(x: size.width * 0.5, y: size.height * 0.2),
                            control: CGPoint(x: size.width * 0.3, y: size.height * 0.35))
                    }
                    context.opacity = 0.7
                    context.fill(flamePath, with: .linearGradient(
                        Gradient(colors: [
                            Color(hex: "FFD700"),
                            Color(hex: "FF6B00"),
                            Color(hex: "FF453A"),
                        ]),
                        startPoint: CGPoint(x: size.width * 0.5, y: size.height * 0.2),
                        endPoint: CGPoint(x: size.width * 0.5, y: size.height * 0.6)
                    ))
                }
                .frame(width: 20, height: 24)
            }
            .position(x: cx, y: cy)
        }
    }

    // MARK: - Stage 5: Summit Lodge

    private var summitLodgeDecorations: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Lodge silhouette (back center-right)
            let lodge = Path { p in
                // Walls
                p.move(to: CGPoint(x: w * 0.6, y: h * 0.82))
                p.addLine(to: CGPoint(x: w * 0.6, y: h * 0.66))
                // Peaked roof
                p.addLine(to: CGPoint(x: w * 0.7, y: h * 0.58))
                p.addLine(to: CGPoint(x: w * 0.95, y: h * 0.58))
                p.addLine(to: CGPoint(x: w * 0.98, y: h * 0.65))
                // Right wall
                p.addLine(to: CGPoint(x: w * 0.98, y: h * 0.82))
                p.closeSubpath()
            }
            context.opacity = 0.18
            context.fill(lodge, with: .color(Color(hex: "3A2510")))
            context.opacity = 0.25
            context.stroke(lodge, with: .color(Color(hex: "5A3E1A")), lineWidth: 0.8)

            // Windows (warm glow)
            let windows: [(CGFloat, CGFloat)] = [(0.68, 0.72), (0.78, 0.72), (0.88, 0.72)]
            for (wx, wy) in windows {
                let wRect = CGRect(
                    x: w * wx - 3, y: h * wy - 3,
                    width: 6, height: 6
                )
                let glowColor = time == .night || time == .dusk
                    ? Color(hex: "FFD060").opacity(0.6)
                    : Color(hex: "FFD060").opacity(0.2)
                context.fill(
                    RoundedRectangle(cornerRadius: 1).path(in: wRect),
                    with: .color(glowColor)
                )
            }

            // Chimney
            let chimney = CGRect(
                x: w * 0.92 - 3, y: h * 0.52,
                width: 6, height: h * 0.13
            )
            context.opacity = 0.2
            context.fill(
                RoundedRectangle(cornerRadius: 1).path(in: chimney),
                with: .color(Color(hex: "4A3520"))
            )

            // Smoke wisps (night/dusk only)
            if time == .night || time == .dusk {
                let smokePuffs: [(CGFloat, CGFloat, CGFloat)] = [
                    (0.92, 0.48, 5), (0.91, 0.43, 7), (0.93, 0.38, 6),
                ]
                for (sx, sy, sr) in smokePuffs {
                    let rect = CGRect(
                        x: w * sx - sr, y: h * sy - sr,
                        width: sr * 2, height: sr * 2
                    )
                    context.opacity = 0.08
                    context.fill(Circle().path(in: rect), with: .color(.white))
                }
            }

            // Front porch / deck
            let deck = CGRect(
                x: w * 0.58, y: h * 0.8,
                width: w * 0.42, height: h * 0.03
            )
            context.opacity = 0.15
            context.fill(
                RoundedRectangle(cornerRadius: 1).path(in: deck),
                with: .color(Color(hex: "5A3E1A"))
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Stage Badge (mini overlay showing stage name)

/// Small badge that flashes when the player reaches a new stage.
struct StageBadge: View {
    let stage: StageTier

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: stageIcon)
                .font(.system(size: 10, weight: .bold))

            Text(stage.displayName.uppercased())
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var stageIcon: String {
        switch stage {
        case .bareIce:     return "snowflake"
        case .snowNest:    return "house.fill"
        case .fishingPier: return "fish.fill"
        case .cozyCamp:    return "flame.fill"
        case .summitLodge: return "building.2.fill"
        }
    }
}

// MARK: - Preview

#Preview("All Stages") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(StageTier.allCases, id: \.rawValue) { stage in
                ZStack {
                    Color(hex: "0A1520")
                    StageDecorations(stage: stage, time: .night, mood: .productive)
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    StageBadge(stage: stage)
                        .padding(8),
                    alignment: .topLeading
                )
            }
        }
        .padding()
    }
    .background(Color.black)
}
