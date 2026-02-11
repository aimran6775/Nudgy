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
        case ...0:    return .bareIce
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
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // ── Snow Drifts — layered with shadows + frost highlight ──
            ForEach(Array(bareIceDrifts.enumerated()), id: \.offset) { _, d in
                // Shadow
                SnowDriftShape()
                    .fill(Color(hex: "0A1828").opacity(0.3))
                    .frame(width: w * d.wF, height: h * d.hF)
                    .position(x: w * d.x + 1.5, y: h * d.y + 2.5)
                // Body
                SnowDriftShape()
                    .fill(
                        LinearGradient(
                            colors: d.colors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: w * d.wF, height: h * d.hF)
                    .position(x: w * d.x, y: h * d.y)
                // Frost highlight
                SnowDriftShape()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.6), Color.white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
                    .frame(width: w * d.wF, height: h * d.hF)
                    .position(x: w * d.x, y: h * d.y)
            }

            // ── Ice crack networks ──
            IceCrackShape()
                .stroke(Color(hex: "7AB0D4").opacity(0.6), lineWidth: 1.2)
                .frame(width: w * 0.32, height: 14)
                .position(x: w * 0.26, y: h * 0.885)

            IceCrackShape()
                .stroke(Color(hex: "6A9CC0").opacity(0.4), lineWidth: 0.9)
                .frame(width: w * 0.24, height: 10)
                .position(x: w * 0.68, y: h * 0.878)
                .rotationEffect(.degrees(4))

            // ── Frost sparkles ──
            ForEach(Array(frostSparkles.enumerated()), id: \.offset) { _, s in
                Circle()
                    .fill(Color.white.opacity(s.a))
                    .frame(width: s.sz, height: s.sz)
                    .position(x: w * s.x, y: h * s.y)
            }
        }
        .allowsHitTesting(false)
    }

    nonisolated private static let bareIceDriftData: [(x: CGFloat, y: CGFloat, wF: CGFloat, hF: CGFloat, c: [UInt])] = [
        (0.12, 0.832, 0.26, 0.055, [0xF4F9FF, 0xD8E8F6, 0xB4D0E8, 0x94B8D6]),
        (0.36, 0.858, 0.18, 0.038, [0xEEF5FC, 0xC8DEF0, 0xA4C4DC]),
        (0.55, 0.840, 0.22, 0.050, [0xF0F7FF, 0xD0E4F4, 0xB0CCE4, 0xAAC8E0]),
        (0.74, 0.852, 0.15, 0.032, [0xEAF3FC, 0xB8D4EC, 0x98BAD8]),
        (0.90, 0.836, 0.24, 0.048, [0xECF5FC, 0xCCDFF0, 0xA8C4E0, 0xA4C0DC]),
        (0.46, 0.874, 0.12, 0.025, [0xD8E8F6, 0xB0CCE0, 0xA8C4DC]),
    ]
    private var bareIceDrifts: [(x: CGFloat, y: CGFloat, wF: CGFloat, hF: CGFloat, colors: [Color])] {
        Self.bareIceDriftData.map { d in
            (d.x, d.y, d.wF, d.hF, d.c.map { Color(hex: String(format: "%06X", $0)) })
        }
    }

    nonisolated private static let frostSparkleData: [(x: CGFloat, y: CGFloat, sz: CGFloat, a: CGFloat)] = [
        (0.16, 0.828, 3, 0.7), (0.38, 0.848, 2.5, 0.55), (0.54, 0.836, 3, 0.65),
        (0.72, 0.850, 2.5, 0.5), (0.28, 0.878, 2, 0.4), (0.84, 0.830, 3, 0.6),
        (0.48, 0.868, 2, 0.45), (0.64, 0.842, 2.5, 0.5),
    ]
    private var frostSparkles: [(x: CGFloat, y: CGFloat, sz: CGFloat, a: CGFloat)] {
        Self.frostSparkleData
    }

    // MARK: - Stage 2: Snow Nest

    private var snowNestDecorations: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // ── Left snow wall ──
            // Shadow
            SnowWallShape(side: .left)
                .fill(Color(hex: "0A1828").opacity(0.3))
                .frame(width: w * 0.32, height: h * 0.24)
                .position(x: w * 0.16 + 2, y: h * 0.72 + 3)
            // Fill
            SnowWallShape(side: .left)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "F4F9FF"), Color(hex: "DCE8F6"), Color(hex: "C0D4EA"), Color(hex: "A0BCD8")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: w * 0.32, height: h * 0.24)
                .position(x: w * 0.16, y: h * 0.72)
            // Highlight
            SnowWallShape(side: .left)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color(hex: "90B0CC").opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
                .frame(width: w * 0.32, height: h * 0.24)
                .position(x: w * 0.16, y: h * 0.72)

            // ── Right snow shelter ──
            // Shadow
            SnowWallShape(side: .right)
                .fill(Color(hex: "0A1828").opacity(0.25))
                .frame(width: w * 0.32, height: h * 0.26)
                .position(x: w * 0.86 + 2, y: h * 0.71 + 3)
            // Fill
            SnowWallShape(side: .right)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "F0F6FF"), Color(hex: "D4E4F6"), Color(hex: "B8CCE4"), Color(hex: "98B4D0")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: w * 0.32, height: h * 0.26)
                .position(x: w * 0.86, y: h * 0.71)
            // Highlight
            SnowWallShape(side: .right)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.5), Color(hex: "88AAC4").opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.2
                )
                .frame(width: w * 0.32, height: h * 0.26)
                .position(x: w * 0.86, y: h * 0.71)

            // ── Shelter entrance ──
            ShelterEntranceShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "060E18"), Color(hex: "142232")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 30, height: 18)
                .position(x: w * 0.86, y: h * 0.81)

            // Entrance warm glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "FFB060").opacity(0.45), Color(hex: "FF8830").opacity(0.15), .clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: 20
                    )
                )
                .frame(width: 36, height: 18)
                .position(x: w * 0.86, y: h * 0.82)

            // ── Snow mounds ──
            ForEach(Array(snowNestMounds.enumerated()), id: \.offset) { _, m in
                SnowDriftShape()
                    .fill(Color(hex: "0A1828").opacity(0.2))
                    .frame(width: m.w, height: m.h)
                    .position(x: w * m.x + 1, y: h * m.y + 2)
                SnowDriftShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "ECF4FB"), Color(hex: "C4D8EE"), Color(hex: "A8C0DA")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: m.w, height: m.h)
                    .position(x: w * m.x, y: h * m.y)
            }
        }
        .allowsHitTesting(false)
    }

    private var snowNestMounds: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] {
        [(0.36, 0.84, 50, 18), (0.52, 0.86, 40, 14), (0.66, 0.845, 34, 12)]
    }

    // MARK: - Stage 3: Fishing Pier

    private var fishingPierDecorations: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // ── Support posts ──
            ForEach([0.04, 0.13, 0.22] as [CGFloat], id: \.self) { xFrac in
                // Post shadow
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "0A0A0A").opacity(0.25))
                    .frame(width: 12, height: h * 0.26)
                    .position(x: w * xFrac + 1.5, y: h * 0.87 + 2)
                // Post body
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "7A5830"), Color(hex: "5A3E1A"), Color(hex: "3A2510"), Color(hex: "2A1808")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 12, height: h * 0.26)
                    .position(x: w * xFrac, y: h * 0.87)
                // Post highlight edge
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(hex: "8B6B3A").opacity(0.4), lineWidth: 0.6)
                    .frame(width: 12, height: h * 0.26)
                    .position(x: w * xFrac, y: h * 0.87)
            }

            // Cross braces
            CrossBraceShape()
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "5A3818"), Color(hex: "3A2510")],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2.5
                )
                .frame(width: w * 0.20, height: h * 0.12)
                .position(x: w * 0.13, y: h * 0.87)

            // ── Dock planks ──
            ForEach(0..<8, id: \.self) { i in
                let y = h * 0.73 + CGFloat(i) * 5.5
                let shade = i % 2 == 0 ? "8B6B3A" : "7A5E30"
                // Plank shadow
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(hex: "0A0A0A").opacity(0.15))
                    .frame(width: w * 0.28, height: 6)
                    .position(x: w * 0.13 + 1, y: y + 1)
                // Plank body
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: shade), Color(hex: "5A3E1A"), Color(hex: "4A3018")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: w * 0.28, height: 6)
                    .position(x: w * 0.13, y: y)
                // Wood grain line
                Rectangle()
                    .fill(Color(hex: "6B5028").opacity(0.3))
                    .frame(width: w * 0.24, height: 0.5)
                    .position(x: w * 0.13, y: y)
            }

            // ── Fishing rod ──
            // Rod shadow
            FishingRodShape()
                .stroke(Color(hex: "0A0A0A").opacity(0.2), lineWidth: 4)
                .frame(width: w * 0.14, height: h * 0.34)
                .position(x: w * 0.03 + 1, y: h * 0.56 + 2)
            // Rod body (bamboo gradient)
            FishingRodShape()
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "6B4A1A"), Color(hex: "8B6830"), Color(hex: "4A2D0A")],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 3.5
                )
                .frame(width: w * 0.14, height: h * 0.34)
                .position(x: w * 0.03, y: h * 0.56)

            // Fishing line
            FishingLineShape()
                .stroke(Color(hex: "B0B0B0"), lineWidth: 1)
                .frame(width: w * 0.12, height: h * 0.52)
                .position(x: w * 0.02, y: h * 0.72)

            // ── Bobber ──
            ZStack {
                // Splash ring
                Ellipse()
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
                    .frame(width: 18, height: 6)
                    .offset(y: 5)
                // Red top
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "FF6050"), Color(hex: "FF453A"), Color(hex: "CC2020")],
                            center: .init(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: 7
                        )
                    )
                // White bottom half
                Ellipse()
                    .fill(Color.white)
                    .frame(width: 12, height: 7)
                    .offset(y: 2)
                // Shine dot
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 3, height: 3)
                    .offset(x: -2, y: -2)
            }
            .frame(width: 14, height: 14)
            .position(x: w * 0.05, y: h * 0.96)

            // ── Right: rope railing ──
            ForEach([0.78, 0.96] as [CGFloat], id: \.self) { xFrac in
                VStack(spacing: 0) {
                    // Cap
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(hex: "2A1808"))
                        .frame(width: 10, height: 5)
                    // Body
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "7A5830"), Color(hex: "5A3E1A"), Color(hex: "3A2510")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 8, height: 18)
                }
                .position(x: w * xFrac, y: h * 0.66)
            }

            // Rope
            RopeSagShape()
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "8B7355"), Color(hex: "6B5A3A")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2.5
                )
                .frame(width: w * 0.20, height: 14)
                .position(x: w * 0.87, y: h * 0.67)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Stage 4: Cozy Camp

    private var cozyCampDecorations: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let iglooCX = w * 0.78
            let iglooBottom = h * 0.84
            let fireCX = w * 0.32

            // ═══════ IGLOO — one big dome ═══════
            let iglooW = w * 0.52
            let iglooH = iglooW * 0.54
            let iglooDomeY = iglooBottom - iglooH * 0.5

            // Ground shadow
            Ellipse()
                .fill(Color(hex: "0A1520").opacity(0.35))
                .frame(width: iglooW * 1.05, height: 6)
                .position(x: iglooCX, y: iglooBottom + 2)

            // Dome shadow
            IglooShape()
                .fill(Color(hex: "0A1520").opacity(0.25))
                .frame(width: iglooW, height: iglooH)
                .position(x: iglooCX + 2, y: iglooDomeY + 2.5)

            // Dome fill
            IglooShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "FFFFFF"),
                            Color(hex: "F0F6FF"),
                            Color(hex: "D8E8F6"),
                            Color(hex: "B4D0E8"),
                            Color(hex: "90B4D0"),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: iglooW, height: iglooH)
                .position(x: iglooCX, y: iglooDomeY)

            // Brick pattern
            IglooBlockLines()
                .stroke(Color(hex: "7AA0C0").opacity(0.5), lineWidth: 0.8)
                .frame(width: iglooW * 0.90, height: iglooH * 0.85)
                .position(x: iglooCX, y: iglooDomeY + iglooH * 0.07)

            // Dome outline
            IglooShape()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color(hex: "7AA0C0").opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
                .frame(width: iglooW, height: iglooH)
                .position(x: iglooCX, y: iglooDomeY)

            // Entrance arch (dark opening at base of dome)
            ShelterEntranceShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "060E18"), Color(hex: "142232")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: iglooW * 0.22, height: iglooH * 0.35)
                .position(x: iglooCX, y: iglooBottom - iglooH * 0.02)

            // Warm glow from entrance
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "FFB060").opacity(0.5),
                            Color(hex: "FF8030").opacity(0.15),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: iglooW * 0.15
                    )
                )
                .frame(width: iglooW * 0.3, height: iglooH * 0.22)
                .position(x: iglooCX, y: iglooBottom + 2)

            // ═══════ CAMPFIRE ═══════
            // Wide warm glow on snow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "FF6B00").opacity(0.30),
                            Color(hex: "FF4500").opacity(0.12),
                            Color(hex: "FF2000").opacity(0.04),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 60)
                .position(x: fireCX, y: h * 0.82)

            // Stone ring (8 stones)
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * (.pi / 4.0)
                let rx: CGFloat = 20
                let ry: CGFloat = 11
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "707070"), Color(hex: "484848"), Color(hex: "2A2A2A")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 11, height: 9)
                    .position(
                        x: fireCX + cos(angle) * rx,
                        y: h * 0.82 + sin(angle) * ry
                    )
            }

            // Crossed logs
            CampfireLogShape()
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "6B3A10"), Color(hex: "3A1E08")],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 5.5
                )
                .frame(width: 38, height: 22)
                .position(x: fireCX, y: h * 0.81)
            // Log bark detail
            CampfireLogShape()
                .stroke(Color(hex: "8B5A20").opacity(0.35), lineWidth: 1.2)
                .frame(width: 38, height: 22)
                .position(x: fireCX, y: h * 0.81)

            // Outer flame
            StageFlameShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "FFF8E0"),
                            Color(hex: "FFE040"),
                            Color(hex: "FF8C00"),
                            Color(hex: "FF4500"),
                            Color(hex: "CC2200"),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 30, height: 42)
                .position(x: fireCX, y: h * 0.78)

            // Middle flame
            StageFlameShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(hex: "FFEE60"),
                            Color(hex: "FFB020"),
                            Color(hex: "FF6A00"),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 18, height: 28)
                .position(x: fireCX, y: h * 0.786)

            // Core flame
            StageFlameShape()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(hex: "FFF8C0")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 9, height: 16)
                .position(x: fireCX, y: h * 0.792)

            // Embers
            ForEach(Array(campfireEmbers.enumerated()), id: \.offset) { _, e in
                Circle()
                    .fill(Color(hex: e.hex))
                    .frame(width: e.sz, height: e.sz)
                    .position(x: fireCX + e.dx, y: h * 0.78 + e.dy)
            }
        }
        .allowsHitTesting(false)
    }

    nonisolated private static let campfireEmberData: [(dx: CGFloat, dy: CGFloat, sz: CGFloat, hex: String)] = [
        (-8, -30, 2.5, "FFB020"), (5, -36, 2, "FF8800"), (-3, -42, 3, "FFCC40"),
        (9, -28, 2, "FF6A00"), (-6, -48, 2.5, "FFB020"), (2, -22, 2, "FF8800"),
    ]
    private var campfireEmbers: [(dx: CGFloat, dy: CGFloat, sz: CGFloat, hex: String)] {
        Self.campfireEmberData
    }

    // MARK: - Stage 5: Summit Lodge

    private var summitLodgeDecorations: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let lodgeCX = w * 0.78

            // ═══════ LODGE BUILDING ═══════
            // Ground shadow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "0A1520").opacity(0.35), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: w * 0.26
                    )
                )
                .frame(width: w * 0.52, height: h * 0.025)
                .position(x: lodgeCX, y: h * 0.84)

            // Wall shadow
            LodgeWallsShape()
                .fill(Color(hex: "08101A").opacity(0.4))
                .frame(width: w * 0.46, height: h * 0.22)
                .position(x: lodgeCX + 2, y: h * 0.74 + 3)

            // Wall body
            LodgeWallsShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "6B4A28"), Color(hex: "5A3A1A"), Color(hex: "3A2510"), Color(hex: "2A1808")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: w * 0.46, height: h * 0.22)
                .position(x: lodgeCX, y: h * 0.74)

            // Log cabin lines (thicker, more visible)
            ForEach(0..<7, id: \.self) { i in
                let yOff = CGFloat(i) * (h * 0.028)
                Rectangle()
                    .fill(Color(hex: "8B6B3A").opacity(0.35))
                    .frame(width: w * 0.42, height: 1.2)
                    .position(x: lodgeCX, y: h * 0.658 + yOff)
            }

            // Wall outline
            LodgeWallsShape()
                .stroke(Color(hex: "8B6B3A"), lineWidth: 1.5)
                .frame(width: w * 0.46, height: h * 0.22)
                .position(x: lodgeCX, y: h * 0.74)

            // ── Roof ──
            // Roof shadow
            LodgeRoofShape()
                .fill(Color(hex: "08101A").opacity(0.3))
                .frame(width: w * 0.52, height: h * 0.16)
                .position(x: lodgeCX + 2, y: h * 0.58 + 3)
            // Roof body
            LodgeRoofShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "5A3818"), Color(hex: "4A3018"), Color(hex: "2A1808")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: w * 0.52, height: h * 0.16)
                .position(x: lodgeCX, y: h * 0.58)
            // Roof outline
            LodgeRoofShape()
                .stroke(Color(hex: "8B6540"), lineWidth: 1.5)
                .frame(width: w * 0.52, height: h * 0.16)
                .position(x: lodgeCX, y: h * 0.58)

            // Snow on roof (larger, with frost)
            RoofSnowShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "F4F9FF"), Color(hex: "E0ECF8"), Color(hex: "C8DCF0")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: w * 0.26, height: h * 0.04)
                .position(x: w * 0.64, y: h * 0.565)
            RoofSnowShape()
                .stroke(Color.white.opacity(0.4), lineWidth: 0.7)
                .frame(width: w * 0.26, height: h * 0.04)
                .position(x: w * 0.64, y: h * 0.565)

            // ── Windows (larger: 18×18) ──
            ForEach([0.65, 0.76, 0.87] as [CGFloat], id: \.self) { wx in
                let isLit = time == .night || time == .dusk
                ZStack {
                    // Frame
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color(hex: "1A1008"))
                    // Glass
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isLit ? Color(hex: "FFD060") : Color(hex: "6898B8"))
                        .padding(2)
                    // Mullion cross
                    Rectangle()
                        .fill(Color(hex: "1A1008"))
                        .frame(width: 1.5, height: 18)
                    Rectangle()
                        .fill(Color(hex: "1A1008"))
                        .frame(width: 18, height: 1.5)
                    // Glass shine
                    if !isLit {
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 5, height: 12)
                            .offset(x: -3)
                    }
                }
                .frame(width: 18, height: 18)
                .position(x: w * wx, y: h * 0.72)

                // Window light spill
                if isLit {
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "FFD060").opacity(0.4), .clear],
                                center: .center,
                                startRadius: 2,
                                endRadius: 14
                            )
                        )
                        .frame(width: 24, height: 10)
                        .position(x: w * wx, y: h * 0.735)
                }
            }

            // ── Door ──
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "4A2810"), Color(hex: "3A1D08"), Color(hex: "2A1406")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 16, height: h * 0.12)
                .position(x: w * 0.96, y: h * 0.78)
            // Door handle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "D4B870"), Color(hex: "A08040")],
                        center: .init(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: 3
                    )
                )
                .frame(width: 4, height: 4)
                .position(x: w * 0.965, y: h * 0.78)

            // ── Chimney ──
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "7A5830"), Color(hex: "5A3E1A"), Color(hex: "3A2510")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 16, height: h * 0.14)
                .position(x: w * 0.90, y: h * 0.46)
            // Chimney cap
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(hex: "5A3E1A"))
                .frame(width: 22, height: 5)
                .position(x: w * 0.90, y: h * 0.39)

            // ── Smoke puffs ──
            ForEach(Array(smokePuffs.enumerated()), id: \.offset) { _, puff in
                Circle()
                    .fill(Color.white.opacity(puff.alpha))
                    .frame(width: puff.size, height: puff.size)
                    .position(x: w * puff.x, y: h * puff.y)
            }

            // ── Deck / porch ──
            RoundedRectangle(cornerRadius: 1.5)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "8B6B3A"), Color(hex: "6B4A28"), Color(hex: "4A3018")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: w * 0.50, height: h * 0.04)
                .position(x: lodgeCX, y: h * 0.83)

            // Porch railing
            ForEach([0.56, 0.66, 0.76, 0.86, 0.96] as [CGFloat], id: \.self) { xFrac in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color(hex: "5A3E1A"))
                    .frame(width: 3.5, height: h * 0.045)
                    .position(x: w * xFrac, y: h * 0.80)
            }
            // Railing bar
            Rectangle()
                .fill(Color(hex: "6B4A28"))
                .frame(width: w * 0.42, height: 2)
                .position(x: lodgeCX, y: h * 0.79)

            // ── Icicles hanging from roof edge ──
            ForEach(Array(iciclePositions.enumerated()), id: \.offset) { _, ic in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "D4E8F8"), Color(hex: "A8CCE4").opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: ic.w, height: ic.h)
                    .position(x: w * ic.x, y: h * 0.645 + ic.h / 2)
            }
        }
        .allowsHitTesting(false)
    }

    private var smokePuffs: [(x: CGFloat, y: CGFloat, size: CGFloat, alpha: CGFloat)] {
        let isLit = time == .night || time == .dusk
        let baseAlpha: CGFloat = isLit ? 0.55 : 0.30
        return [
            (0.90, 0.36, 12, baseAlpha),
            (0.89, 0.30, 16, baseAlpha * 0.8),
            (0.91, 0.24, 20, baseAlpha * 0.6),
            (0.88, 0.18, 18, baseAlpha * 0.4),
            (0.90, 0.12, 14, baseAlpha * 0.25),
        ]
    }

    nonisolated private static let icicleData: [(x: CGFloat, w: CGFloat, h: CGFloat)] = [
        (0.58, 2, 10), (0.62, 1.5, 14), (0.67, 2, 8), (0.72, 1.5, 12),
        (0.78, 2, 16), (0.83, 1.5, 10), (0.88, 2, 13), (0.93, 1.5, 9),
    ]
    private var iciclePositions: [(x: CGFloat, w: CGFloat, h: CGFloat)] {
        Self.icicleData
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

// MARK: - Cubic Bezier Shape Definitions

/// Soft mound shape — organic drift with flat bottom, cubic bezier curves.
private struct SnowDriftShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: 0, y: h))
            // Left rise — sweeps up with a smooth belly
            p.addCurve(
                to: CGPoint(x: w * 0.5, y: 0),
                control1: CGPoint(x: w * 0.04, y: h * 0.12),
                control2: CGPoint(x: w * 0.22, y: -h * 0.02)
            )
            // Right fall — mirrors with slight asymmetry for organic feel
            p.addCurve(
                to: CGPoint(x: w, y: h),
                control1: CGPoint(x: w * 0.78, y: -h * 0.02),
                control2: CGPoint(x: w * 0.96, y: h * 0.12)
            )
            p.closeSubpath()
        }
    }
}

