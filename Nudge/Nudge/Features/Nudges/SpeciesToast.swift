//
//  SpeciesToast.swift
//  Nudge
//
//  A brief toast that reveals the fish species earned after completing a task.
//  Slides in from the top, shows species emoji + name + snowflakes, then auto-dismisses.
//  Rare catches (swordfish, whale) get extra sparkle + haptic.
//
//  Phase 8 + 10: Species toast component + rare catch celebration.
//

import SwiftUI

// MARK: - Species Toast

struct SpeciesToast: View {
    
    let species: FishSpecies
    let snowflakesEarned: Int
    let isRare: Bool
    @Binding var isPresented: Bool
    
    @State private var sparkleRotation: Double = 0
    @State private var glowPulse: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var isVeryRare: Bool {
        species == .whale
    }
    
    var body: some View {
        VStack {
            toastContent
                .padding(.top, 60)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // Haptic for rare catches
            if isRare {
                HapticService.shared.swipeDone()
                if isVeryRare {
                    // Double haptic for whale
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        HapticService.shared.swipeDone()
                    }
                }
            }
            
            // Sparkle rotation for rare
            if isRare && !reduceMotion {
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    sparkleRotation = 360
                }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }
            
            // Auto-dismiss
            let duration = species.celebrationDuration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isPresented = false
                }
            }
        }
    }
    
    private var toastContent: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            // Fish icon with species-specific glow
            ZStack {
                if isRare {
                    // Glow ring for rare catches
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: species.glowColorHex).opacity(glowPulse ? 0.3 : 0.1),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    // Rotating sparkle dots
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(Color(hex: species.glowColorHex).opacity(0.6))
                            .frame(width: 3, height: 3)
                            .offset(y: -22)
                            .rotationEffect(.degrees(sparkleRotation + Double(i) * 90))
                    }
                }
                
                FishView(
                    size: species.displaySize,
                    color: species.fishColor,
                    accentColor: species.fishAccentColor
                )
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(species.description)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isRare ? Color(hex: species.glowColorHex) : DesignTokens.textPrimary)
                
                HStack(spacing: 4) {
                    Text(species.emoji)
                        .font(.system(size: 11))
                    Text(species.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DesignTokens.textSecondary)
                    
                    Text("•")
                        .foregroundStyle(DesignTokens.textTertiary)
                    
                    Text("+\(snowflakesEarned) ❄️")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "87CEEB"))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM + 2)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                .fill(
                    isRare
                        ? Color(hex: species.glowColorHex).opacity(0.08)
                        : Color(hex: "FFD54F").opacity(0.05)
                )
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        .padding(.horizontal, DesignTokens.spacingLG)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            SpeciesToast(species: .catfish, snowflakesEarned: 1, isRare: false, isPresented: .constant(true))
            SpeciesToast(species: .swordfish, snowflakesEarned: 10, isRare: true, isPresented: .constant(true))
            SpeciesToast(species: .whale, snowflakesEarned: 15, isRare: true, isPresented: .constant(true))
        }
    }
    .preferredColorScheme(.dark)
}
