//
//  CategoryPickerView.swift
//  Nudge
//
//  Lets users assign a color and icon/emoji to tasks for visual grouping.
//  Used in the task edit sheet to customize appearance.
//

import SwiftUI

struct CategoryPickerView: View {
    
    @Binding var selectedColorHex: String?
    @Binding var selectedIcon: String?
    @Binding var selectedEmoji: String?
    @Binding var selectedEnergyLevel: EnergyLevel?
    @Binding var estimatedMinutes: Int?
    
    @State private var showEmojiGrid = false
    @State private var customMinutes: Int = 15
    
    private let colorOptions: [(hex: String, name: String)] = [
        ("007AFF", "Blue"), ("30D158", "Green"), ("FF9F0A", "Amber"),
        ("FF453A", "Red"), ("BF5AF2", "Purple"), ("FF2D55", "Pink"),
        ("64D2FF", "Cyan"), ("FFD60A", "Yellow"), ("AC8E68", "Brown")
    ]
    
    private let categoryEmojis = [
        "📋", "💼", "🏠", "💪", "📚", "🎨", "🛒", "💰",
        "🧹", "📱", "🍳", "🧘", "🎯", "🧠", "❤️", "🎵",
        "🐾", "🌿", "✈️", "🎮", "📧", "📞", "🏥", "⚡"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
            // Color
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                Text(String(localized: "Color"))
                    .font(AppTheme.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                
                HStack(spacing: DesignTokens.spacingSM) {
                    // No color option
                    Button {
                        selectedColorHex = nil
                        HapticService.shared.actionButtonTap()
                    } label: {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            .frame(width: 28, height: 28)
                            .overlay {
                                if selectedColorHex == nil {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    
                    ForEach(colorOptions, id: \.hex) { option in
                        Button {
                            selectedColorHex = option.hex
                            HapticService.shared.actionButtonTap()
                        } label: {
                            Circle()
                                .fill(Color(hex: option.hex))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if selectedColorHex == option.hex {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Emoji
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                Text(String(localized: "Category"))
                    .font(AppTheme.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.spacingSM) {
                        ForEach(categoryEmojis, id: \.self) { emoji in
                            Button {
                                selectedEmoji = emoji
                                HapticService.shared.actionButtonTap()
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 22))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                selectedEmoji == emoji
                                                    ? Color.white.opacity(0.12)
                                                    : .clear
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            // Duration
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                Text(String(localized: "Duration"))
                    .font(AppTheme.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                
                HStack(spacing: DesignTokens.spacingSM) {
                    ForEach([5, 10, 15, 25, 45, 60], id: \.self) { mins in
                        Button {
                            estimatedMinutes = mins
                            HapticService.shared.actionButtonTap()
                        } label: {
                            Text(mins < 60 ? "\(mins)m" : "1h")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(
                                    estimatedMinutes == mins ? .white : DesignTokens.textSecondary
                                )
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(
                                            estimatedMinutes == mins
                                                ? DesignTokens.accentActive
                                                : DesignTokens.cardSurface.opacity(0.4)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Clear
                    if estimatedMinutes != nil {
                        Button {
                            estimatedMinutes = nil
                            HapticService.shared.actionButtonTap()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(DesignTokens.textTertiary)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Energy level
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                Text(String(localized: "Energy Required"))
                    .font(AppTheme.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                
                HStack(spacing: DesignTokens.spacingSM) {
                    ForEach(EnergyLevel.allCases, id: \.self) { energy in
                        Button {
                            selectedEnergyLevel = selectedEnergyLevel == energy ? nil : energy
                            HapticService.shared.actionButtonTap()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: energy.icon)
                                    .font(.system(size: 11))
                                Text(energy.label)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(
                                selectedEnergyLevel == energy ? .white : DesignTokens.textSecondary
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        selectedEnergyLevel == energy
                                            ? energyColor(energy)
                                            : DesignTokens.cardSurface.opacity(0.4)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private func energyColor(_ energy: EnergyLevel) -> Color {
        switch energy {
        case .low: return DesignTokens.accentStale
        case .medium: return DesignTokens.accentActive
        case .high: return DesignTokens.accentComplete
        }
    }
}