/// Wavy ice crack line — jagged organic fissure with cubic curves.
private struct IceCrackShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: 0, y: h * 0.5))
            p.addCurve(
                to: CGPoint(x: w * 0.3, y: h * 0.25),
                control1: CGPoint(x: w * 0.06, y: h * 0.78),
                control2: CGPoint(x: w * 0.2, y: h * 0.10)
            )
            p.addCurve(
                to: CGPoint(x: w * 0.58, y: h * 0.62),
                control1: CGPoint(x: w * 0.38, y: h * 0.38),
                control2: CGPoint(x: w * 0.48, y: h * 0.08)
            )
            p.addCurve(
                to: CGPoint(x: w, y: h * 0.38),
                control1: CGPoint(x: w * 0.68, y: h * 0.98),
                control2: CGPoint(x: w * 0.88, y: h * 0.25)
            )
        }
    }
}

/// Snow wall — curved barrier with smooth domed top, cubic beziers.
private struct SnowWallShape: Shape {
    enum Side { case left, right }
    let side: Side

    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            if side == .left {
                p.move(to: CGPoint(x: 0, y: h))
                p.addLine(to: CGPoint(x: 0, y: h * 0.4))
                // Smooth dome crest with two control points
                p.addCurve(
                    to: CGPoint(x: w * 0.5, y: h * 0.08),
                    control1: CGPoint(x: w * 0.02, y: h * 0.06),
                    control2: CGPoint(x: w * 0.25, y: h * 0.0)
                )
                p.addCurve(
                    to: CGPoint(x: w, y: h * 0.35),
                    control1: CGPoint(x: w * 0.75, y: h * 0.0),
                    control2: CGPoint(x: w * 0.96, y: h * 0.06)
                )
                p.addLine(to: CGPoint(x: w, y: h))
                p.closeSubpath()
            } else {
                p.move(to: CGPoint(x: 0, y: h))
                p.addLine(to: CGPoint(x: 0, y: h * 0.35))
                p.addCurve(
                    to: CGPoint(x: w * 0.5, y: h * 0.04),
                    control1: CGPoint(x: w * 0.02, y: h * 0.04),
                    control2: CGPoint(x: w * 0.25, y: -h * 0.02)
                )
                p.addCurve(
                    to: CGPoint(x: w, y: h * 0.3),
                    control1: CGPoint(x: w * 0.75, y: -h * 0.02),
                    control2: CGPoint(x: w * 0.96, y: h * 0.04)
                )
                p.addLine(to: CGPoint(x: w, y: h))
                p.closeSubpath()
            }
        }
    }
}

