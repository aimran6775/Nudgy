//
//  InventorySheet.swift
//  Nudge
//
//  A compact pull-tab inventory sheet that glides up from the bottom.
//  Shows at-a-glance stats: altitude (level), fish count, Nudgy status,
//  streak, daily challenges, and stage evolution progress.
//
//  Designed as a small, informative drawer — not a full screen.
//  Uses native iOS 26 glass effects and presentation detents.
//

import SwiftUI

// MARK: - Inventory Sheet

struct InventorySheet: View {
    
    @Environment(PenguinState.self) private var penguinState
    
    @State private var showWardrobe = false
    
    let level: Int
    let fishCount: Int
    let streak: Int
    let levelProgress: Double
    let tasksToday: Int
    let totalCompleted: Int
    let activeCount: Int
    let stage: StageTier
    let challenges: [DailyChallenge]
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            // Stats row — the core glanceable info
            statsRow
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Nudgy status
            nudgyStatusRow
            
            // Stage evolution progress
            stageProgressRow
            
            // Daily challenges (if any active)
            if !challenges.isEmpty {
                Divider()
                    .overlay(Color.white.opacity(0.08))
                
                challengesSection
            }
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Wardrobe shortcut
            wardrobeButton
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.top, DesignTokens.spacingMD)
        .sheet(isPresented: $showWardrobe) {
            WardrobeView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(DesignTokens.cardSurface)
                .preferredColorScheme(.dark)
        }
        .background {
            ZStack {
                Color.black
                
                // Subtle aurora gradient at top
                LinearGradient(
                    colors: [
                        Color(hex: "00D4FF").opacity(0.03),
                        Color(hex: "7B61FF").opacity(0.02),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 0) {
            // Altitude
            statItem(
                icon: "mountain.2.fill",
                iconGradient: [Color(hex: "00D4FF"), Color(hex: "7B61FF")],
                label: String(localized: "Altitude"),
                value: altitudeValue,
                progress: levelProgress
            )
            
            Spacer()
            
            // Fish
            statItem(
                icon: "fish.fill",
                iconGradient: [Color(hex: "FFB800"), Color(hex: "FF8C00")],
                label: String(localized: "Fish"),
                value: "\(fishCount)",
                progress: nil
            )
            
            Spacer()
            
            // Streak
            statItem(
                icon: "flame.fill",
                iconGradient: [Color(hex: "FF6B35"), Color(hex: "FF453A")],
                label: String(localized: "Streak"),
                value: streak > 0 ? "\(streak)d" : "—",
                progress: nil
            )
            
            Spacer()
            
            // Today
            statItem(
                icon: "checkmark.circle.fill",
                iconGradient: [DesignTokens.accentComplete, DesignTokens.accentComplete.opacity(0.7)],
                label: String(localized: "Today"),
                value: "\(tasksToday)",
                progress: nil
            )
        }
    }
    
    private func statItem(icon: String, iconGradient: [Color], label: String, value: String, progress: Double?) -> some View {
        VStack(spacing: 6) {
            ZStack {
                if let progress {
                    // Progress ring
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 2.5)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: iconGradient + [iconGradient.first ?? .blue],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                }
                
                Image(systemName: icon)
                    .font(.system(size: progress != nil ? 14 : 18, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconGradient,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 40, height: 40)
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignTokens.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }
    
    // MARK: - Nudgy Status Row
    
    private var nudgyStatusRow: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            // Mini penguin expression
            LottieNudgyView(
                expression: penguinState.expression,
                size: 36,
                accentColor: penguinState.accentColor
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(nudgyStatusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Text(nudgyMoodText)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            
            Spacer()
            
            // Interaction mode badge
            if penguinState.interactionMode != .ambient {
                Text(interactionBadge)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(DesignTokens.accentActive)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(DesignTokens.accentActive.opacity(0.1))
                    )
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
    
    // MARK: - Stage Progress
    
    private var stageProgressRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Image(systemName: stageIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(stageColor)
                
                Text(stage.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(stageColor)
                
                Spacer()
                
                Text(String(localized: "Lv. \(level)"))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            
            // Progress bar to next stage
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [stageColor.opacity(0.7), stageColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * levelProgress)
                }
            }
            .frame(height: 4)
        }
        .padding(DesignTokens.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
    
    // MARK: - Challenges Section
    
    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(String(localized: "Daily Challenges"))
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(DesignTokens.textTertiary)
                .textCase(.uppercase)
                .tracking(1)
            
            ForEach(challenges) { challenge in
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: challenge.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(challenge.isCompleted ? DesignTokens.accentComplete : DesignTokens.textTertiary)
                    
                    Text(challenge.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(challenge.isCompleted ? DesignTokens.textTertiary : DesignTokens.textPrimary)
                        .strikethrough(challenge.isCompleted)
                    
                    Spacer()
                    
                    if challenge.isCompleted {
                        Text(String(localized: "+\(challenge.bonusFish)🐟"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "FFB800"))
                    }
                }
            }
        }
    }
    
    // MARK: - Wardrobe Button
    
    private var wardrobeButton: some View {
        Button {
            showWardrobe = true
        } label: {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FFD700"), Color(hex: "FF8C00")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(String(localized: "Nudgy's Wardrobe"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(DesignTokens.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
            )
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Computed Properties
    
    private var altitudeValue: String {
        let meters = level * 100
        if meters >= 1000 {
            let km = Double(meters) / 1000.0
            return String(format: "%.1fk", km)
        }
        return "\(meters)m"
    }
    
    private var nudgyStatusText: String {
        switch penguinState.expression {
        case .idle:      return String(localized: "Nudgy is chillin'")
        case .happy:     return String(localized: "Nudgy is happy!")
        case .sleeping:  return String(localized: "Nudgy is napping")
        case .thinking:  return String(localized: "Nudgy is thinking...")
        case .listening: return String(localized: "Nudgy is listening")
        case .waving:    return String(localized: "Nudgy says hi!")
        case .celebrating: return String(localized: "Nudgy is celebrating!")
        case .confused:  return String(localized: "Nudgy is pondering")
        case .nudging:   return String(localized: "Nudgy wants your attention")
        case .thumbsUp:  return String(localized: "Nudgy approves 👍")
        default:         return String(localized: "Nudgy is here")
        }
    }
    
    private var nudgyMoodText: String {
        if activeCount == 0 && tasksToday > 0 {
            return String(localized: "Everything done • \(totalCompleted) total")
        } else if activeCount == 0 {
            return String(localized: "No tasks yet • tap to unload")
        } else {
            return String(localized: "\(activeCount) active • \(totalCompleted) total completed")
        }
    }
    
    private var interactionBadge: String {
        switch penguinState.interactionMode {
        case .chatting:       return "CHATTING"
        case .listening:      return "LISTENING"
        case .processing:     return "PROCESSING"
        case .celebrating:    return "CELEBRATING"
        case .presentingTask: return "FOCUSED"
        case .greeting:       return "GREETING"
        default:              return ""
        }
    }
    
    private var stageIcon: String {
        switch stage {
        case .bareIce:     return "snowflake"
        case .snowNest:    return "house.fill"
        case .fishingPier: return "fish.fill"
        case .cozyCamp:    return "flame.fill"
        case .summitLodge: return "building.2.fill"
        }
    }
    
    private var stageColor: Color {
        switch stage {
        case .bareIce:     return Color(hex: "88CCFF")
        case .snowNest:    return Color(hex: "AAE0FF")
        case .fishingPier: return Color(hex: "FFB800")
        case .cozyCamp:    return Color(hex: "FF8C00")
        case .summitLodge: return Color(hex: "FFD700")
        }
    }
}

// MARK: - Preview

#Preview("Inventory Sheet") {
    Color.black
        .sheet(isPresented: .constant(true)) {
            InventorySheet(
                level: 7,
                fishCount: 142,
                streak: 5,
                levelProgress: 0.65,
                tasksToday: 4,
                totalCompleted: 89,
                activeCount: 3,
                stage: .fishingPier,
                challenges: []
            )
            .environment(PenguinState())
            .presentationDetents([.fraction(0.35), .medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
        }
}
