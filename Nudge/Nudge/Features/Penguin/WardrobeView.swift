//
//  WardrobeView.swift
//  Nudge
//
//  Accessory shop & equip screen.
//  Browse unlocked and locked accessories, spend snowflakes to unlock,
//  and equip items on Nudgy with instant preview.
//
//  Presented as a sheet from the penguin's home screen.
//

import SwiftUI
import SwiftData

struct WardrobeView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(PenguinState.self) private var penguinState
    
    @State private var rewardService = RewardService.shared
    @State private var selectedAccessory: String?
    @State private var showUnlockConfirm = false
    @State private var unlockResult: UnlockResult?
    @State private var showCelebration = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.spacingXL) {
                    // Header — Nudgy preview with equipped accessories
                    nudgyPreview
                    
                    // Stats bar
                    statsBar
                    
                    // Accessory grid by tier
                    ForEach(1...4, id: \.self) { tier in
                        tierSection(tier)
                    }
                }
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.bottom, DesignTokens.spacingXXXL)
            }
            .background(DesignTokens.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "Nudgy's Wardrobe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                    .foregroundStyle(DesignTokens.accentActive)
                }
            }
            .preferredColorScheme(.dark)
        }
        .confirmationDialog(
            unlockDialogTitle,
            isPresented: $showUnlockConfirm,
            titleVisibility: .visible
        ) {
            if let id = selectedAccessory {
                let cost = AccessoryCatalog.cost(for: id)
                Button(String(localized: "Unlock for \(cost) ❄️")) {
                    performUnlock(id)
                }
                Button(String(localized: "Cancel"), role: .cancel) {}
            }
        }
    }
    
    // MARK: - Nudgy Preview
    
    private var nudgyPreview: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            NudgySprite(
                expression: showCelebration ? .celebrating : .idle,
                size: 160,
                accentColor: DesignTokens.accentActive,
                equippedAccessories: rewardService.equippedAccessories,
                useSpriteArt: false
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: rewardService.equippedAccessories)
            
            Text(String(localized: "Nudgy"))
                .font(AppTheme.nudgyNameFont)
                .foregroundStyle(DesignTokens.textTertiary.opacity(0.5))
                .textCase(.uppercase)
                .tracking(2.0)
        }
        .padding(.top, DesignTokens.spacingMD)
    }
    
    // MARK: - Stats Bar
    
    private var statsBar: some View {
        HStack(spacing: DesignTokens.spacingXL) {
            // Snowflakes
            statBadge(
                icon: "❄️",
                value: "\(rewardService.snowflakes)",
                label: String(localized: "Snowflakes")
            )
            
            // Level
            statBadge(
                icon: "⭐",
                value: String(localized: "Lv.\(rewardService.level)"),
                label: String(localized: "Level")
            )
            
            // Streak
            statBadge(
                icon: "🔥",
                value: "\(rewardService.currentStreak)",
                label: String(localized: "Day Streak")
            )
        }
        .padding(DesignTokens.spacingMD)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                .fill(DesignTokens.cardSurface.opacity(DesignTokens.cardOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .strokeBorder(DesignTokens.accentActive.opacity(0.2), lineWidth: DesignTokens.cardBorderWidth)
                )
        )
    }
    
    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 22))
            Text(value)
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            Text(label)
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Tier Section
    
    private func tierSection(_ tier: Int) -> some View {
        let items = AccessoryCatalog.all.filter { AccessoryCatalog.tier(for: $0.id) == tier }
        guard !items.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                // Tier header
                HStack {
                    Text(tierTitle(tier))
                        .font(AppTheme.headline)
                        .foregroundStyle(DesignTokens.textPrimary)
                    
                    Spacer()
                    
                    Text(tierCost(tier))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                
                // Item grid
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: DesignTokens.spacingMD
                ) {
                    ForEach(items) { item in
                        accessoryCell(item)
                    }
                }
            }
        )
    }
    
    private func tierTitle(_ tier: Int) -> String {
        switch tier {
        case 1: return String(localized: "Starter")
        case 2: return String(localized: "Explorer")
        case 3: return String(localized: "Achiever")
        case 4: return String(localized: "Legendary")
        default: return ""
        }
    }
    
    private func tierCost(_ tier: Int) -> String {
        switch tier {
        case 1: return String(localized: "5 ❄️ each")
        case 2: return String(localized: "15 ❄️ each")
        case 3: return String(localized: "30 ❄️ each")
        case 4: return String(localized: "50 ❄️ each")
        default: return ""
        }
    }
    
    // MARK: - Accessory Cell
    
    private func accessoryCell(_ item: NudgyAccessoryItem) -> some View {
        let isUnlocked = rewardService.unlockedAccessories.contains(item.id)
        let isEquipped = rewardService.equippedAccessories.contains(item.id)
        let canAfford = rewardService.snowflakes >= AccessoryCatalog.cost(for: item.id)
        
        return Button {
            HapticService.shared.prepare()
            
            if isUnlocked {
                // Toggle equip
                rewardService.toggleEquip(accessoryID: item.id, context: modelContext)
                HapticService.shared.prepare()
            } else {
                // Attempt unlock
                selectedAccessory = item.id
                showUnlockConfirm = true
            }
        } label: {
            VStack(spacing: DesignTokens.spacingSM) {
                // Emoji/icon
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                        .fill(
                            isEquipped
                                ? DesignTokens.accentActive.opacity(0.2)
                                : DesignTokens.cardSurface.opacity(0.6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                                .strokeBorder(
                                    isEquipped
                                        ? DesignTokens.accentActive.opacity(0.6)
                                        : DesignTokens.cardBorder.opacity(0.3),
                                    lineWidth: isEquipped ? 1.5 : 0.5
                                )
                        )
                    
                    if isUnlocked {
                        Text(AccessoryCatalog.emoji(for: item.id))
                            .font(.system(size: 32))
                    } else {
                        VStack(spacing: 2) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(
                                    canAfford
                                        ? DesignTokens.accentActive
                                        : DesignTokens.textTertiary
                                )
                            Text("\(AccessoryCatalog.cost(for: item.id))❄️")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                    }
                }
                .frame(height: 70)
                
                // Name
                Text(AccessoryCatalog.displayName(for: item.id))
                    .font(AppTheme.caption)
                    .foregroundStyle(
                        isUnlocked
                            ? DesignTokens.textSecondary
                            : DesignTokens.textTertiary
                    )
                    .lineLimit(1)
                
                // Equipped badge
                if isEquipped {
                    Text(String(localized: "Wearing"))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DesignTokens.accentActive)
                        .textCase(.uppercase)
                }
            }
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: AccessoryCatalog.displayName(for: item.id),
            hint: isUnlocked
                ? (isEquipped
                    ? String(localized: "Tap to unequip")
                    : String(localized: "Tap to equip"))
                : String(localized: "Locked. Costs \(AccessoryCatalog.cost(for: item.id)) snowflakes to unlock"),
            traits: .isButton
        )
    }
    
    // MARK: - Unlock
    
    private var unlockDialogTitle: String {
        guard let id = selectedAccessory else { return "" }
        return String(localized: "Unlock \(AccessoryCatalog.displayName(for: id))?")
    }
    
    private func performUnlock(_ accessoryID: String) {
        let result = rewardService.unlock(accessoryID: accessoryID, context: modelContext)
        unlockResult = result
        
        if case .success = result {
            HapticService.shared.prepare()
            
            // Auto-equip newly unlocked item
            rewardService.toggleEquip(accessoryID: accessoryID, context: modelContext)
            
            // Celebrate
            showCelebration = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                showCelebration = false
            }
        }
    }
}

// MARK: - Preview

#Preview("Wardrobe") {
    let penguinState = PenguinState()
    
    WardrobeView()
        .environment(penguinState)
}