/// Dark semicircular shelter entrance — smooth arch via cubic beziers.
private struct ShelterEntranceShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: 0, y: h))
            p.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.02),
                control1: CGPoint(x: 0, y: h * 0.15),
                control2: CGPoint(x: w * 0.18, y: h * 0.02)
            )
            p.addCurve(
                to: CGPoint(x: w, y: h),
                control1: CGPoint(x: w * 0.82, y: h * 0.02),
                control2: CGPoint(x: w, y: h * 0.15)
            )
            p.closeSubpath()
        }
    }
}

/// X-shaped cross brace with slightly bowed members.
private struct CrossBraceShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            // Brace 1: slight bow
            p.move(to: CGPoint(x: 0, y: 0))
            p.addCurve(
                to: CGPoint(x: w, y: h),
                control1: CGPoint(x: w * 0.35, y: h * 0.42),
                control2: CGPoint(x: w * 0.65, y: h * 0.58)
            )
            // Brace 2: slight bow opposite
            p.move(to: CGPoint(x: 0, y: h))
            p.addCurve(
                to: CGPoint(x: w, y: 0),
                control1: CGPoint(x: w * 0.35, y: h * 0.58),
                control2: CGPoint(x: w * 0.65, y: h * 0.42)
            )
        }
    }
}

