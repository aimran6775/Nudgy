//
//  AquariumTankView.swift
//  Nudge
//
//  Inline interactive fish tank for the You page hero.
//  Vector-rendered fish (FishView) swim with sin/cos physics.
//  Tap a fish → info popover. Tap water → ripple + scatter.
//
//  Self-contained — manages its own animation state.
//  Max 12 fish visible for performance.
//

import SwiftUI

// MARK: - Tank Fish Model

private struct TankFish: Identifiable {
    let id: UUID
    let catchData: FishCatch
    var x: CGFloat
    var y: CGFloat
    var speed: Double
    var amplitude: CGFloat
    var flipped: Bool
    var phaseOffset: Double
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

// MARK: - Aquarium Tank View

struct AquariumTankView: View {
    let catches: [FishCatch]
    let level: Int
    let streak: Int
    var height: CGFloat = 220
    var onFishTap: ((FishCatch) -> Void)? = nil

    @State private var tankFish: [TankFish] = []
    @State private var swimPhase: CGFloat = 0
    @State private var ripples: [Ripple] = []
    @State private var isScattered = false
    @State private var bubbles: [BubbleParticle] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// This week's catches, capped at 12 for rendering.
    private var weeklyCatches: [FishCatch] {
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        return Array(catches.filter { $0.weekNumber == currentWeek }.prefix(12))
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                // 1. Water gradient
                waterBackground

                // 2. Sand/gravel at bottom
                sandBottom(width: size.width, height: size.height)

                // 3. Bubbles
                if !reduceMotion {
                    bubblesOverlay(size: size)
                }

                // 4. Fish
                if weeklyCatches.isEmpty {
                    emptyState
                } else {
                    fishLayer(size: size)
                }

                // 5. Ripples
                ForEach(ripples) { ripple in
                    Circle()
                        .stroke(Color.white.opacity(ripple.opacity), lineWidth: 1.5)
                        .frame(width: 40 * ripple.scale, height: 40 * ripple.scale)
                        .position(ripple.point)
                }

                // 6. Glass border
                glassBorder

                // 7. Caustic light shimmer
                if !reduceMotion {
                    causticOverlay(size: size)
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture { location in
            handleWaterTap(at: location)
        }
        .onAppear {
            spawnFish()
            spawnBubbles()
            guard !reduceMotion else { return }
            startSwimCycle()
        }
        .onChange(of: weeklyCatches.count) { _, _ in
            spawnFish()
        }
        .nudgeAccessibility(
            label: String(localized: "Aquarium tank with \(weeklyCatches.count) fish"),
            hint: String(localized: "Tap a fish to see details, or tap the water for a ripple effect")
        )
    }

    // MARK: - Water Background

    private var waterBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "001B3A"),
                        Color(hex: "002855"),
                        Color(hex: "003366"),
                        Color(hex: "001B3A")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    // MARK: - Sand Bottom

