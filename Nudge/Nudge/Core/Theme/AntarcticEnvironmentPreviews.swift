//
//  AntarcticEnvironmentPreviews.swift
//  Nudge
//
//  Isolated previews for each Antarctic layer.
//  Open this file in Xcode and use the Canvas to see individual layers
//  WITHOUT building/deploying to a device.
//
//  Usage:
//    1. Open this file in Xcode
//    2. Press Opt+Cmd+P (or Editor → Canvas) to show the preview canvas
//    3. Pick a preview from the dropdown at the top of the canvas
//    4. Edit AntarcticEnvironment.swift — previews update live
//

import SwiftUI

// MARK: - Layer Isolation Preview

/// A reusable preview wrapper that renders just the bottom portion of the scene
/// where the platform lives, with a consistent size and dark background.
/// This lets you see EXACTLY what the ground/platform area looks like.
private struct PlatformAreaPreview<Content: View>: View {
    let title: String
    let time: AntarcticTimeOfDay
    @ViewBuilder let content: (CGFloat, CGFloat) -> Content

    private let width: CGFloat = 393  // iPhone 15 Pro width
    private let height: CGFloat = 852 // iPhone 15 Pro height

    var body: some View {
        ZStack {
            // Background: show what's "behind" — bright red so gaps are obvious
            Color.red

            // The layer under test
            content(width, height)
        }
        .frame(width: width, height: height)
        .clipped()
        .overlay(alignment: .top) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(6)
                .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                .padding(8)
        }
        .preferredColorScheme(.dark)
    }
}

// ═══════════════════════════════════════════════════════
//  1. JUST THE GROUND FILL (safety net layer)
// ═══════════════════════════════════════════════════════

#Preview("🔴 Ground Fill Only") {
    PlatformAreaPreview(title: "Ground Fill — should cover all red below cliff line", time: .day) { w, h in
        let groundTop = h * (AntarcticEnvironment.cliffSurfaceY - 0.12)
        let groundHeight = h - groundTop + 100

        // Cliff line marker
        Rectangle()
            .fill(.yellow)
            .frame(width: w, height: 1)
            .position(x: w / 2, y: h * AntarcticEnvironment.cliffSurfaceY)

        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        AntarcticTimeOfDay.day.iceShelfTop,
                        AntarcticTimeOfDay.day.iceShelfBody,
                        AntarcticTimeOfDay.day.iceShelfDeep,
                        Color(hex: "06101E"),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: w + 100, height: groundHeight)
            .position(x: w / 2, y: groundTop + groundHeight / 2)
    }
}

// ═══════════════════════════════════════════════════════
//  2. GROUND FILL + ICE SHELF PLATFORM
// ═══════════════════════════════════════════════════════

#Preview("🧊 Ground + Platform") {
    PlatformAreaPreview(title: "Ground fill + Ice shelf platform layered", time: .day) { w, h in
        let cliffY = AntarcticEnvironment.cliffSurfaceY

        // Yellow cliff line marker
        Rectangle()
            .fill(.yellow)
            .frame(width: w, height: 1)
            .position(x: w / 2, y: h * cliffY)

        // Ground fill (same as Layer 0a)
        let groundTop = h * (cliffY - 0.12)
        let groundHeight = h - groundTop + 100
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        AntarcticTimeOfDay.day.iceShelfTop,
                        AntarcticTimeOfDay.day.iceShelfBody,
                        AntarcticTimeOfDay.day.iceShelfDeep,
                        Color(hex: "06101E"),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: w + 100, height: groundHeight)
            .position(x: w / 2, y: groundTop + groundHeight / 2)

        // Platform (same as Layer 9)
        AntarcticEnvironment(
            mood: .productive,
            unlockedProps: [],
            fishCount: 5,
            level: 3,
            stage: .bareIce,
            sceneWidth: w,
            sceneHeight: h,
            timeOverride: .day
        )
    }
}

// ═══════════════════════════════════════════════════════
//  3. FULL SCENE — ALL TIMES OF DAY (side by side)
// ═══════════════════════════════════════════════════════

