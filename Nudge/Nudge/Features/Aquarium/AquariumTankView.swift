//
//  AquariumTankView.swift
//  Nudge
//
//  Inline interactive fish tank for the You page hero.
//  Vector-rendered fish (AnimatedFishView) swim with sin/cos physics
//  and animated tail wag. TimelineView drives smooth 30fps updates.
//
//  Environment: light rays, swaying seaweed, bubbles, caustics, sand.
//  Interactions: tap water → ripple + scatter, tap fish → info,
//  swipe down → feed.
//
//  Self-contained — manages its own animation state.
//  Max 12 fish visible for performance.
//

import SwiftUI

// MARK: - Tank Fish Model

private struct TankFish: Identifiable {
    let id: UUID
    let catchData: FishCatch
    var x: CGFloat           // 0…1 normalized position
    var y: CGFloat           // 0…1 normalized position
    var speed: Double        // swim cycle seconds
    var amplitude: CGFloat   // vertical bob px
    var flipped: Bool
    var phaseOffset: Double
    var depth: CGFloat       // 0 = front, 1 = back (parallax + opacity)
    var scatterOffset: CGSize = .zero
    var isScattering: Bool = false
}

// MARK: - Ripple Model

private struct Ripple: Identifiable {
    let id = UUID()
    let point: CGPoint
    var scale: CGFloat = 0
    var opacity: Double = 0.6
}

// MARK: - Food Particle Model

private struct FoodParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vy: CGFloat = 0
    var opacity: Double = 1.0
    var consumed: Bool = false
}

// MARK: - Seaweed Model

private struct SeaweedPatch: Identifiable {
    let id = UUID()
    let x: CGFloat             // normalized 0…1
    let height: CGFloat        // normalized 0.12…0.30
    let bladeCount: Int        // 2–4
    let color: Color
    let phaseOffset: Double
}

// MARK: - Bubble Particle

private struct BubbleParticle {
    let x: CGFloat
    let radius: CGFloat
    let speed: Double
    let startOffset: Double
    let wobble: Double
}

// MARK: - Aquarium Tank View

struct AquariumTankView: View {
    let catches: [FishCatch]
    let level: Int
    let streak: Int
    var height: CGFloat = 220
    var onFishTap: ((FishCatch) -> Void)? = nil

    @State private var tankFish: [TankFish] = []
    @State private var ripples: [Ripple] = []
    @State private var isScattered = false
    @State private var bubbles: [BubbleParticle] = []
    @State private var foodParticles: [FoodParticle] = []
    @State private var feedsAvailable: Int = 0
    @State private var tankSize: CGSize = .init(width: 350, height: 220)
    @State private var seaweeds: [SeaweedPatch] = []
    @State private var rewardService = RewardService.shared
    @State private var showDecorationShop = false
    @State private var feedBonusText: String? = nil
    @State private var feedBonusOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext

    /// This week's catches, capped at 12 for rendering.
    private var weeklyCatches: [FishCatch] {
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        return Array(catches.filter { $0.weekNumber == currentWeek }.prefix(12))
    }

