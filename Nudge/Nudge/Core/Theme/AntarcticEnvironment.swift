//
//  AntarcticEnvironment.swift
//  Nudge
//
//  The Antarctic environment scene — Nudgy's home.
//  Composes layered background art, snow particles, and environmental props
//  into a living scene that reacts to the user's productivity state.
//
//  Layers (back to front):
//    0. Sky gradient (time-of-day / productivity-driven)
//    1. Aurora overlay (visible when productive)
//    2. Mountains / icebergs (static parallax layer)
//    3. Ground / ice shelf (where Nudgy stands)
//    4. Environmental props (igloo, campfire — unlockable)
//    5. Snow particles (code-driven from a single snowflake)
//
//  When artist PNGs aren't available, renders with code-drawn shapes + gradients.
//

import SwiftUI

// MARK: - Environment Mood

/// Drives the visual mood of the Antarctic scene based on productivity.
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
    
    var skyColors: [Color] {
        switch self {
        case .cold:
            return [Color(hex: "0A0A1A"), Color(hex: "0D1B2A"), Color(hex: "1B263B")]
        case .warming:
            return [Color(hex: "1B1B3A"), Color(hex: "2D1B4E"), Color(hex: "4A2040"), Color(hex: "6B3A5C")]
        case .productive:
            return [Color(hex: "0D1B3A"), Color(hex: "1B3A6B"), Color(hex: "2D6B9E")]
        case .golden:
            return [Color(hex: "2D1B0A"), Color(hex: "6B3A0A"), Color(hex: "CC7A1A"), Color(hex: "FFB84D")]
        case .stormy:
            return [Color(hex: "0A0A0F"), Color(hex: "1A1A2A"), Color(hex: "2A2A3A")]
        }
    }
    
    var auroraOpacity: Double {
        switch self {
        case .cold: return 0
        case .warming: return 0.15
        case .productive: return 0.4
        case .golden: return 0.6
        case .stormy: return 0
        }
    }
    
    var snowIntensity: Double {
        switch self {
        case .cold: return 1.0      // Heavy snow
        case .warming: return 0.6
        case .productive: return 0.3
        case .golden: return 0.1    // Barely any snow
        case .stormy: return 1.5    // Blizzard
        }
    }
    
    var groundBrightness: Double {
        switch self {
        case .cold: return 0.3
        case .warming: return 0.5
        case .productive: return 0.7
        case .golden: return 0.9
        case .stormy: return 0.2
        }
    }
}

// MARK: - Snow Particle System

/// A single snowflake particle.
private struct Snowflake: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let opacity: Double
    let speed: CGFloat        // Points per second
    let horizontalDrift: CGFloat
}

// MARK: - Antarctic Environment View

struct AntarcticEnvironment: View {
    
    let mood: EnvironmentMood
    let unlockedProps: Set<String>  // e.g. ["igloo", "campfire"]
    
    /// Size of the scene — fills available space
    var sceneWidth: CGFloat = 390
    var sceneHeight: CGFloat = 500
    
    @State private var snowflakes: [Snowflake] = []
    @State private var snowTimer: Timer?
    @State private var auroraPhase: Double = 0
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            // Layer 0: Sky gradient
            skyLayer
            
            // Layer 1: Aurora
            if mood.auroraOpacity > 0 {
                auroraLayer
            }
            
            // Layer 2: Mountains
            mountainLayer
            
            // Layer 3: Ground
            groundLayer
            
            // Layer 4: Props
            propsLayer
            
            // Layer 5: Snow particles
            if !reduceMotion {
                snowLayer
            }
            