/// Curved fishing rod — smooth S-curve with cubic beziers.
private struct FishingRodShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: w * 0.8, y: h))
            // Lower section — gentle curve toward mid
            p.addCurve(
                to: CGPoint(x: w * 0.3, y: h * 0.3),
                control1: CGPoint(x: w * 0.72, y: h * 0.7),
                control2: CGPoint(x: w * 0.38, y: h * 0.48)
            )
            // Upper section — whippy tip
            p.addCurve(
                to: CGPoint(x: 0, y: 0),
                control1: CGPoint(x: w * 0.22, y: h * 0.14),
                control2: CGPoint(x: w * 0.06, y: h * 0.02)
            )
        }
    }
}

/// Drooping fishing line — natural catenary sag.
private struct FishingLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: w * 0.3, y: 0))
            p.addCurve(
                to: CGPoint(x: w * 0.6, y: h),
                control1: CGPoint(x: -w * 0.12, y: h * 0.22),
                control2: CGPoint(x: w * 0.15, y: h * 0.78)
            )
        }
    }
}

/// Sagging rope between two posts — symmetric catenary.
private struct RopeSagShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: 0, y: 0))
            p.addCurve(
                to: CGPoint(x: w, y: 0),
                control1: CGPoint(x: w * 0.22, y: h * 0.88),
                control2: CGPoint(x: w * 0.78, y: h * 0.88)
            )
        }
    }
}

