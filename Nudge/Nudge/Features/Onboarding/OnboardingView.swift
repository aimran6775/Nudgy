//
//  OnboardingView.swift
//  Nudge
//
//  Post-auth glassmorphic onboarding — Nudgy teaches you the ropes.
//  Page 1: Brain dump with Nudgy
//  Page 2: One card at a time
//  Page 3: Name + get started
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0
    @State private var firstName: String = ""
    @FocusState private var nameFieldFocused: Bool

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            mascot: .listening,
            title: String(localized: "Talk, don't type"),
            body: String(localized: "Tap the mic and unload everything. Nudgy turns your ramble into neat task cards."),
            gradient: [Color(hex: "BF5AF2"), Color(hex: "FF375F")]
        ),
        OnboardingPage(
            mascot: .happy,
            title: String(localized: "One card at a time"),
            body: String(localized: "No overwhelming lists. Handle one task, swipe it done, see the next. Simple as that."),
            gradient: [Color(hex: "30D158"), Color(hex: "0A84FF")]
        ),
        OnboardingPage(
            mascot: .celebrating,
            title: String(localized: "Ready to roll!"),
            body: String(localized: "Nudgy's here whenever you need a nudge. Let's get your first brain unload going."),
            gradient: [Color(hex: "0A84FF"), Color(hex: "5E5CE6")]
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
                            completeOnboarding()
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
                        pageView(pages[i], index: i)
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
                .offset(x: -60, y: -220)
                .blur(radius: 80)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [pages[currentPage].gradient[1].opacity(0.15), .clear],
                        center: .center, startRadius: 0, endRadius: 220
                    )
                )
                .frame(width: 450, height: 450)
                .offset(x: 100, y: 320)
                .blur(radius: 60)
        }
        .animation(.easeInOut(duration: 0.8), value: currentPage)
    }

    // MARK: - Page View

    private func pageView(_ page: OnboardingPage, index: Int) -> some View {
        VStack(spacing: DesignTokens.spacingXL) {
            Spacer()

            // Nudgy penguin
            PenguinSceneView(
                size: .large,
                expressionOverride: page.mascot
            )
            .scaleEffect(currentPage == index ? 1 : 0.75)
            .opacity(currentPage == index ? 1 : 0)
            .animation(springAnimation, value: currentPage)

            // Glass card with text
            VStack(spacing: DesignTokens.spacingMD) {
                Text(page.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(page.body)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                // Name field on last page
                if index == pages.count - 1 {
                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.white.opacity(0.35))
                                .frame(width: 20)
                            TextField(String(localized: "Your first name (optional)"), text: $firstName)
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundStyle(.white)
                                .focused($nameFieldFocused)
                                .submitLabel(.done)
                                .textContentType(.givenName)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(0.1), lineWidth: 0.5)
                        )

                        Text(String(localized: "Used to sign off AI-drafted messages"))
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(DesignTokens.spacingXL)
            .frame(maxWidth: .infinity)
            .background(glassCard)
            .padding(.horizontal, DesignTokens.spacingLG)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Glass

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.4))
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.04)],
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
            // Pill dots
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? .white : .white.opacity(0.25))
                        .frame(width: i == currentPage ? 24 : 8, height: 8)
                        .animation(springAnimation, value: currentPage)
                }
            }

            if currentPage == pages.count - 1 {
                // Get Started
                Button {
                    completeOnboarding()
                } label: {
                    Text(String(localized: "Let's go! 🐧"))
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
                        .shadow(color: pages[currentPage].gradient[0].opacity(0.35), radius: 20, y: 8)
                }
                .padding(.horizontal, DesignTokens.spacingXL)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
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
                                .fill(.white.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.15), lineWidth: 0.5)
                        )
                }
                .padding(.horizontal, DesignTokens.spacingXL)
            }
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            settings.userName = trimmed
        }
        withAnimation(springAnimation) {
            settings.hasCompletedOnboarding = true
        }
    }
}

// MARK: - Model

private struct OnboardingPage {
    let mascot: PenguinExpression
    let title: String
    let body: String
    let gradient: [Color]
}

#Preview {
    OnboardingView()
        .environment(AppSettings())
        .environment(PenguinState())
}