    var body: some View {
        GeometryReader { geo in
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let size = tankSize

                ZStack {
                    // 1. Deep water gradient
                    waterBackground

                    // 2. Light rays from surface
                    if !reduceMotion {
                        lightRays(size: size, time: time)
                    }

                    // 3. Sand/gravel bottom
                    sandBottom(width: size.width, height: size.height)

                    // 4. Seaweed (behind fish)
                    seaweedLayer(size: size, time: time)

                    // 4.5. Tank decorations (on the sand)
                    decorationLayer(size: size)

                    // 5. Bubbles
                    if !reduceMotion {
                        bubblesCanvas(size: size, time: time)
                    }

                    // 6. Fish — back layer then front layer
                    if weeklyCatches.isEmpty {
                        emptyState
                    } else {
                        backFishLayer(size: size, time: time)
                        frontFishLayer(size: size, time: time)
                    }

                    // 7. Ripples
                    ForEach(ripples) { ripple in
                        Circle()
                            .stroke(Color.white.opacity(ripple.opacity), lineWidth: 1.5)
                            .frame(width: 40 * ripple.scale, height: 40 * ripple.scale)
                            .position(ripple.point)
                    }

                    // 8. Food particles
                    foodParticlesLayer

                    // 9. Caustic light shimmer
                    if !reduceMotion {
                        causticCanvas(size: size, time: time)
                    }

                    // 10. Glass border + surface shine
                    glassBorder
                    surfaceShine(width: size.width)

                    // 11. Feed indicator + decor shop button
                    tankOverlayButtons

                    // 12. Happiness indicator (top-left)
                    happinessIndicator

                    // 13. Feed bonus toast
                    if feedBonusText != nil {
                        feedBonusToast
                    }
                }
        }
        .onAppear { tankSize = geo.size }
        .onChange(of: geo.size) { _, newSize in tankSize = newSize }
        } // end GeometryReader
        .drawingGroup()  // Flatten all fish, bubbles, caustics into one GPU texture
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 30 && feedsAvailable > 0 {
                        dropFood(at: value.location)
                    }
                }
        )
        .onTapGesture { location in
            handleWaterTap(at: location)
        }
        .sheet(isPresented: $showDecorationShop) {
            DecorationShopView()
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            spawnFish()
            spawnBubbles()
            spawnSeaweed()
            feedsAvailable = rewardService.tasksCompletedToday
        }
        .onChange(of: weeklyCatches.count) { _, _ in
            spawnFish()
        }
        .nudgeAccessibility(
            label: String(localized: "Aquarium tank with \(weeklyCatches.count) fish"),
            hint: String(localized: "Tap a fish to see details, swipe down to feed")
        )
    }

    // MARK: - Water Background

    private var waterBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "000D1A"),
                        Color(hex: "001B3A"),
                        Color(hex: "002855"),
                        Color(hex: "003366"),
                        Color(hex: "001B2E")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    // MARK: - Light Rays

    private func lightRays(size: CGSize, time: Double) -> some View {
        Canvas { context, canvasSize in
            let rayCount = 4
            for i in 0..<rayCount {
                let t = Double(i) / Double(rayCount)
                let sway = sin(time * 0.3 + t * .pi * 2) * 0.05
                let baseX = 0.15 + t * 0.7 + sway
                let topX = canvasSize.width * baseX
                let spreadBottom = canvasSize.width * 0.08
                let rayHeight = canvasSize.height * 0.7
                let opacity = 0.03 + sin(time * 0.5 + t * 3.0) * 0.015

                var path = Path()
                path.move(to: CGPoint(x: topX - 3, y: 0))
                path.addLine(to: CGPoint(x: topX + 3, y: 0))
                path.addLine(to: CGPoint(x: topX + spreadBottom, y: rayHeight))
                path.addLine(to: CGPoint(x: topX - spreadBottom, y: rayHeight))
                path.closeSubpath()

                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.white.opacity(opacity),
                            Color(hex: "4FC3F7").opacity(opacity * 0.5),
                            Color.clear
                        ]),
                        startPoint: CGPoint(x: topX, y: 0),
                        endPoint: CGPoint(x: topX, y: rayHeight)
                    )
                )
            }
        }
        .allowsHitTesting(false)
        .blendMode(.screen)
    }

    // MARK: - Sand Bottom

    private func sandBottom(width: CGFloat, height: CGFloat) -> some View {
        VStack {
            Spacer()
            ZStack(alignment: .bottom) {
                // Sand gradient
                LinearGradient(
                    colors: [
                        Color(hex: "3E2723").opacity(0.0),
                        Color(hex: "3E2723").opacity(0.25),
                        Color(hex: "5D4037").opacity(0.45),
                        Color(hex: "6D4C41").opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height * 0.20)

                // Pebbles — small random dots in the sand
                Canvas { context, canvasSize in
                    let pebbleCount = 10
                    for i in 0..<pebbleCount {
                        let seed = Double(i) * 7.31
                        let px = canvasSize.width * CGFloat((seed * 0.137).truncatingRemainder(dividingBy: 1.0))
                        let py = canvasSize.height * CGFloat(0.5 + (seed * 0.243).truncatingRemainder(dividingBy: 0.45))
                        let r = CGFloat(1.5 + (seed * 0.371).truncatingRemainder(dividingBy: 2.0))
                        var circle = Path()
                        circle.addEllipse(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
                        context.fill(circle, with: .color(Color(hex: "8D6E63").opacity(0.15)))
                    }
                }
                .frame(height: height * 0.20)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Seaweed Layer

    private func seaweedLayer(size: CGSize, time: Double) -> some View {
        Canvas { context, canvasSize in
            for weed in seaweeds {
                let baseX = weed.x * canvasSize.width
                let weedHeight = weed.height * canvasSize.height
                let bottomY = canvasSize.height

                for blade in 0..<weed.bladeCount {
                    let bladeOffset = CGFloat(blade - weed.bladeCount / 2) * 6
                    let sway = reduceMotion ? 0.0 : sin(time * 0.8 + weed.phaseOffset + Double(blade) * 0.5) * 8.0
                    let sway2 = reduceMotion ? 0.0 : sin(time * 1.2 + weed.phaseOffset + Double(blade) * 0.7) * 4.0

                    var path = Path()
                    path.move(to: CGPoint(x: baseX + bladeOffset, y: bottomY))
                    path.addCurve(
                        to: CGPoint(x: baseX + bladeOffset + CGFloat(sway), y: bottomY - weedHeight),
                        control1: CGPoint(
                            x: baseX + bladeOffset + CGFloat(sway2) * 0.3,
                            y: bottomY - weedHeight * 0.35
                        ),
                        control2: CGPoint(
                            x: baseX + bladeOffset + CGFloat(sway) * 0.7,
                            y: bottomY - weedHeight * 0.65
                        )
                    )

                    context.stroke(
                        path,
                        with: .color(weed.color.opacity(0.5)),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Fish Layers (Depth-Sorted)

    /// Back-layer fish (depth 0.5…1.0) — behind, smaller, dimmer.
    private func backFishLayer(size: CGSize, time: Double) -> some View {
        ForEach(Array(tankFish.filter { $0.depth >= 0.5 }), id: \.id) { fish in
            fishBody(fish: fish, size: size, time: time)
        }
    }

    /// Front-layer fish (depth 0.0..<0.5) — in front, full size.
    private func frontFishLayer(size: CGSize, time: Double) -> some View {
        ForEach(Array(tankFish.filter { $0.depth < 0.5 }), id: \.id) { fish in
            fishBody(fish: fish, size: size, time: time)
        }
    }

    @ViewBuilder
    private func fishBody(fish: TankFish, size: CGSize, time: Double) -> some View {
        let pos = swimPosition(for: fish, in: size, time: time)
        let tailWag = tailWagPhase(for: fish, time: time)
        let depthScale = 1.0 - fish.depth * 0.25
        let depthOpacity = 1.0 - Double(fish.depth) * 0.3

        AnimatedFishView(
            size: fish.catchData.species.displaySize * depthScale,
            color: fish.catchData.species.fishColor,
            accentColor: fish.catchData.species.fishAccentColor,
            tailPhase: tailWag
        )
        .scaleEffect(x: fish.flipped ? -1 : 1, y: 1)
        .opacity(depthOpacity)
        .offset(x: fish.scatterOffset.width, y: fish.scatterOffset.height)
        .position(x: pos.x, y: pos.y)
        .onTapGesture {
            onFishTap?(fish.catchData)
            HapticService.shared.actionButtonTap()
        }
        .allowsHitTesting(true)
    }

    // MARK: - Swim Physics

    private func swimPosition(for fish: TankFish, in size: CGSize, time: Double) -> CGPoint {
        guard !reduceMotion else {
            return CGPoint(x: fish.x * size.width, y: fish.y * size.height)
        }

        let phase = time * .pi * 2
        let xPhase = phase / fish.speed + fish.phaseOffset
        let yPhase = phase / (fish.speed * 0.7) + fish.phaseOffset

        // Horizontal: sin wave drift + slow cruise
        let cruise = CGFloat(time.truncatingRemainder(dividingBy: fish.speed * 12.0) / (fish.speed * 12.0))
        let dx = CGFloat(sin(xPhase)) * (size.width * 0.07)
        let cruiseOffset = cruise * size.width * 0.15 * (fish.flipped ? -1 : 1)

        // Vertical: gentle bob
        let dy = CGFloat(cos(yPhase)) * fish.amplitude

        // Depth parallax — back fish move slower
        let depthDampen = 1.0 - fish.depth * 0.3

        let baseX = fish.x * size.width
        let baseY = fish.y * size.height

        return CGPoint(
            x: baseX + (dx + cruiseOffset) * depthDampen,
            y: baseY + dy * depthDampen
        )
    }

    private func tailWagPhase(for fish: TankFish, time: Double) -> CGFloat {
        guard !reduceMotion else { return 0 }
        // Tail wags faster for smaller/faster fish
        let wagSpeed = 3.0 + (6.0 - fish.speed) * 0.8
        return CGFloat(sin(time * wagSpeed + fish.phaseOffset))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            Text("🐧")
                .font(.system(size: 40))
            Text(String(localized: "Complete tasks to earn fish!"))
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Glass Border + Surface Shine

    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        Color.white.opacity(0.04),
                        Color.white.opacity(0.06),
                        Color.white.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private func surfaceShine(width: CGFloat) -> some View {
        VStack {
            // Water surface line — subtle white band at top
            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.white.opacity(0.02),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 4)
            .padding(.horizontal, 1)

            Spacer()
        }
    }

    // MARK: - Caustic Light Canvas

    private func causticCanvas(size: CGSize, time: Double) -> some View {
        Canvas { context, canvasSize in
            let phase = time * 0.3
            let count = 6

            for i in 0..<count {
                let t = Double(i) / Double(count)
                let x = canvasSize.width * (0.1 + CGFloat(t) * 0.8)
                let y = canvasSize.height * (0.08 + CGFloat(sin(phase + t * 4)) * 0.12)
                let w = canvasSize.width * CGFloat(0.06 + sin(phase + t * 3) * 0.025)
                let opacity = 0.025 + sin(phase + t * 2) * 0.012

                var path = Path()
                path.addEllipse(in: CGRect(
                    x: x - w / 2,
                    y: y - w * 0.25,
                    width: w,
                    height: w * 0.5
                ))

                context.fill(path, with: .color(Color.white.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
        .blendMode(.screen)
    }

    // MARK: - Bubbles Canvas

    private func bubblesCanvas(size: CGSize, time: Double) -> some View {
        Canvas { context, canvasSize in
            for bubble in bubbles {
                let speed = bubble.speed
                let t = (time * speed + bubble.startOffset).truncatingRemainder(dividingBy: 1.0)
                let y = canvasSize.height * (1.0 - CGFloat(t))
                let x = bubble.x * canvasSize.width + CGFloat(sin(time * 2 + bubble.wobble)) * 5
                let radius = bubble.radius
                let opacity = 0.12 * (1.0 - t)

                // Bubble body
                var circle = Path()
                circle.addEllipse(in: CGRect(
                    x: x - radius,
                    y: y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.fill(circle, with: .color(Color.white.opacity(opacity)))

                // Tiny highlight on bubble
                var glint = Path()
                let gr = radius * 0.35
                glint.addEllipse(in: CGRect(
                    x: x - gr * 0.5,
                    y: y - radius * 0.6,
                    width: gr,
                    height: gr * 0.7
                ))
                context.fill(glint, with: .color(Color.white.opacity(opacity * 0.6)))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Spawn

    private func spawnFish() {
        tankFish = weeklyCatches.enumerated().map { index, catchItem in
            let cols = min(weeklyCatches.count, 4)
            let row = index / cols
            let col = index % cols

            let baseX = 0.12 + (0.76 / Double(cols)) * (Double(col) + 0.5)
            let baseY = 0.25 + Double(row) * 0.18
            let jitterX = Double.random(in: -0.06...0.06)
            let jitterY = Double.random(in: -0.04...0.04)

            return TankFish(
                id: catchItem.id,
                catchData: catchItem,
                x: CGFloat(baseX + jitterX),
                y: CGFloat(min(max(baseY + jitterY, 0.18), 0.68)),
                speed: catchItem.species.swimSpeed + Double.random(in: -0.5...0.5),
                amplitude: CGFloat.random(in: 5...12),
                flipped: Bool.random(),
                phaseOffset: Double.random(in: 0...(.pi * 2)),
                depth: CGFloat.random(in: 0...1)
            )
        }
    }

    private func spawnBubbles() {
        bubbles = (0..<10).map { _ in
            BubbleParticle(
                x: CGFloat.random(in: 0.08...0.92),
                radius: CGFloat.random(in: 1.5...4.0),
                speed: Double.random(in: 0.025...0.07),
                startOffset: Double.random(in: 0...1),
                wobble: Double.random(in: 0...(.pi * 2))
            )
        }
    }

    private func spawnSeaweed() {
        let colors: [Color] = [
            Color(hex: "2E7D32"),
            Color(hex: "388E3C"),
            Color(hex: "1B5E20"),
            Color(hex: "4CAF50"),
        ]
        seaweeds = (0..<5).map { i in
            SeaweedPatch(
                x: 0.08 + CGFloat(i) * 0.22 + CGFloat.random(in: -0.06...0.06),
                height: CGFloat.random(in: 0.14...0.28),
                bladeCount: Int.random(in: 2...4),
                color: colors[i % colors.count],
                phaseOffset: Double.random(in: 0...(.pi * 2))
            )
        }
    }

    // MARK: - Tap Handling

    private func handleWaterTap(at point: CGPoint) {
        let ripple = Ripple(point: point)
        ripples.append(ripple)

        withAnimation(.easeOut(duration: 0.8)) {
            if let idx = ripples.firstIndex(where: { $0.id == ripple.id }) {
                ripples[idx].scale = 3.0
                ripples[idx].opacity = 0
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.9))
            ripples.removeAll { $0.id == ripple.id }
        }

        scatterFish()
    }

    private func scatterFish() {
        guard !isScattered else { return }
        isScattered = true

        for i in tankFish.indices {
            tankFish[i].isScattering = true
            let scatterX = CGFloat.random(in: -30...30)
            let scatterY = CGFloat.random(in: -20...20)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                tankFish[i].scatterOffset = CGSize(width: scatterX, height: scatterY)
            }
        }

        // Flip some fish on scatter
        for i in tankFish.indices {
            if Bool.random() {
                tankFish[i].flipped.toggle()
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            for i in tankFish.indices {
                tankFish[i].isScattering = false
                withAnimation(.easeInOut(duration: 1.5)) {
                    tankFish[i].scatterOffset = .zero
                }
            }
            try? await Task.sleep(for: .seconds(1.5))
            isScattered = false
        }
    }

    // MARK: - Feed Mechanic

    private var foodParticlesLayer: some View {
        ForEach(foodParticles) { particle in
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "FFB74D"),
                            Color(hex: "FF8A65").opacity(0.6)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 3
                    )
                )
                .frame(width: 6, height: 6)
                .position(x: particle.x, y: particle.y)
                .opacity(particle.opacity)
        }
    }

    private var feedIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 10))
                    Text(String(localized: "\(feedsAvailable) feeds"))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color(hex: "FFB74D"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.5))
                )
                .padding(8)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Overlay Buttons (Feed + Decor Shop)

    private var tankOverlayButtons: some View {
        VStack {
            // Top-right: decoration shop button
            HStack {
                Spacer()
                Button {
                    showDecorationShop = true
                    HapticService.shared.actionButtonTap()
                } label: {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "4FC3F7"))
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.45))
                        )
                }
                .buttonStyle(.plain)
                .padding(8)
                .nudgeAccessibility(
                    label: String(localized: "Decoration shop"),
                    hint: String(localized: "Buy and place tank decorations"),
                    traits: .isButton
                )
            }

            Spacer()

            // Bottom-right: feed indicator
            if feedsAvailable > 0 {
                HStack {
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                        Text(String(localized: "\(feedsAvailable) feeds"))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color(hex: "FFB74D"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.5))
                    )
                    .padding(8)
                }
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Happiness Indicator

    private var happinessIndicator: some View {
        let happiness = rewardService.fishHappiness
        let emoji: String = {
            if happiness >= 1.0 { return "😍" }
            if happiness >= 0.5 { return "😊" }
            if happiness > 0 { return "🐟" }
            return "🐟"
        }()
        let feedStreak = rewardService.feedingStreak

        return VStack {
            HStack {
                // Happiness mood + streak
                VStack(alignment: .leading, spacing: 1) {
                    if happiness > 0 {
                        HStack(spacing: 3) {
                            Text(emoji)
                                .font(.system(size: 12))
                            // Hearts for happiness level
                            HStack(spacing: 1) {
                                ForEach(0..<3, id: \.self) { i in
                                    Image(systemName: Double(i) < happiness * 3.0 ? "heart.fill" : "heart")
                                        .font(.system(size: 7))
                                        .foregroundStyle(
                                            Double(i) < happiness * 3.0
                                                ? Color(hex: "FF6B6B")
                                                : Color.white.opacity(0.25)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.black.opacity(0.45))
                        )
                    }

                    if feedStreak >= 2 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(Color(hex: "FF6B35"))
                            Text(String(localized: "\(feedStreak)d"))
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "FF6B35"))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.black.opacity(0.45))
                        )
                    }
                }
                .padding(6)

                Spacer()
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }

    // MARK: - Feed Bonus Toast

    private var feedBonusToast: some View {
        VStack {
            Spacer()

            if let text = feedBonusText {
                Text(text)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "4FC3F7"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color(hex: "4FC3F7").opacity(0.3), lineWidth: 1)
                            )
                    )
                    .opacity(feedBonusOpacity)
                    .offset(y: -10)
            }

            Spacer()
        }
        .allowsHitTesting(false)
    }

    // MARK: - Decoration Layer

    private func decorationLayer(size: CGSize) -> some View {
        ForEach(TankDecoration.allCases) { deco in
            if rewardService.placedDecorations.contains(deco.rawValue) {
                TankDecorationView(decoration: deco, size: deco.decoSize)
                    .position(
                        x: deco.tankX * size.width,
                        y: size.height - deco.decoSize * 0.5 - size.height * 0.06
                    )
            }
        }
    }

    private func dropFood(at location: CGPoint) {
        guard feedsAvailable > 0 else { return }
        feedsAvailable -= 1
        HapticService.shared.actionButtonTap()

        // Persist the feeding via RewardService
        let bonus = rewardService.recordFeeding(context: modelContext)

        // Show bonus toast if snowflakes earned
        if bonus > 0 {
            feedBonusText = "+\(bonus) ❄️"
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                feedBonusOpacity = 1
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation(.easeOut(duration: 0.5)) {
                    feedBonusOpacity = 0
                }
                try? await Task.sleep(for: .seconds(0.6))
                feedBonusText = nil
            }
            HapticService.shared.swipeDone()
        }

        let newParticles = (0..<3).map { i in
            FoodParticle(
                x: location.x + CGFloat.random(in: -12...12),
                y: location.y + CGFloat(i) * 6
            )
        }
        foodParticles.append(contentsOf: newParticles)

        startFoodPhysics(particleIDs: newParticles.map { $0.id })
    }

    private func startFoodPhysics(particleIDs: [UUID]) {
        Task { @MainActor in
            for _ in 0..<60 {
                try? await Task.sleep(for: .seconds(1.0 / 30.0))
                guard !Task.isCancelled else { break }

                for i in foodParticles.indices {
                    guard particleIDs.contains(foodParticles[i].id),
                          !foodParticles[i].consumed else { continue }

                    foodParticles[i].vy += 0.15
                    foodParticles[i].y += foodParticles[i].vy
                    foodParticles[i].x += CGFloat.random(in: -0.3...0.3)

                    for fi in tankFish.indices {
                        let fishPos = CGPoint(
                            x: tankFish[fi].x * height * 1.5,
                            y: tankFish[fi].y * height
                        )
                        let dist = hypot(
                            foodParticles[i].x - fishPos.x,
                            foodParticles[i].y - fishPos.y
                        )
                        if dist < 25 {
                            foodParticles[i].consumed = true
                            withAnimation(.easeOut(duration: 0.2)) {
                                foodParticles[i].opacity = 0
                            }
                            let burstX = foodParticles[i].x
                            let burstY = foodParticles[i].y
                            addRipple(at: CGPoint(x: burstX, y: burstY))
                            break
                        }
                    }
                }
            }

            withAnimation(.easeOut(duration: 0.3)) {
                for i in foodParticles.indices where particleIDs.contains(foodParticles[i].id) {
                    foodParticles[i].opacity = 0
                }
            }
            try? await Task.sleep(for: .seconds(0.4))
            foodParticles.removeAll { particleIDs.contains($0.id) }
        }
    }

    private func addRipple(at point: CGPoint) {
        let ripple = Ripple(point: point)
        ripples.append(ripple)
        withAnimation(.easeOut(duration: 0.6)) {
            if let idx = ripples.firstIndex(where: { $0.id == ripple.id }) {
                ripples[idx].scale = 2.0
                ripples[idx].opacity = 0
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.7))
            ripples.removeAll { $0.id == ripple.id }
        }
    }
}

// MARK: - Preview

#Preview("Aquarium Tank") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            AquariumTankView(
                catches: [
                    FishCatch(species: .catfish, taskContent: "Reply to emails", taskEmoji: "📧"),
                    FishCatch(species: .tropical, taskContent: "Clean the kitchen", taskEmoji: "🧹"),
                    FishCatch(species: .swordfish, taskContent: "Finish report", taskEmoji: "📄"),
                    FishCatch(species: .catfish, taskContent: "Buy groceries", taskEmoji: "🛒"),
                    FishCatch(species: .tropical, taskContent: "Call mom", taskEmoji: "📞"),
                    FishCatch(species: .whale, taskContent: "Ship feature", taskEmoji: "🚀"),
                ],
                level: 3,
                streak: 5
            )
            .padding(.horizontal)

            AquariumTankView(
                catches: [],
                level: 1,
                streak: 0,
                height: 160
            )
            .padding(.horizontal)
        }
    }
}