            // Storm overlay
            if mood == .stormy {
                stormOverlay
            }
        }
        .frame(height: sceneHeight)
        .clipped()
        .onAppear { startSnow() }
        .onDisappear { stopSnow() }
        .onChange(of: mood) { _, _ in
            // Restart snow with new intensity
            stopSnow()
            startSnow()
        }
    }
    
    // MARK: - Sky Layer
    
    private var skyLayer: some View {
        LinearGradient(
            colors: mood.skyColors,
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 2.0), value: mood)
    }
    
    // MARK: - Aurora Layer
    
    private var auroraLayer: some View {
        ZStack {
            // Aurora band 1
            AuroraBand(
                color1: Color(hex: "00FF88").opacity(0.3),
                color2: Color(hex: "00AAFF").opacity(0.2),
                phase: auroraPhase
            )
            .offset(y: -sceneHeight * 0.25)
            
            // Aurora band 2
            AuroraBand(
                color1: Color(hex: "AA44FF").opacity(0.15),
                color2: Color(hex: "00FF88").opacity(0.2),
                phase: auroraPhase + 1.5
            )
            .offset(y: -sceneHeight * 0.2)
        }
        .opacity(mood.auroraOpacity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                auroraPhase = .pi * 2
            }
        }
    }
    
    // MARK: - Mountain Layer
    
    private var mountainLayer: some View {
        VStack {
            Spacer()
            
            // Mountains silhouette
            ZStack(alignment: .bottom) {
                // Far mountains (darker)
                MountainShape(peaks: [0.3, 0.6, 0.45, 0.7, 0.35, 0.55])
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "1A2A3A").opacity(0.8),
                                Color(hex: "0D1520").opacity(0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: sceneHeight * 0.35)
                
                // Near mountains (lighter)
                MountainShape(peaks: [0.25, 0.5, 0.35, 0.6, 0.3, 0.45, 0.55])
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "2A3A4A").opacity(0.7),
                                Color(hex: "1A2530").opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: sceneHeight * 0.25)
            }
        }
    }
    
    // MARK: - Ground Layer
    
    private var groundLayer: some View {
        VStack {
            Spacer()
            
            // Ice shelf / snow ground
            ZStack {
                // Base ice
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(mood.groundBrightness * 0.3),
                                Color(hex: "B0C4D4").opacity(mood.groundBrightness * 0.2),
                                Color(hex: "8AAABB").opacity(mood.groundBrightness * 0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: sceneHeight * 0.15)
                
                // Snow drifts on top edge
                SnowDriftShape()
                    .fill(Color.white.opacity(mood.groundBrightness * 0.25))
                    .frame(height: 30)
                    .offset(y: -sceneHeight * 0.075 + 5)
            }
            .animation(.easeInOut(duration: 1.5), value: mood)
        }
    }
    
    // MARK: - Props Layer
    
    private var propsLayer: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 40) {
                if unlockedProps.contains("igloo") {
                    // Placeholder igloo
                    Text("🏠")
                        .font(.system(size: 44))
                        .opacity(0.8)
                }
                
                Spacer()
                
                if unlockedProps.contains("campfire") {
                    // Placeholder campfire
                    Text("🔥")
                        .font(.system(size: 36))
                        .opacity(0.9)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, sceneHeight * 0.08)
        }
    }
    
    // MARK: - Snow Layer
    
    private var snowLayer: some View {
        Canvas { context, size in
            for flake in snowflakes {
                let rect = CGRect(
                    x: flake.x - flake.size / 2,
                    y: flake.y - flake.size / 2,
                    width: flake.size,
                    height: flake.size
                )
                context.opacity = flake.opacity
                context.fill(
                    Circle().path(in: rect),
                    with: .color(.white)
                )
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Storm Overlay
    
    private var stormOverlay: some View {
        Color(hex: "1A1A2A")
            .opacity(0.3)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
    
    // MARK: - Snow Particle System
    
    private func startSnow() {
        guard !reduceMotion else { return }
        
        let baseCount = Int(20 * mood.snowIntensity)
        snowflakes = (0..<baseCount).map { _ in
            Snowflake(
                x: CGFloat.random(in: 0...sceneWidth),
                y: CGFloat.random(in: -50...sceneHeight),
                size: CGFloat.random(in: 2...5),
                opacity: Double.random(in: 0.3...0.7),
                speed: CGFloat.random(in: 15...40),
                horizontalDrift: CGFloat.random(in: -10...10)
            )
        }
        
        // Update snowflake positions at 30fps
        snowTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            let dt: CGFloat = 1.0 / 30.0
            for i in snowflakes.indices {
                snowflakes[i].y += snowflakes[i].speed * dt
                snowflakes[i].x += snowflakes[i].horizontalDrift * dt
                
                // Respawn at top when off screen
                if snowflakes[i].y > sceneHeight + 10 {
                    snowflakes[i].y = -10
                    snowflakes[i].x = CGFloat.random(in: 0...sceneWidth)
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
                
                let steps = 20
                for i in 0...steps {
                    let x = size.width * CGFloat(i) / CGFloat(steps)
                    let wave = sin(Double(i) * 0.5 + phase) * 20
                    let y = size.height * 0.5 + CGFloat(wave)
                    p.addLine(to: CGPoint(x: x, y: y))
                }
                
                // Close the shape
                p.addLine(to: CGPoint(x: size.width, y: size.height))
                p.addLine(to: CGPoint(x: 0, y: size.height))
                p.closeSubpath()
            }
            
            context.fill(path, with: .linearGradient(
                Gradient(colors: [color1, color2, .clear]),
                startPoint: CGPoint(x: size.width * 0.3, y: 0),
                endPoint: CGPoint(x: size.width * 0.7, y: size.height)
            ))
        }
        .frame(height: 80)
        .blur(radius: 20)
    }
}

// MARK: - Mountain Shape

private struct MountainShape: Shape {
    let peaks: [CGFloat]  // Heights as fractions of available height (0.0–1.0)
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard peaks.count >= 2 else { return path }
        
        let segmentWidth = rect.width / CGFloat(peaks.count - 1)
        
        path.move(to: CGPoint(x: 0, y: rect.height))
        
        for (i, height) in peaks.enumerated() {
            let x = CGFloat(i) * segmentWidth
            let y = rect.height * (1 - height)
            
            if i == 0 {
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                let prevX = CGFloat(i - 1) * segmentWidth
                let midX = (prevX + x) / 2
                path.addQuadCurve(
                    to: CGPoint(x: x, y: y),
                    control: CGPoint(x: midX, y: min(y, rect.height * (1 - peaks[i-1])) - 10)
                )
            }
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Snow Drift Shape

private struct SnowDriftShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: 0, y: rect.height))
        
        // Gentle rolling snow drifts
        let drifts = [0.6, 0.3, 0.5, 0.2, 0.7, 0.4, 0.55, 0.25]
        let segWidth = rect.width / CGFloat(drifts.count)
        
        for (i, height) in drifts.enumerated() {
            let x = CGFloat(i) * segWidth + segWidth / 2
            let y = rect.height * (1 - height * 0.6)
            
            if i == 0 {
                path.addQuadCurve(
                    to: CGPoint(x: x, y: y),
                    control: CGPoint(x: x / 2, y: y + 5)
                )
            } else {
                let prevX = CGFloat(i - 1) * segWidth + segWidth / 2
                path.addQuadCurve(
                    to: CGPoint(x: x, y: y),
                    control: CGPoint(x: (prevX + x) / 2, y: y + 8)
                )
            }
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Preview

#Preview("Antarctic Environment — Productive") {
    AntarcticEnvironment(mood: .productive, unlockedProps: ["igloo"])
        .ignoresSafeArea()
}

#Preview("Antarctic Environment — Cold") {
    AntarcticEnvironment(mood: .cold, unlockedProps: [])
        .ignoresSafeArea()
}

#Preview("Antarctic Environment — Golden") {
    AntarcticEnvironment(mood: .golden, unlockedProps: ["igloo", "campfire"])
        .ignoresSafeArea()
}