/// Igloo dome — proper wide hemisphere with flat base.
private struct IglooShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            // Flat base from left to right
            p.move(to: CGPoint(x: 0, y: h))
            // Single smooth semicircular arc across the top
            // Use two symmetric cubic curves to form a clean half-circle
            p.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.0),
                control1: CGPoint(x: 0, y: h * 0.0),
                control2: CGPoint(x: w * 0.16, y: h * 0.0)
            )
            p.addCurve(
                to: CGPoint(x: w, y: h),
                control1: CGPoint(x: w * 0.84, y: h * 0.0),
                control2: CGPoint(x: w, y: h * 0.0)
            )
            p.closeSubpath()
        }
    }
}

/// Staggered ice-block brick pattern that follows the igloo dome.
private struct IglooBlockLines: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            let rows = 6

            // For each row, compute the dome width at that height, draw horizontal line + vertical joints
            for row in 1...rows {
                let frac = CGFloat(row) / CGFloat(rows + 1)
                let y = h * frac

                // Approximate dome x-extent at height y using circle math:
                // For a semicircle of radius R centered at (R, R), x = R ± sqrt(R² - (R-y)²)
                let R = w * 0.5
                let Rh = h
                let normalY = (1.0 - frac) * Rh  // distance from bottom
                let ratio = normalY / Rh
                // Width fraction at this height (circle): sqrt(1 - (1-t)²) where t = frac
                let halfW = R * sqrt(max(0, 1.0 - ratio * ratio))
                let leftX = w * 0.5 - halfW
                let rightX = w * 0.5 + halfW

                // Horizontal line
                p.move(to: CGPoint(x: leftX, y: y))
                p.addLine(to: CGPoint(x: rightX, y: y))

                // Vertical joints (staggered: even rows offset by half a block)
                let blockCount = max(2, Int((rightX - leftX) / 14))
                let blockW = (rightX - leftX) / CGFloat(blockCount)
                let offset: CGFloat = (row % 2 == 0) ? blockW * 0.5 : 0

                let prevFrac = CGFloat(row - 1) / CGFloat(rows + 1)
                let prevY = h * prevFrac

                for j in 1..<blockCount {
                    let jx = leftX + CGFloat(j) * blockW + offset
                    if jx > leftX + 2 && jx < rightX - 2 {
                        p.move(to: CGPoint(x: jx, y: prevY))
                        p.addLine(to: CGPoint(x: jx, y: y))
                    }
                }
            }
        }
    }
}

