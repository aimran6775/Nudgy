//
//  RoutineEditorView.swift
//  Nudge
//
//  Create or edit a routine with steps, schedule, and emoji.
//  Steps support drag-to-reorder and inline editing.
//
//  ADHD-optimized: minimal required fields, visual emoji selection,
//  quick-add steps with default emojis.
//

import SwiftUI
import SwiftData

struct RoutineEditorView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    let routine: Routine?
    
    // Form state
    @State private var name: String = ""
    @State private var emoji: String = "📋"
    @State private var schedule: RepeatSchedule = .daily
    @State private var customDays: Set<Int> = []
    @State private var startHour: Int = 8
    @State private var startMinute: Int = 0
    @State private var colorHex: String = "007AFF"
    @State private var steps: [RoutineStep] = []
    
    // UI state
    @State private var newStepContent: String = ""
    @State private var showEmojiGrid = false
    @State private var editingStepID: UUID?
    
    private let isEditing: Bool
    
    private let weekdays: [(label: String, number: Int)] = [
        ("S", 1), ("M", 2), ("T", 3), ("W", 4), ("T", 5), ("F", 6), ("S", 7)
    ]
    
    private let routineEmojis = [
        "☀️", "🌙", "💪", "🧘", "📚", "🎯", "🏃", "🍳",
        "💊", "🧹", "📝", "🎨", "🧠", "💤", "🚿", "🌿",
        "🐾", "📱", "🎵", "☕", "🥗", "🏋️", "📋", "✨"
    ]
    
    private let colorOptions: [(hex: String, name: String)] = [
        ("007AFF", "Blue"), ("30D158", "Green"), ("FF9F0A", "Amber"),
        ("FF453A", "Red"), ("BF5AF2", "Purple"), ("FF2D55", "Pink"),
        ("64D2FF", "Cyan"), ("FFD60A", "Yellow")
    ]
    
    init(routine: Routine?) {
        self.routine = routine
        self.isEditing = routine != nil
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.spacingXL) {
                    // Header: Emoji + Name
                    headerSection
                    
                    // Schedule
                    scheduleSection
                    
                    // Color
                    colorSection
                    
                    // Steps
                    stepsSection
                    
                    // Delete (editing only)
                    if isEditing {
                        deleteSection
                    }
                }
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.top, DesignTokens.spacingMD)
                .padding(.bottom, 100)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(isEditing ? String(localized: "Edit Routine") : String(localized: "New Routine"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(DesignTokens.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? String(localized: "Save") : String(localized: "Create")) {
                        saveRoutine()
                    }
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(
                        name.trimmingCharacters(in: .whitespaces).isEmpty
                            ? DesignTokens.textTertiary
                            : DesignTokens.accentActive
                    )
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { loadExistingRoutine() }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            // Emoji picker button
            Button {
                showEmojiGrid.toggle()
            } label: {
                Text(emoji)
                    .font(.system(size: 48))
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .fill(Color(hex: colorHex).opacity(0.15))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color(hex: colorHex).opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            if showEmojiGrid {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: DesignTokens.spacingSM) {
                    ForEach(routineEmojis, id: \.self) { e in
                        Button {
                            emoji = e
                            showEmojiGrid = false
                            HapticService.shared.actionButtonTap()
                        } label: {
                            Text(e)
                                .font(.system(size: 28))
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(emoji == e ? Color(hex: colorHex).opacity(0.2) : .clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DesignTokens.spacingSM)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(DesignTokens.cardSurface.opacity(0.6))
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            
            // Name field
            TextField(String(localized: "Routine name"), text: $name)
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
                .multilineTextAlignment(.center)
                .padding(DesignTokens.spacingMD)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(DesignTokens.cardSurface.opacity(0.4))
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        }
    }
    
    // MARK: - Schedule Section
    
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text(String(localized: "Schedule"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            // Schedule type pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.spacingSM) {
                    ForEach(RepeatSchedule.allCases, id: \.self) { sched in
                        Button {
                            schedule = sched
                            HapticService.shared.actionButtonTap()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: sched.icon)
                                    .font(.system(size: 11))
                                Text(sched.label)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(
                                schedule == sched ? .white : DesignTokens.textSecondary
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        schedule == sched
                                            ? Color(hex: colorHex)
                                            : DesignTokens.cardSurface.opacity(0.6)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Custom day picker
            if schedule == .custom {
                HStack(spacing: DesignTokens.spacingSM) {
                    ForEach(weekdays, id: \.number) { day in
                        Button {
                            if customDays.contains(day.number) {
                                customDays.remove(day.number)
                            } else {
                                customDays.insert(day.number)
                            }
                            HapticService.shared.actionButtonTap()
                        } label: {
                            Text(day.label)
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .foregroundStyle(
                                    customDays.contains(day.number)
                                        ? .white
                                        : DesignTokens.textSecondary
                                )
                                .background(
                                    Circle()
                                        .fill(
                                            customDays.contains(day.number)
                                                ? Color(hex: colorHex)
                                                : DesignTokens.cardSurface.opacity(0.4)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DesignTokens.spacingSM)
            }
            
            // Start time
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.textSecondary)
                
                Text(String(localized: "Start time"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                
                Spacer()
                
                DatePicker(
                    "",
                    selection: Binding(
                        get: {
                            Calendar.current.date(
                                from: DateComponents(hour: startHour, minute: startMinute)
                            ) ?? Date()
                        },
                        set: { date in
                            startHour = Calendar.current.component(.hour, from: date)
                            startMinute = Calendar.current.component(.minute, from: date)
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .colorScheme(.dark)
            }
            .padding(DesignTokens.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(DesignTokens.cardSurface.opacity(0.4))
            )
        }
    }
    
    // MARK: - Color Section
    
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text(String(localized: "Color"))
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            HStack(spacing: DesignTokens.spacingMD) {
                ForEach(colorOptions, id: \.hex) { option in
                    Button {
                        colorHex = option.hex
                        HapticService.shared.actionButtonTap()
                    } label: {
                        Circle()
                            .fill(Color(hex: option.hex))
                            .frame(width: 32, height: 32)
                            .overlay {
                                if colorHex == option.hex {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .nudgeAccessibility(
                        label: option.name,
                        traits: colorHex == option.hex ? [.isButton, .isSelected] : .isButton
                    )
                }
            }
        }
    }
    
    // MARK: - Steps Section
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            HStack {
                Text(String(localized: "Steps"))
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Spacer()
                
                if !steps.isEmpty {
                    Text(String(localized: "\(steps.count) steps"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            
            // Existing steps (drag-reorder)
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                stepRow(step: step, index: index)
            }
            .onMove { from, to in
                steps.move(fromOffsets: from, toOffset: to)
                reindexSteps()
            }
            
            // Add step
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(DesignTokens.accentActive.opacity(0.6))
                
                TextField(String(localized: "Add a step..."), text: $newStepContent)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .onSubmit {
                        addStep()
                    }
                
                if !newStepContent.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        addStep()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DesignTokens.accentActive)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignTokens.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(DesignTokens.cardSurface.opacity(0.3))
                    .strokeBorder(
                        DesignTokens.accentActive.opacity(0.15),
                        style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                    )
            )
        }
    }
    
    // MARK: - Step Row
    
    private func stepRow(step: RoutineStep, index: Int) -> some View {
        HStack(spacing: DesignTokens.spacingMD) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.textTertiary)
            
            // Step number
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: colorHex))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color(hex: colorHex).opacity(0.12))
                )
            
            // Emoji
            Text(step.emoji ?? "•")
                .font(.system(size: 16))
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(step.content)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(1)
                
                if let mins = step.estimatedMinutes, mins > 0 {
                    Text(String(localized: "\(mins) min"))
                        .font(.system(size: 10))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            
            Spacer()
            
            // Delete
            Button {
                withAnimation(AnimationConstants.springSmooth) {
                    steps.removeAll { $0.id == step.id }
                    reindexSteps()
                }
                HapticService.shared.actionButtonTap()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.spacingSM)
        .padding(.horizontal, DesignTokens.spacingXS)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                .fill(DesignTokens.cardSurface.opacity(0.3))
        )
    }
    
    // MARK: - Delete Section
    
    private var deleteSection: some View {
        Button(role: .destructive) {
            if let routine {
                modelContext.delete(routine)
                try? modelContext.save()
                HapticService.shared.actionButtonTap()
                dismiss()
            }
        } label: {
            HStack {
                Image(systemName: "trash")
                Text(String(localized: "Delete Routine"))
            }
            .font(AppTheme.body.weight(.medium))
            .foregroundStyle(DesignTokens.accentOverdue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(DesignTokens.accentOverdue.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .padding(.top, DesignTokens.spacingLG)
    }
    
    // MARK: - Actions
    
    private func loadExistingRoutine() {
        guard let routine else { return }
        name = routine.name
        emoji = routine.emoji
        schedule = routine.schedule
        customDays = Set(routine.customDays)
        startHour = routine.startHour
        startMinute = routine.startMinute
        colorHex = routine.colorHex ?? "007AFF"
        steps = routine.steps
    }
    
    private func addStep() {
        let trimmed = newStepContent.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        let step = RoutineStep(
            content: trimmed,
            emoji: guessEmoji(for: trimmed),
            sortOrder: steps.count
        )
        
        withAnimation(AnimationConstants.springSmooth) {
            steps.append(step)
        }
        
        newStepContent = ""
        HapticService.shared.actionButtonTap()
    }
    
    private func reindexSteps() {
        for i in steps.indices {
            steps[i].sortOrder = i
        }
    }
    
    private func saveRoutine() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        if let routine {
            // Update existing
            routine.name = trimmed
            routine.emoji = emoji
            routine.schedule = schedule
            routine.customDays = Array(customDays)
            routine.startHour = startHour
            routine.startMinute = startMinute
            routine.colorHex = colorHex
            routine.steps = steps
        } else {
            // Create new
            let newRoutine = Routine(
                name: trimmed,
                emoji: emoji,
                schedule: schedule,
                startHour: startHour,
                startMinute: startMinute,
                steps: steps,
                colorHex: colorHex
            )
            newRoutine.customDays = Array(customDays)
            modelContext.insert(newRoutine)
        }
        
        try? modelContext.save()
        HapticService.shared.swipeDone()
        dismiss()
    }
    
    /// Simple emoji guesser based on step keywords
    private func guessEmoji(for text: String) -> String {
        let lower = text.lowercased()
        let emojiMap: [(keywords: [String], emoji: String)] = [
            (["wake", "alarm", "get up"], "⏰"),
            (["shower", "bath", "wash"], "🚿"),
            (["brush", "teeth"], "🪥"),
            (["breakfast", "eat", "meal", "food", "lunch", "dinner"], "🍳"),
            (["coffee", "tea"], "☕"),
            (["exercise", "workout", "gym", "run", "jog"], "💪"),
            (["meditat", "mindful", "breath"], "🧘"),
            (["read", "book", "article"], "📚"),
            (["write", "journal"], "📝"),
            (["clean", "tidy", "laundry", "dishes"], "🧹"),
            (["walk", "dog", "pet"], "🐾"),
            (["meds", "medicine", "vitamin", "pill"], "💊"),
            (["stretch", "yoga"], "🧘"),
            (["water", "drink", "hydrate"], "💧"),
            (["email", "inbox"], "📧"),
            (["review", "plan", "agenda"], "📋"),
            (["skin", "face", "moistur"], "✨"),
            (["sleep", "bed", "rest"], "💤"),
            (["phone", "screen"], "📱"),
            (["music", "listen"], "🎵")
        ]
        
        for entry in emojiMap {
            if entry.keywords.contains(where: { lower.contains($0) }) {
                return entry.emoji
            }
        }
        
        return "▸"
    }
}
