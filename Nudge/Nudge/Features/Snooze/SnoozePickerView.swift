//
//  SnoozePickerView.swift
//  Nudge
//
//  Time picker overlay — quick presets + custom date/time.
//  Appears when swiping left on a card or from context menu.
//

import SwiftUI

struct SnoozePickerView: View {
    
    let item: NudgeItem
    var onSnooze: (Date) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var customDate = Date.tomorrowMorning
    @State private var showCustomPicker = false
    
    // MARK: - Snooze Options
    
    /// Computed presets that respect quiet hours.
    /// If "Later today" would land during quiet hours, it's replaced with "After quiet hours."
    private var presets: [(label: String, icon: String, date: Date)] {
        var results: [(label: String, icon: String, date: Date)] = []
        
        let laterToday = Date.laterToday
        if settings.isDateInQuietHours(laterToday) {
            // Push to when quiet hours end instead
            let afterQuiet = settings.nextQuietHoursEnd()
            results.append((String(localized: "After quiet hours"), "moon.zzz", afterQuiet))
        } else {
            results.append((String(localized: "Later today"), "clock", laterToday))
        }
        
        results.append((String(localized: "Tomorrow morning"), "sunrise", Date.tomorrowMorning))
        results.append((String(localized: "This weekend"), "sun.max", Date.thisWeekend))
        results.append((String(localized: "Next week"), "calendar", Date.nextWeek))
        
        return results
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.cardSurface.ignoresSafeArea()
                
                VStack(spacing: DesignTokens.spacingLG) {
                    // Task preview
                    HStack(spacing: DesignTokens.spacingSM) {
                        TaskIconView(emoji: item.emoji, actionType: item.actionType, size: .small)
                        Text(item.content)
                            .font(AppTheme.body)
                            .foregroundStyle(DesignTokens.textPrimary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(DesignTokens.spacingMD)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                            .fill(Color.white.opacity(0.05))
                    )
                    
                    // Quick presets
                    VStack(spacing: DesignTokens.spacingSM) {
                        ForEach(presets, id: \.label) { preset in
                            presetButton(preset)
                        }
                    }
                    
                    // Custom time
                    Divider()
                        .background(DesignTokens.cardBorder)
                    
                    if showCustomPicker {
                        DatePicker(
                            String(localized: "Pick a time"),
                            selection: $customDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                        .tint(DesignTokens.accentActive)
                        .colorScheme(.dark)
                        
                        Button {
                            HapticService.shared.snoozeTimeSelected()
                            onSnooze(customDate)
                        } label: {
                            HStack {
                                Image(systemName: "clock.badge.checkmark")
                                Text(String(localized: "Snooze until \(customDate.friendlySnoozeDescription)"))
                            }
                            .font(AppTheme.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.spacingMD)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                                    .fill(DesignTokens.accentActive)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            withAnimation(AnimationConstants.sheetPresent) {
                                showCustomPicker = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundStyle(DesignTokens.accentActive)
                                Text(String(localized: "Custom time..."))
                                    .foregroundStyle(DesignTokens.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(DesignTokens.textTertiary)
                            }
                            .font(AppTheme.body)
                            .padding(DesignTokens.spacingMD)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                                    .fill(Color.white.opacity(0.05))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                }
                .padding(DesignTokens.spacingXL)
            }
            .navigationTitle(String(localized: "Snooze"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Preset Button
    
    private func presetButton(_ preset: (label: String, icon: String, date: Date)) -> some View {
        Button {
            HapticService.shared.snoozeTimeSelected()
            onSnooze(preset.date)
        } label: {
            HStack(spacing: DesignTokens.spacingMD) {
                Image(systemName: preset.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(DesignTokens.accentActive)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.label)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                    
                    Text(preset.date.friendlySnoozeDescription)
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                
                Spacer()
            }
            .padding(DesignTokens.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: "\(preset.label), \(preset.date.friendlySnoozeDescription)",
            traits: .isButton
        )
    }
}

// MARK: - Identifiable Conformance for sheet(item:)

// NudgeItem is already Identifiable via its id: UUID property from @Model

// MARK: - Preview

#Preview {
    SnoozePickerView(
        item: NudgeItem(content: "Call the dentist", emoji: "📞"),
        onSnooze: { date in print("Snoozed until \(date)") }
    )
    .environment(AppSettings())
}