/// Igloo entrance tunnel — protruding rounded tunnel opening.
private struct IglooEntranceTunnel: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            // Tunnel is wider at base, arched at top
            p.move(to: CGPoint(x: 0, y: h))
            p.addLine(to: CGPoint(x: 0, y: h * 0.35))
            // Smooth arch over the tunnel
            p.addCurve(
                to: CGPoint(x: w, y: h * 0.35),
                control1: CGPoint(x: w * 0.05, y: -h * 0.15),
                control2: CGPoint(x: w * 0.95, y: -h * 0.15)
            )
            p.addLine(to: CGPoint(x: w, y: h))
            p.closeSubpath()
        }
    }
}

/// Flame teardrop — organic fire shape with cubic beziers.
private struct StageFlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: w * 0.5, y: 0))
            // Right side — bulges out then tapers to base
            p.addCurve(
                to: CGPoint(x: w * 0.98, y: h * 0.58),
                control1: CGPoint(x: w * 0.54, y: h * 0.08),
                control2: CGPoint(x: w * 1.12, y: h * 0.32)
            )
            // Right bottom curve to center base
            p.addCurve(
                to: CGPoint(x: w * 0.5, y: h),
                control1: CGPoint(x: w * 0.88, y: h * 0.78),
                control2: CGPoint(x: w * 0.62, y: h * 0.95)
            )
            // Left bottom curve from center base
            p.addCurve(
                to: CGPoint(x: w * 0.02, y: h * 0.58),
                control1: CGPoint(x: w * 0.38, y: h * 0.95),
                control2: CGPoint(x: w * 0.12, y: h * 0.78)
            )
            // Left side — back to tip
            p.addCurve(
                to: CGPoint(x: w * 0.5, y: 0),
                control1: CGPoint(x: -w * 0.12, y: h * 0.32),
                control2: CGPoint(x: w * 0.46, y: h * 0.08)
            )
        }
    }
}