#Preview("🌅 All Times — Side by Side") {
    ScrollView(.horizontal) {
        HStack(spacing: 12) {
            ForEach(
                [
                    ("Dawn", AntarcticTimeOfDay.dawn, EnvironmentMood.warming),
                    ("Day", AntarcticTimeOfDay.day, EnvironmentMood.productive),
                    ("Dusk", AntarcticTimeOfDay.dusk, EnvironmentMood.golden),
                    ("Night", AntarcticTimeOfDay.night, EnvironmentMood.cold),
                    ("Storm", AntarcticTimeOfDay.day, EnvironmentMood.stormy),
                ],
                id: \.0
            ) { label, time, mood in
                VStack(spacing: 4) {
                    AntarcticEnvironment(
                        mood: mood,
                        unlockedProps: ["lantern"],
                        fishCount: 10,
                        level: 5,
                        stage: .fishingPier,
                        sceneWidth: 180,
                        sceneHeight: 390,
                        timeOverride: time
                    )
                    .frame(width: 180, height: 390)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Text(label)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
        }
        .padding()
    }
    .background(.black)
    .preferredColorScheme(.dark)
}

// ═══════════════════════════════════════════════════════
//  4. DEBUG GRID — shows layer boundaries
// ═══════════════════════════════════════════════════════

#Preview("📐 Debug Grid — Layer Boundaries") {
    let w: CGFloat = 393
    let h: CGFloat = 852
    let cliffY = AntarcticEnvironment.cliffSurfaceY

    ZStack {
        // Full scene
        AntarcticEnvironment(
            mood: .productive,
            unlockedProps: [],
            fishCount: 5,
            level: 3,
            stage: .bareIce,
            sceneWidth: w,
            sceneHeight: h,
            timeOverride: .day
        )

        // Debug overlay: key horizontal lines
        VStack(spacing: 0) {
            // cliffSurfaceY line
            Spacer()
                .frame(height: h * cliffY)

            Rectangle()
                .fill(.red)
                .frame(height: 2)

            // Ocean region (cliffY - 0.08 to cliffY + 0.04)
            Spacer()
        }

        // Labels
        VStack(spacing: 0) {
            Spacer().frame(height: h * (cliffY - 0.12))
            Text("groundFill starts")
                .font(.system(size: 9).bold())
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 4)

            Spacer().frame(height: h * 0.04)
            Text("ocean starts")
                .font(.system(size: 9).bold())
                .foregroundStyle(.cyan)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 4)

            Spacer().frame(height: h * 0.04)
            Text("cliffSurfaceY = \(String(format: "%.0f", h * cliffY))pt")
                .font(.system(size: 9).bold())
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 4)

            Spacer()
        }
    }
    .frame(width: w, height: h)
    .clipped()
    .preferredColorScheme(.dark)
}

// ═══════════════════════════════════════════════════════
//  5. RED GAP DETECTOR
// ═══════════════════════════════════════════════════════
//  Puts a RED background behind the full scene.
//  If you see ANY red pixels, there's a transparency gap.

#Preview("🚨 Gap Detector (red = gap)") {
    let w: CGFloat = 393
    let h: CGFloat = 852

    ZStack {
        // Bright red — any red showing through = transparency bug
        Color.red.ignoresSafeArea()

        AntarcticEnvironment(
            mood: .cold,       // worst case: cold mood has lowest brightness
            unlockedProps: [],
            fishCount: 0,
            level: 1,
            stage: .bareIce,
            sceneWidth: w,
            sceneHeight: h,
            timeOverride: .day
        )
    }
    .frame(width: w, height: h)
    .preferredColorScheme(.dark)
}

#Preview("🚨 Gap Detector — Night Cold") {
    let w: CGFloat = 393
    let h: CGFloat = 852

    ZStack {
        Color.red.ignoresSafeArea()

        AntarcticEnvironment(
            mood: .cold,
            unlockedProps: [],
            fishCount: 0,
            level: 1,
            stage: .bareIce,
            sceneWidth: w,
            sceneHeight: h,
            timeOverride: .night
        )
    }
    .frame(width: w, height: h)
    .preferredColorScheme(.dark)
}

#Preview("🚨 Gap Detector — Storm") {
    let w: CGFloat = 393
    let h: CGFloat = 852

    ZStack {
        Color.red.ignoresSafeArea()

        AntarcticEnvironment(
            mood: .stormy,
            unlockedProps: [],
            fishCount: 0,
            level: 1,
            stage: .bareIce,
            sceneWidth: w,
            sceneHeight: h,
            timeOverride: .day
        )
    }
    .frame(width: w, height: h)
    .preferredColorScheme(.dark)
}
