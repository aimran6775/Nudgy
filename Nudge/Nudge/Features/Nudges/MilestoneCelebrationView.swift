//
//  MilestoneCelebrationView.swift
//  Nudge
//
//  Full-screen celebration overlay when the user hits a task milestone.
//  Big emoji, confetti-like particles, and a warm message from Nudgy.
//

import SwiftUI

struct MilestoneCelebrationView: View {
    
    let milestone: Int
    @Binding var isPresented: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showContent = false
    @State private var particlePhase: CGFloat = 0
    
    private var info: (title: String, subtitle: String, emoji: String) {
        MilestoneService.message(for: milestone)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.92)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            // Celebration particles
            if !reduceMotion {
                ForEach(0..<20, id: \.self) { i in
                    Circle()
                        .fill(particleColor(i))
                        .frame(width: CGFloat.random(in: 4...8))
                        .offset(
                            x: CGFloat.random(in: -150...150),
                            y: -200 + particlePhase * CGFloat.random(in: 300...500)
                        )
                        .opacity(1 - particlePhase)
                }
            }
            
            // Content
            if showContent {
                VStack(spacing: DesignTokens.spacingXXL) {
                    Spacer()
                    
                    Text(info.emoji)
                        .font(.system(size: 80))
                    
                    VStack(spacing: DesignTokens.spacingMD) {
                        Text(info.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(DesignTokens.accentComplete)
                        
                        Text(info.subtitle)
                            .font(AppTheme.body)
                            .foregroundStyle(DesignTokens.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignTokens.spacingXXL)
                    }
                    
                    // Bonus snowflakes
                    let bonus = MilestoneService.bonusSnowflakes(for: milestone)
                    HStack(spacing: DesignTokens.spacingSM) {
                        Text("❄️")
                            .font(.system(size: 20))
                        Text(String(localized: "+\(bonus) snowflakes"))
                            .font(AppTheme.body.weight(.semibold))
                            .foregroundStyle(DesignTokens.accentActive)
                    }
                    .padding(.horizontal, DesignTokens.spacingXL)
                    .padding(.vertical, DesignTokens.spacingMD)
                    .background(
                        Capsule()
                            .fill(DesignTokens.accentActive.opacity(0.12))
                    )
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Text(String(localized: "Let's keep going! 💪"))
                            .font(AppTheme.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.spacingMD)
                            .background(
                                Capsule()
                                    .fill(DesignTokens.accentActive)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DesignTokens.spacingXXL)
                    .padding(.bottom, DesignTokens.spacingXXXL)
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .onAppear {
            HapticService.shared.swipeDone()
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showContent = true
            }
            
            if !reduceMotion {
                withAnimation(.easeOut(duration: 2.0)) {
                    particlePhase = 1.0
                }
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
    }
    
    private func particleColor(_ index: Int) -> Color {
        let colors: [Color] = [
            DesignTokens.accentActive,
            DesignTokens.accentComplete,
            DesignTokens.accentStale,
            Color(hex: "BF5AF2"),
            Color(hex: "FF2D55"),
            Color(hex: "FFD60A")
        ]
        return colors[index % colors.count]
    }
}