/// Crossed campfire logs — slight organic bow.
private struct CampfireLogShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: 0, y: h))
            p.addCurve(
                to: CGPoint(x: w, y: h * 0.2),
                control1: CGPoint(x: w * 0.3, y: h * 0.75),
                control2: CGPoint(x: w * 0.7, y: h * 0.35)
            )
            p.move(to: CGPoint(x: w, y: h))
            p.addCurve(
                to: CGPoint(x: 0, y: h * 0.2),
                control1: CGPoint(x: w * 0.7, y: h * 0.75),
                control2: CGPoint(x: w * 0.3, y: h * 0.35)
            )
        }
    }
}

/// Lodge walls — slightly bowed organic rectangle.
private struct LodgeWallsShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: 0, y: 0))
            // Top edge with subtle sag
            p.addCurve(
                to: CGPoint(x: w, y: 0),
                control1: CGPoint(x: w * 0.33, y: -h * 0.01),
                control2: CGPoint(x: w * 0.66, y: -h * 0.01)
            )
            p.addLine(to: CGPoint(x: w, y: h))
            // Bottom edge with subtle sag
            p.addCurve(
                to: CGPoint(x: 0, y: h),
                control1: CGPoint(x: w * 0.66, y: h * 1.01),
                control2: CGPoint(x: w * 0.33, y: h * 1.01)
            )
            p.closeSubpath()
        }
    }
}

