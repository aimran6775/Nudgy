//
//  HomeWeatherOverlay.swift
//  Nudge
//
//  Weather particle overlay for the home screen.
//  Layers the SnowfallView and ShootingStar shapes from IntroVectorShapes
//  on top of the Antarctic environment for added atmosphere.
//
//  - Snowfall: gentle particles, intensity tied to mood (heavier in cold/stormy)
//  - Shooting stars: only visible at night/dusk, random intervals
//
//  All animations respect accessibilityReduceMotion.
//

import SwiftUI

// MARK: - Home Weather Overlay

struct HomeWeatherOverlay: View {
    var mood: EnvironmentMood
    var timeOfDay: AntarcticTimeOfDay

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Snow intensity based on mood: stormy=heavy, cold=medium, others=light
    private var snowIntensity: Double {
        switch mood {
        case .stormy:     return 0.8
        case .cold:       return 0.5
        case .warming:    return 0.25
        case .productive: return 0.15
        case .golden:     return 0.1
        }
    }

    /// Whether shooting stars should appear (night/dusk only)
    private var showShootingStars: Bool {
        timeOfDay == .night || timeOfDay == .dusk
    }

    var body: some View {
        ZStack {
            // Snowfall — always present, intensity varies
            if !reduceMotion {
                SnowfallView(intensity: snowIntensity)
                    .opacity(snowOpacity)
            }

            // Shooting stars — night sky only
            if showShootingStars && !reduceMotion {
                ShootingStar(startX: 0.75, startY: 0.08)
                ShootingStar(startX: 0.35, startY: 0.15)
                ShootingStar(startX: 0.9, startY: 0.05)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    /// Reduce snow opacity during productive/golden moods for cleaner UI
    private var snowOpacity: Double {
        switch mood {
        case .stormy:     return 0.9
        case .cold:       return 0.7
        case .warming:    return 0.5
        case .productive: return 0.35
        case .golden:     return 0.25
        }
    }
}

// MARK: - Preview

#Preview("Weather — Night Stormy") {
    ZStack {
        Color.black.ignoresSafeArea()
        HomeWeatherOverlay(mood: .stormy, timeOfDay: .night)
    }
}

#Preview("Weather — Day Productive") {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "1a1a3e"), Color(hex: "0a0a1a")],
            startPoint: .top,
            endPoint: .bottom
        ).ignoresSafeArea()
        HomeWeatherOverlay(mood: .productive, timeOfDay: .day)
    }
}
