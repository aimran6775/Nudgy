//
//  ShareExtensionView.swift
//  NudgeShareExtension
//
//  Custom SwiftUI share sheet on dark background.
//  Shows content preview + snooze picker + "Save to Nudge" button.
//

import SwiftUI

struct ShareExtensionView: View {
    let content: SharedContent
    var onSave: (Date) -> Void
    var onCancel: () -> Void
    
    @State private var selectedSnoozeDate = Date().addingTimeInterval(3 * 3600) // Default: 3 hours
    @State private var showCustomPicker = false
    @State private var saved = false
    
    // Snooze presets
    private let presets: [(String, String, Date)] = [
        (String(localized: "Later today"), "clock.fill", Date().addingTimeInterval(3 * 3600)),
        (String(localized: "Tomorrow morning"), "sunrise.fill", Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date().addingTimeInterval(86400)) ?? Date()),
        (String(localized: "This weekend"), "sun.max.fill", {
            let cal = Calendar.current
            var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            comps.weekday = 7 // Saturday
            comps.hour = 10
            let date = cal.date(from: comps) ?? Date()
            return date < Date() ? cal.date(byAdding: .weekOfYear, value: 1, to: date) ?? date : date
        }()),
        (String(localized: "Next week"), "calendar", Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()) ?? Date())
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            
            if saved {
                savedConfirmation
            } else {
                shareSheet
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Share Sheet
    
    private var shareSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(String(localized: "Cancel")) {
                    onCancel()
                }
                .foregroundStyle(Color(hex: "8E8E93"))
                
                Spacer()
                
                Text(String(localized: "Save to Nudge"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Invisible spacer for centering
                Text("Cancel").opacity(0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Content Preview
            VStack(alignment: .leading, spacing: 8) {
                if let preview = content.preview, !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                
                if let url = content.url {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                        Text(URL(string: url)?.host() ?? url)
                            .font(.system(size: 13))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color(hex: "007AFF"))
                } else if !content.text.isEmpty {
                    Text(content.text)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "1C1C1E").opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(hex: "2C2C2E"), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            // Snooze section label
            Text(String(localized: "Remind me"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            // Quick presets
            VStack(spacing: 1) {
                ForEach(presets, id: \.0) { preset in
                    Button {
                        selectedSnoozeDate = preset.2
                        save()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: preset.1)
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "007AFF"))
                                .frame(width: 24)
                            
                            Text(preset.0)
                                .font(.system(size: 15))
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Text(preset.2.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "8E8E93"))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "1C1C1E").opacity(0.8))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            
            // Custom time
            Button {
                showCustomPicker.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "007AFF"))
                        .frame(width: 24)
                    
                    Text(String(localized: "Pick a time..."))
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Image(systemName: showCustomPicker ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "1C1C1E").opacity(0.8))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            if showCustomPicker {
                DatePicker(
                    "",
                    selection: $selectedSnoozeDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(Color(hex: "007AFF"))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Button {
                    save()
                } label: {
                    Text(String(localized: "Save"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "007AFF"))
                        )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Saved Confirmation
    
    private var savedConfirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color(hex: "30D158"))
            
            Text(String(localized: "Saved ✓"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            
            Text(String(localized: "We'll nudge you at the right time"))
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Actions
    
    private func save() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            saved = true
        }
        onSave(selectedSnoozeDate)
    }
}

// MARK: - Color Extension (Share Extension needs its own copy)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
