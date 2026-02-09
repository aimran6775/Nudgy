//
//  FishRewardAnimation.swift
//  Nudge
//
//  Animated fish that fly from a completed task into the AltitudeHUD fish counter.
//
//  Usage:
//    1. Overlay `FishRewardOverlay` on top of the NudgyHomeView ZStack.
//    2. When a task is completed, call `FishRewardEngine.shared.spawnFish(count:from:to:)`.
//    3. Golden fish fly in an arc from the task card position to the HUD fish icon.
//
//  The animation is lightweight: simple Path arcs rendered via Canvas + Timer,
//  no particle system overhead. Each fish is a tiny golden shape that follows
//  a bezier curve with slight randomness.
//

import SwiftUI

// MARK: - Flying Fish Model

struct FlyingFish: Identifiable {
    let id = UUID()
    var progress: CGFloat = 0         // 0 → 1 along the flight path
    let startPoint: CGPoint
    let endPoint: CGPoint
    let controlOffset: CGPoint        // randomized bezier control offset
    let size: CGFloat
    let delay: TimeInterval           // stagger start
    var hasLaunched: Bool = false
    let rotationSpeed: Double
    var opacity: Double = 1.0
}

// MARK: - Fish Reward Engine

/// Singleton that manages the flying fish reward animation state.
@Observable
final class FishRewardEngine {
    static let shared = FishRewardEngine()

    private(set) var activeFish: [FlyingFish] = []
    private(set) var isAnimating = false
    private var timer: Timer?
    private var startTime: Date = .now

    private init() {}

    /// Spawn `count` fish that fly from `origin` to `destination` in screen coordinates.
    func spawnFish(count: Int, from origin: CGPoint, to destination: CGPoint) {
        guard count > 0 else { return }

        let newFish: [FlyingFish] = (0..<count).map { i in
            // Randomized control point for varied arc paths
            let controlX = CGFloat.random(in: -80...80)
            let controlY = CGFloat.random(in: -120 ... -40)

            return FlyingFish(
                startPoint: origin,
                endPoint: destination,
                controlOffset: CGPoint(x: controlX, y: controlY),
                size: CGFloat.random(in: 8...14),
                delay: Double(i) * 0.08,
                rotationSpeed: Double.random(in: 2...5)
            )
        }

        activeFish.append(contentsOf: newFish)

        if !isAnimating {
            startAnimation()
        }
    }

    private func startAnimation() {
        isAnimating = true
        startTime = .now

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.tick()
        }
    }

    private func tick() {
        let elapsed = Date.now.timeIntervalSince(startTime)
        var allDone = true

        for i in activeFish.indices {
            // Stagger: don't start until delay has passed
            guard elapsed >= activeFish[i].delay else {
                allDone = false
                continue
            }

            if !activeFish[i].hasLaunched {
                activeFish[i].hasLaunched = true
            }

            // Advance progress (0.6s flight duration)
            let flightDuration: CGFloat = 0.6
            let fishElapsed = CGFloat(elapsed - activeFish[i].delay)
            activeFish[i].progress = min(1.0, fishElapsed / flightDuration)

            // Fade out near the end
            if activeFish[i].progress > 0.8 {
                activeFish[i].opacity = Double(1.0 - (activeFish[i].progress - 0.8) / 0.2)
            }

            if activeFish[i].progress < 1.0 {
                allDone = false
            }
        }

        if allDone {
            stopAnimation()
        }
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
        activeFish.removeAll()
        isAnimating = false
    }
}

// MARK: - Fish Reward Overlay

/// Full-screen overlay that renders flying fish. Place in a ZStack above all content.
struct FishRewardOverlay: View {
    private let engine = FishRewardEngine.shared

    var body: some View {
        if engine.isAnimating {
            Canvas { context, size in
                for fish in engine.activeFish where fish.hasLaunched {
                    let pos = bezierPoint(
                        start: fish.startPoint,
                        end: fish.endPoint,
                        control: fish.controlOffset,
                        t: easeOutCubic(fish.progress)
                    )

                    // Fish shape — simple diamond with tail
                    let fishPath = Path { p in
                        let s = fish.size
                        // Body (diamond)
                        p.move(to: CGPoint(x: pos.x - s * 0.5, y: pos.y))
                        p.addLine(to: CGPoint(x: pos.x, y: pos.y - s * 0.3))
                        p.addLine(to: CGPoint(x: pos.x + s * 0.4, y: pos.y))
                        p.addLine(to: CGPoint(x: pos.x, y: pos.y + s * 0.3))
                        p.closeSubpath()

                        // Tail
                        p.move(to: CGPoint(x: pos.x + s * 0.4, y: pos.y))
                        p.addLine(to: CGPoint(x: pos.x + s * 0.7, y: pos.y - s * 0.2))
                        p.addLine(to: CGPoint(x: pos.x + s * 0.7, y: pos.y + s * 0.2))
                        p.closeSubpath()
                    }

                    context.opacity = fish.opacity
                    context.fill(fishPath, with: .linearGradient(
                        Gradient(colors: [
                            Color(hex: "FFD700"),
                            Color(hex: "FF8C00"),
                        ]),
                        startPoint: CGPoint(x: pos.x - fish.size, y: pos.y),
                        endPoint: CGPoint(x: pos.x + fish.size, y: pos.y)
                    ))

                    // Sparkle trail
                    if fish.progress < 0.9 {
                        let sparkle = CGRect(
                            x: pos.x + fish.size * 0.6,
                            y: pos.y - 1,
                            width: 2, height: 2
                        )
                        context.opacity = fish.opacity * 0.6
                        context.fill(Circle().path(in: sparkle), with: .color(.white))
                    }
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
    }

    // MARK: - Math Helpers

    /// Quadratic bezier point at parameter t.
    private func bezierPoint(start: CGPoint, end: CGPoint, control: CGPoint, t: CGFloat) -> CGPoint {
        // Control point is relative to midpoint of start→end
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let cp = CGPoint(x: mid.x + control.x, y: mid.y + control.y)

        let oneMinusT = 1 - t
        let x = oneMinusT * oneMinusT * start.x + 2 * oneMinusT * t * cp.x + t * t * end.x
        let y = oneMinusT * oneMinusT * start.y + 2 * oneMinusT * t * cp.y + t * t * end.y
        return CGPoint(x: x, y: y)
    }

    private func easeOutCubic(_ t: CGFloat) -> CGFloat {
        1 - pow(1 - t, 3)
    }
}

// MARK: - Preview

#Preview("Fish Reward") {
    ZStack {
        Color.black

        FishRewardOverlay()

        Button("Spawn Fish") {
            FishRewardEngine.shared.spawnFish(
                count: 5,
                from: CGPoint(x: 200, y: 500),
                to: CGPoint(x: 200, y: 80)
            )
        }
        .foregroundStyle(.white)
    }
}