/// A-frame roof — peaked with subtle curve on rafters.
private struct LodgeRoofShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: 0, y: h))
            // Left rafter — slight outward bow
            p.addCurve(
                to: CGPoint(x: w * 0.25, y: 0),
                control1: CGPoint(x: w * 0.04, y: h * 0.65),
                control2: CGPoint(x: w * 0.15, y: h * 0.08)
            )
            // Ridge line
            p.addLine(to: CGPoint(x: w * 0.95, y: 0))
            // Right rafter
            p.addCurve(
                to: CGPoint(x: w, y: h),
                control1: CGPoint(x: w * 0.97, y: h * 0.08),
                control2: CGPoint(x: w * 0.99, y: h * 0.65)
            )
            p.closeSubpath()
        }
    }
}

/// Snow cap on roof edge — organic draping snow.
private struct RoofSnowShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: 0, y: h))
            // Rise to peak
            p.addCurve(
                to: CGPoint(x: w * 0.45, y: h * 0.02),
                control1: CGPoint(x: w * 0.04, y: h * 0.08),
                control2: CGPoint(x: w * 0.2, y: -h * 0.02)
            )
            // Drape down right side with icicle-like dips
            p.addCurve(
                to: CGPoint(x: w * 0.75, y: h * 0.3),
                control1: CGPoint(x: w * 0.58, y: -h * 0.02),
                control2: CGPoint(x: w * 0.68, y: h * 0.1)
            )
            p.addCurve(
                to: CGPoint(x: w, y: h * 0.55),
                control1: CGPoint(x: w * 0.82, y: h * 0.42),
                control2: CGPoint(x: w * 0.95, y: h * 0.35)
            )
            p.addLine(to: CGPoint(x: w, y: h))
            p.closeSubpath()
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
