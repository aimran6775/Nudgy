//
//  AquariumView.swift
//  Nudge
//
//  Visual fish tank showing your weekly catch collection.
//  Fish swim around, different species visible.
//  Weekly reset with "best week" tracking.
//

import SwiftUI

// MARK: - Aquarium View

struct AquariumView: View {
    
    let catches: [FishCatch]
    let level: Int
    let streak: Int
    
    @State private var animationPhase: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var weeklyCatches: [FishCatch] {
        FishEconomy.thisWeekCatches(from: catches)
    }
    
    private var speciesCounts: [FishSpecies: Int] {
        FishEconomy.weeklySpeciesCount(from: catches)
    }
    
    private var weeklyProgress: Double {
        FishEconomy.weeklyProgress(catches: catches, level: level)
    }
    
    private var weeklyGoal: Int {
        FishEconomy.weeklyGoal(level: level)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingLG) {
                // Aquarium Tank
                aquariumTank
                
                // Weekly Progress
                weeklyProgressCard
                
                // Species Collection
                speciesGrid
                
                // Recent Catches
                recentCatchesList
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.bottom, DesignTokens.spacingXXL)
        }
        .navigationTitle(String(localized: "Aquarium"))
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            if !reduceMotion {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    animationPhase = 1
                }
            }
        }
    }
    
    // MARK: - Aquarium Tank
    
    private var aquariumTank: some View {
        ZStack {
            // Water background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#001B3A"),
                            Color(hex: "#002855"),
                            Color(hex: "#001B3A")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 260)
            
            // Bubbles
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: CGFloat.random(in: 4...12))
                    .offset(
                        x: CGFloat.random(in: -140...140),
                        y: reduceMotion ? CGFloat.random(in: -100...100) : CGFloat(sin(animationPhase * .pi * 2 + Double(i) * 0.8)) * 100
                    )
            }
            
            // Swimming fish
            ForEach(Array(weeklyCatches.prefix(15).enumerated()), id: \.element.id) { index, fish in
                fishView(for: fish, index: index)
            }
            
            // Empty state
            if weeklyCatches.isEmpty {
                VStack(spacing: DesignTokens.spacingSM) {
                    Text("🐧")
                        .font(.system(size: 40))
                    Text(String(localized: "Complete tasks to fill your aquarium!"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
            
            // Glass border
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(height: 260)
        }
    }
    
    private func fishView(for fish: FishCatch, index: Int) -> some View {
        Text(fish.species.emoji)
            .font(.system(size: fish.species == .swordfish ? 28 : fish.species == .whale ? 36 : 22))
            .offset(
                x: reduceMotion
                    ? CGFloat(index * 20 - 120)
                    : CGFloat(sin(animationPhase * .pi * 2 + Double(index) * 0.5)) * 130,
                y: CGFloat(cos(animationPhase * .pi * 2 * 0.7 + Double(index) * 0.3)) * 80
            )
            .scaleEffect(x: sin(animationPhase * .pi * 2 + Double(index)) > 0 ? 1 : -1, y: 1)
    }
    
    // MARK: - Weekly Progress
    
    private var weeklyProgressCard: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            HStack {
                Text(String(localized: "This Week"))
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                Spacer()
                Text("\(weeklyCatches.count)/\(weeklyGoal)")
                    .font(AppTheme.captionBold)
                    .foregroundStyle(DesignTokens.accentActive)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [DesignTokens.accentActive, DesignTokens.accentComplete],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * weeklyProgress)
                }
            }
            .frame(height: 8)
            
            if weeklyProgress >= 1.0 {
                Text(String(localized: "🎉 Weekly goal reached! Nudgy is well-fed!"))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.accentComplete)
            }
        }
        .padding(DesignTokens.spacingMD)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
    
    // MARK: - Species Grid
    
    private var speciesGrid: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(String(localized: "Collection"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            HStack(spacing: DesignTokens.spacingSM) {
                ForEach(FishSpecies.allCases, id: \.self) { species in
                    speciesCard(species)
                }
            }
        }
    }
    
    private func speciesCard(_ species: FishSpecies) -> some View {
        let count = speciesCounts[species] ?? 0
        return VStack(spacing: DesignTokens.spacingXS) {
            Text(species.emoji)
                .font(.system(size: 32))
                .opacity(count > 0 ? 1 : 0.3)
            Text("\(count)")
                .font(AppTheme.captionBold)
                .foregroundStyle(count > 0 ? DesignTokens.textPrimary : DesignTokens.textTertiary)
            Text(species.label)
                .font(.system(size: 9))
                .foregroundStyle(DesignTokens.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.spacingSM)
        .background {
            if count > 0 {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: species.glowColorHex).opacity(0.08))
            }
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
    }
    
    // MARK: - Recent Catches
    
    private var recentCatchesList: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(String(localized: "Recent Catches"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            if weeklyCatches.isEmpty {
                Text(String(localized: "No fish caught yet this week. Complete some tasks! 🎣"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .padding(.vertical, DesignTokens.spacingMD)
            } else {
                ForEach(recentFishList) { fish in
                    HStack(spacing: DesignTokens.spacingSM) {
                        Text(fish.species.emoji)
                            .font(.system(size: 24))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(fish.taskEmoji) \(fish.taskContent)")
                                .font(AppTheme.body)
                                .foregroundStyle(DesignTokens.textPrimary)
                                .lineLimit(1)
                            Text(fish.caughtAt.formatted(.relative(presentation: .named)))
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        
                        Spacer()
                        
                        Text("+\(fish.species.snowflakeValue)❄️")
                            .font(AppTheme.captionBold)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                    .padding(.vertical, DesignTokens.spacingXS)
                }
            }
        }
    }
    
    private var recentFishList: [FishCatch] {
        Array(weeklyCatches.suffix(10).reversed())
    }
}
