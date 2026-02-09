//
//  IntroView.swift
//  Nudge
//
//  Glassmorphic intro pages — shown once before auth.
//  Uses Nudgy (PenguinSceneView) as the hero, not emojis.
//

import SwiftUI

struct IntroView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0

    private let pages: [IntroPage] = [
        IntroPage(
            mascot: .waving,
            headline: String(localized: "Meet Nudgy"),
            body: String(localized: "Your tiny penguin companion who turns brain chaos into calm, one nudge at a time."),
            gradient: [Color(hex: "0A84FF"), Color(hex: "5E5CE6")]
        ),
        IntroPage(
            mascot: .listening,
            headline: String(localized: "Brain dump, not burnout"),
            body: String(localized: "Tap the mic and say everything on your mind. Nudgy sorts it into bite-sized tasks for you."),
            gradient: [Color(hex: "BF5AF2"), Color(hex: "FF375F")]
        ),
        IntroPage(
            mascot: .happy,
            headline: String(localized: "One thing at a time"),
            body: String(localized: "No endless lists. Just one card. Handle it. Move on. That's it."),
            gradient: [Color(hex: "30D158"), Color(hex: "0A84FF")]
        ),
    ]

    private var springAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.5, dampingFraction: 0.8)
    }

    var body: some View {
        ZStack {
            ambientBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button {
                            settings.hasSeenIntro = true
                        } label: {
                            Text(String(localized: "Skip"))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .padding(.trailing, DesignTokens.spacingLG)
                    }
                }
                .frame(height: 44)
                .padding(.top, DesignTokens.spacingSM)

                // Pages
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { i in
                        introPageView(pages[i], index: i)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom controls
                bottomControls
                    .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
        .animation(springAnimation, value: currentPage)
    }

    // MARK: - Ambient Background

    private var ambientBackground: some View {
        ZStack {
            Color.black

            Circle()
                .fill(
                    RadialGradient(
                        colors: [pages[currentPage].gradient[0].opacity(0.25), .clear],
                        center: .center, startRadius: 0, endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .offset(x: -50, y: -200)
                .blur(radius: 80)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [pages[currentPage].gradient[1].opacity(0.15), .clear],
                        center: .center, startRadius: 0, endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .offset(x: 100, y: 300)
                .blur(radius: 60)
        }
        .animation(.easeInOut(duration: 0.8), value: currentPage)
    }

    // MARK: - Page

    private func introPageView(_ page: IntroPage, index: Int) -> some View {
        VStack(spacing: DesignTokens.spacingXL) {
            Spacer()

            // Nudgy penguin hero
            PenguinSceneView(
                size: .large,
                expressionOverride: page.mascot
            )
            .scaleEffect(currentPage == index ? 1.0 : 0.7)
            .opacity(currentPage == index ? 1.0 : 0.0)
            .animation(springAnimation, value: currentPage)

            // Glass card
            VStack(spacing: DesignTokens.spacingMD) {
                Text(page.headline)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(page.body)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(DesignTokens.spacingXL)
            .frame(maxWidth: .infinity)
            .background(glassBackground)
            .padding(.horizontal, DesignTokens.spacingLG)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Glass

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.5))
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? .white : .white.opacity(0.3))
                        .frame(width: i == currentPage ? 24 : 8, height: 8)
                        .animation(springAnimation, value: currentPage)
                }
            }

            if currentPage == pages.count - 1 {
                Button {
                    withAnimation(springAnimation) {
                        settings.hasSeenIntro = true
                    }
                } label: {
                    Text(String(localized: "Get Started"))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: pages[currentPage].gradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(color: pages[currentPage].gradient[0].opacity(0.4), radius: 20, y: 8)
                }
                .padding(.horizontal, DesignTokens.spacingXL)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(springAnimation) { currentPage += 1 }
                } label: {
                    Text(String(localized: "Next"))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.white.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )
                }
                .padding(.horizontal, DesignTokens.spacingXL)
            }
        }
        .animation(springAnimation, value: currentPage)
    }
}

// MARK: - Model

private struct IntroPage {
    let mascot: PenguinExpression
    let headline: String
    let body: String
    let gradient: [Color]
}

#Preview {
    IntroView()
        .environment(AppSettings())
        .environment(PenguinState())
}
