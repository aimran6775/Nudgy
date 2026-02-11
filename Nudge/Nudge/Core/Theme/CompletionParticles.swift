//
//  CompletionParticles.swift
//  Nudge
//
//  Green checkmark particle burst effect played when a task is swiped "Done".
//  Small green dots radiate outward from the card center and fade.
//  Respects Reduce Motion — cross-fades a simple checkmark instead.
//

import SwiftUI

// MARK: - Particle Model

private struct Particle: Identifiable {
    let id = UUID()
    let angle: Double      // Radians — direction of travel
    let distance: CGFloat  // How far it travels
    let size: CGFloat      // Dot diameter
    let delay: Double      // Stagger
}

// MARK: - Completion Particles View

struct CompletionParticles: View {
    
    @Binding var isActive: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var animating = false
    @State private var showCheck = false
    
    // Pre-computed particles — deterministic, no random re-rolls
    private let particles: [Particle] = {
        let count = 12
        var result: [Particle] = []
        for i in 0..<count {
            let angle = (Double(i) / Double(count)) * 2 * .pi + Double(i) * 0.3
            let distance: CGFloat = CGFloat(40 + (i % 3) * 20)
            let size: CGFloat = CGFloat(4 + (i % 4))
            let delay = Double(i) * 0.02
            result.append(Particle(angle: angle, distance: distance, size: size, delay: delay))
        }
        return result
    }()
    
    var body: some View {
        ZStack {
            if reduceMotion {
                // Simple checkmark fade for Reduce Motion users
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(DesignTokens.accentComplete)
                    .opacity(showCheck ? 1 : 0)
                    .scaleEffect(showCheck ? 1.0 : 0.5)
            } else {
                // Particle burst
                ForEach(particles) { particle in
                    Circle()
                        .fill(DesignTokens.accentComplete)
                        .frame(width: particle.size, height: particle.size)
                        .offset(
                            x: animating ? cos(particle.angle) * particle.distance : 0,
                            y: animating ? sin(particle.angle) * particle.distance : 0
                        )
                        .opacity(animating ? 0 : 1)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.6)
                                .delay(particle.delay),
                            value: animating
                        )
                }
                
                // Central checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DesignTokens.accentComplete)
                    .scaleEffect(showCheck ? 1.0 : 0.1)
                    .opacity(showCheck ? 0 : 1)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.5),
                        value: showCheck
                    )
            }
        }
        .onChange(of: isActive) { _, active in
            guard active else {
                animating = false
                showCheck = false
                return
            }
            
            // Trigger the burst
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.3)) {
                    showCheck = true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.8))
                    withAnimation(.easeOut(duration: 0.2)) {
                        showCheck = false
                    }
                    isActive = false
                }
            } else {
                showCheck = true
                animating = true
                
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.6))
                    withAnimation(.easeOut(duration: 0.15)) {
                        showCheck = false
                    }
                    try? await Task.sleep(for: .seconds(0.2))
                    animating = false
                    isActive = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var active = false
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 40) {
                    CompletionParticles(isActive: $active)
                    
                    Button("Trigger") {
                        active = true
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
    return PreviewWrapper()
}