    private func sandBottom(width: CGFloat, height: CGFloat) -> some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [
                    Color(hex: "3E2723").opacity(0.0),
                    Color(hex: "3E2723").opacity(0.3),
                    Color(hex: "5D4037").opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height * 0.18)
        }
    }

    // MARK: - Fish Layer

    private func fishLayer(size: CGSize) -> some View {
        ForEach(Array(tankFish), id: \.id) { fish in
            let pos = animatedPosition(for: fish, in: size)

            FishView(
                size: fish.catchData.species.displaySize,
                color: fish.catchData.species.fishColor,
                accentColor: fish.catchData.species.fishAccentColor
            )
            .scaleEffect(x: fish.flipped ? -1 : 1, y: 1)
            .offset(x: fish.scatterOffset.width, y: fish.scatterOffset.height)
            .position(x: pos.x, y: pos.y)
            .onTapGesture {
                onFishTap?(fish.catchData)
                HapticService.shared.actionButtonTap()
            }
            .allowsHitTesting(true)
        }
    }

    // MARK: - Animated Position

    private func animatedPosition(for fish: TankFish, in size: CGSize) -> CGPoint {
        guard !reduceMotion else {
            return CGPoint(x: fish.x * size.width, y: fish.y * size.height)
        }

        let phase = Double(swimPhase) * .pi * 2
        let xPhase = phase / fish.speed + fish.phaseOffset
        let yPhase = phase / (fish.speed * 0.7) + fish.phaseOffset

        let dx = CGFloat(sin(xPhase)) * (size.width * 0.06)
        let dy = CGFloat(cos(yPhase)) * fish.amplitude

        let baseX = fish.x * size.width
        let baseY = fish.y * size.height

        return CGPoint(x: baseX + dx, y: baseY + dy)
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

    // MARK: - Glass Border

    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.05),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    // MARK: - Caustic Light Overlay

    private func causticOverlay(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let phase = Double(swimPhase) * 0.3
            let count = 5

            for i in 0..<count {
                let t = Double(i) / Double(count)
                let x = canvasSize.width * (0.15 + CGFloat(t) * 0.7)
                let y = canvasSize.height * (0.1 + CGFloat(sin(phase + t * 4)) * 0.15)
                let w = canvasSize.width * CGFloat(0.08 + sin(phase + t * 3) * 0.03)

                var path = Path()
                path.addEllipse(in: CGRect(
                    x: x - w / 2,
                    y: y - w * 0.3,
                    width: w,
                    height: w * 0.6
                ))

                context.fill(
                    path,
                    with: .color(Color.white.opacity(0.03 + sin(phase + t * 2) * 0.015))
                )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Bubbles

    private func bubblesOverlay(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let phase = Double(swimPhase)

            for bubble in bubbles {
                let speed = bubble.speed
                let t = (phase * speed + bubble.startOffset).truncatingRemainder(dividingBy: 1.0)
                let y = canvasSize.height * (1.0 - CGFloat(t))
                let x = bubble.x * canvasSize.width + CGFloat(sin(phase * 2 + bubble.wobble)) * 4
                let radius = bubble.radius
                let opacity = 0.15 * (1.0 - t) // fade as they rise

                var circle = Path()
                circle.addEllipse(in: CGRect(
                    x: x - radius,
                    y: y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))

                context.fill(
                    circle,
                    with: .color(Color.white.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Spawn Fish

    private func spawnFish() {
        tankFish = weeklyCatches.enumerated().map { index, catchItem in
            let cols = min(weeklyCatches.count, 4)
            let row = index / cols
            let col = index % cols

            // Distribute across the tank with some randomness
            let baseX = 0.15 + (0.7 / Double(cols)) * (Double(col) + 0.5)
            let baseY = 0.3 + Double(row) * 0.2
            let jitterX = Double.random(in: -0.06...0.06)
            let jitterY = Double.random(in: -0.04...0.04)

            return TankFish(
                id: catchItem.id,
                catchData: catchItem,
                x: CGFloat(baseX + jitterX),
                y: CGFloat(min(max(baseY + jitterY, 0.2), 0.72)),
                speed: catchItem.species.swimSpeed + Double.random(in: -0.5...0.5),
                amplitude: CGFloat.random(in: 4...10),
                flipped: Bool.random(),
                phaseOffset: Double.random(in: 0...(.pi * 2))
            )
        }
    }

    private func spawnBubbles() {
        bubbles = (0..<8).map { _ in
            BubbleParticle(
                x: CGFloat.random(in: 0.1...0.9),
                radius: CGFloat.random(in: 1.5...3.5),
                speed: Double.random(in: 0.03...0.08),
                startOffset: Double.random(in: 0...1),
                wobble: Double.random(in: 0...(.pi * 2))
            )
        }
    }

    // MARK: - Swim Cycle

    private func startSwimCycle() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.0 / 30.0))
                swimPhase += 1.0 / 30.0

                // Gentle horizontal drift + direction flip
                for i in tankFish.indices {
                    let drift = CGFloat.random(in: -0.0004...0.0004)
                    tankFish[i].x += drift

                    // Flip direction based on drift tendency
                    if drift > 0.0002 { tankFish[i].flipped = false }
                    else if drift < -0.0002 { tankFish[i].flipped = true }

                    // Soft edge wrapping (keep within 10%-90%)
                    if tankFish[i].x < 0.08 { tankFish[i].x = 0.92 }
                    else if tankFish[i].x > 0.92 { tankFish[i].x = 0.08 }
                }
            }
        }
    }

    // MARK: - Tap Handling

    private func handleWaterTap(at point: CGPoint) {
        // Add ripple
        var ripple = Ripple(point: point)
        ripples.append(ripple)

        withAnimation(.easeOut(duration: 0.8)) {
            if let idx = ripples.firstIndex(where: { $0.id == ripple.id }) {
                ripples[idx].scale = 3.0
                ripples[idx].opacity = 0
            }
        }

        // Clean up ripple after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            ripples.removeAll { $0.id == ripple.id }
        }

        // Scatter nearby fish
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

        // Drift back
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            for i in tankFish.indices {
                tankFish[i].isScattering = false
                withAnimation(.easeInOut(duration: 1.5)) {
                    tankFish[i].scatterOffset = .zero
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isScattered = false
            }
        }
    }
}

// MARK: - Bubble Particle

private struct BubbleParticle {
    let x: CGFloat
    let radius: CGFloat
    let speed: Double
    let startOffset: Double
    let wobble: Double
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
                ],
                level: 3,
                streak: 5
            )
            .padding(.horizontal)

            // Empty state
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
