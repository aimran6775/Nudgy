//
//  AmbientFishScene.swift
//  Nudge
//
//  Ambient swimming fish that lazily drift around behind/beside Nudgy
//  on the ice shelf. The fish count matches earned fish today from
//  RewardService. Fish scatter on tap and swim back slowly.
//
//  Uses FishView from IntroVectorShapes for the bezier-drawn fish art.
//

import SwiftUI

// MARK: - Swimming Fish Model

struct SwimmingFish: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var accentColor: Color
    var speed: Double          // seconds per full swim cycle
    var amplitude: CGFloat     // vertical bob amplitude
    var flipped: Bool          // swim direction (true = left-facing)
    var opacity: Double
    var scatterOffset: CGSize = .zero
    var isScattering: Bool = false
}

// MARK: - Ambient Fish Scene

/// Overlays small fish lazily swimming around Nudgy.
/// Count is based on earned rewards. Max 6 visible at once for performance.
struct AmbientFishScene: View {
    var fishEarned: Int
    var sceneWidth: CGFloat
    var sceneHeight: CGFloat
    var onTap: (() -> Void)?

    @State private var fish: [SwimmingFish] = []
    @State private var swimPhase: CGFloat = 0
    @State private var isScattered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Palette — matches intro fish colors
    private static let fishPalette: [(Color, Color)] = [
        (Color(hex: "4FC3F7"), Color(hex: "0288D1")),   // Ocean blue
        (Color(hex: "FF8A65"), Color(hex: "E64A19")),   // Coral orange
        (Color(hex: "81C784"), Color(hex: "388E3C")),   // Sea green
        (Color(hex: "BA68C8"), Color(hex: "7B1FA2")),   // Purple
        (Color(hex: "FFD54F"), Color(hex: "F57F17")),   // Golden
        (Color(hex: "4DD0E1"), Color(hex: "00838F")),   // Teal
    ]

    /// Always show at least 2 fish so the scene feels alive from first launch.
    /// Additional fish appear as the user completes tasks.
    private var visibleCount: Int {
        min(max(fishEarned, 2), 6)
    }

    var body: some View {
        ZStack {
            ForEach(fish) { f in
                fishBody(f)
            }
        }
        .allowsHitTesting(true)
        .contentShape(Rectangle())
        .onTapGesture {
            scatterFish()
            onTap?()
        }
        .onAppear {
            spawnFish()
            guard !reduceMotion else { return }
            startSwimCycle()
        }
        .onChange(of: fishEarned) { _, _ in
            respawnIfNeeded()
        }
    }

    // MARK: - Fish Body

    @ViewBuilder
    private func fishBody(_ f: SwimmingFish) -> some View {
        let phase: Double = swimPhase * .pi * 2
        let phaseOffset: Double = phase / f.speed + Double(f.x) * 0.01
        let sinWave: CGFloat = CGFloat(sin(phaseOffset)) * f.amplitude
        let yOffset: CGFloat = reduceMotion ? 0 : sinWave
        let combinedY: CGFloat = yOffset + f.scatterOffset.height
        let anim: Animation = f.isScattering
            ? .spring(response: 0.3, dampingFraction: 0.5)
            : .easeInOut(duration: f.speed * 0.5)

        FishView(size: f.size, color: f.color, accentColor: f.accentColor)
            .scaleEffect(x: f.flipped ? -1 : 1, y: 1)
            .opacity(f.opacity)
            .offset(x: f.scatterOffset.width, y: combinedY)
            .position(x: f.x, y: f.y)
            .animation(anim, value: f.scatterOffset)
    }

    // MARK: - Spawning

    private func spawnFish() {
        guard visibleCount > 0 else { return }

        fish = (0..<visibleCount).map { i in
            let palette = Self.fishPalette[i % Self.fishPalette.count]
            let flipped = Bool.random()
            return SwimmingFish(
                x: CGFloat.random(in: sceneWidth * 0.15 ... sceneWidth * 0.85),
                y: sceneHeight * CGFloat.random(in: 0.55 ... 0.72),
                size: CGFloat.random(in: 18...30),
                color: palette.0,
                accentColor: palette.1,
                speed: Double.random(in: 3.0...6.0),
                amplitude: CGFloat.random(in: 4...10),
                flipped: flipped,
                opacity: Double.random(in: 0.5...0.8)
            )
        }
    }

    private func respawnIfNeeded() {
        let target = visibleCount
        if target > fish.count {
            // Add more fish
            for i in fish.count..<target {
                let palette = Self.fishPalette[i % Self.fishPalette.count]
                let newFish = SwimmingFish(
                    x: CGFloat.random(in: sceneWidth * 0.15 ... sceneWidth * 0.85),
                    y: sceneHeight * CGFloat.random(in: 0.55 ... 0.72),
                    size: CGFloat.random(in: 18...30),
                    color: palette.0,
                    accentColor: palette.1,
                    speed: Double.random(in: 3.0...6.0),
                    amplitude: CGFloat.random(in: 4...10),
                    flipped: Bool.random(),
                    opacity: 0
                )
                fish.append(newFish)
                // Fade in
                withAnimation(.easeIn(duration: 0.8)) {
                    if let idx = fish.firstIndex(where: { $0.id == newFish.id }) {
                        fish[idx].opacity = Double.random(in: 0.5...0.8)
                    }
                }
            }
        } else if target < fish.count {
            // Remove excess (fade out)
            let excess = fish.count - target
            for i in 0..<excess {
                let idx = fish.count - 1 - i
                guard idx >= 0 else { break }
                withAnimation(.easeOut(duration: 0.5)) {
                    fish[idx].opacity = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                fish = Array(fish.prefix(target))
            }
        }
    }

    // MARK: - Swim Cycle

    private func startSwimCycle() {
        Task { @MainActor in
            while true {
                try? await Task.sleep(for: .seconds(1.0 / 30.0))
                swimPhase += 1.0 / 30.0

                // Gentle horizontal drift
                for i in fish.indices {
                    let drift = CGFloat.random(in: -0.15...0.15)
                    fish[i].x += drift
                    // Wrap around edges
                    if fish[i].x < -20 {
                        fish[i].x = sceneWidth + 15
                    } else if fish[i].x > sceneWidth + 20 {
                        fish[i].x = -15
                    }
                }
            }
        }
    }

    // MARK: - Scatter

    private func scatterFish() {
        guard !isScattered else { return }
        isScattered = true
        HapticService.shared.prepare()

        for i in fish.indices {
            fish[i].isScattering = true
            let scatterX = CGFloat.random(in: -60...60)
            let scatterY = CGFloat.random(in: -40...40)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                fish[i].scatterOffset = CGSize(width: scatterX, height: scatterY)
            }
        }

        // Swim back slowly
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            for i in fish.indices {
                fish[i].isScattering = false
                withAnimation(.easeInOut(duration: 2.0)) {
                    fish[i].scatterOffset = .zero
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isScattered = false
            }
        }
    }
}

// MARK: - Preview

#Preview("Ambient Fish") {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientFishScene(
            fishEarned: 4,
            sceneWidth: UIScreen.main.bounds.width,
            sceneHeight: UIScreen.main.bounds.height
        )
    }
}
