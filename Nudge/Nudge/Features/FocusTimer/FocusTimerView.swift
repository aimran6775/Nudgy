//
//  FocusTimerView.swift
//  Nudge
//
//  A calming countdown timer that anchors you in the current task.
//  Shows a circular progress ring, Nudgy's expression, micro-steps
//  as a checklist, and gentle encouragement at intervals.
//
//  Directly combats ADHD time-agnosia by making time visible.
//

import SwiftUI
import SwiftData

// MARK: - Focus Timer State

@Observable
final class FocusTimerState {
    var totalSeconds: Int = 0
    var remainingSeconds: Int = 0
    var isRunning: Bool = false
    var isPaused: Bool = false
    var completedSteps: Set<UUID> = []
    
    /// 0.0–1.0 progress (elapsed / total)
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }
    
    var elapsedSeconds: Int { totalSeconds - remainingSeconds }
    
    var formattedRemaining: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    var formattedElapsed: String {
        let mins = elapsedSeconds / 60
        let secs = elapsedSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    var isComplete: Bool { remainingSeconds <= 0 && totalSeconds > 0 }
}

// MARK: - Focus Timer View

struct FocusTimerView: View {
    
    let item: NudgeItem
    @Binding var isPresented: Bool
    
    @Environment(PenguinState.self) private var penguinState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var timer = FocusTimerState()
    @State private var tickTimer: Timer?
    @State private var customMinutes: Int = 25
    @State private var showCustomPicker = false
    @State private var encouragementText: String = ""
    @State private var showEncouragement = false
    @State private var lastEncouragementTime: Int = 0
    
    // Preset durations
    private let presets: [(label: String, minutes: Int)] = [
        ("5 min", 5),
        ("15 min", 15),
        ("25 min", 25),
        ("45 min", 45)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                // Subtle radial glow based on progress
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [progressColor.opacity(0.06), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .blur(radius: 40)
                
                VStack(spacing: 0) {
                    if !timer.isRunning && !timer.isPaused {
                        setupView
                    } else {
                        activeTimerView
                    }
                }
            }
            .navigationTitle(timer.isRunning || timer.isPaused ? "" : String(localized: "Focus Timer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(timer.isRunning ? String(localized: "End") : String(localized: "Close")) {
                        endSession()
                    }
                    .foregroundStyle(DesignTokens.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Setup View (Before Timer Starts)
    
    private var setupView: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            Spacer()
            
            // Task info
            VStack(spacing: DesignTokens.spacingSM) {
                TaskIconView(emoji: item.emoji, actionType: item.actionType, size: .large, accentColor: DesignTokens.accentActive)
                
                Text(item.content)
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, DesignTokens.spacingXXL)
                
                if let duration = item.durationLabel {
                    Text(String(localized: "Estimated: \(duration)"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            
            Spacer()
            
            // Duration presets
            VStack(spacing: DesignTokens.spacingMD) {
                Text(String(localized: "How long do you want to focus?"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                
                HStack(spacing: DesignTokens.spacingSM) {
                    ForEach(presets, id: \.minutes) { preset in
                        Button {
                            startTimer(minutes: preset.minutes)
                        } label: {
                            Text(preset.label)
                                .font(AppTheme.body.weight(.semibold))
                                .foregroundStyle(DesignTokens.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignTokens.spacingMD)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                                        .fill(DesignTokens.accentActive.opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                                                .strokeBorder(DesignTokens.accentActive.opacity(0.3), lineWidth: 0.5)
                                        )
                                )
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.spacingLG)
                
                // Custom time
                Button {
                    showCustomPicker.toggle()
                } label: {
                    Text(String(localized: "Custom time"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.accentActive)
                }
                
                if showCustomPicker {
                    HStack(spacing: DesignTokens.spacingMD) {
                        Stepper(
                            "\(customMinutes) min",
                            value: $customMinutes,
                            in: 1...120,
                            step: 5
                        )
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                        
                        Button(String(localized: "Start")) {
                            startTimer(minutes: customMinutes)
                        }
                        .font(AppTheme.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.accentActive)
                    }
                    .padding(.horizontal, DesignTokens.spacingXXL)
                    .transition(.opacity)
                }
                
                // Use AI estimate if available
                if let estimate = item.estimatedMinutes {
                    Button {
                        startTimer(minutes: estimate)
                    } label: {
                        HStack(spacing: DesignTokens.spacingXS) {
                            Image(systemName: "sparkles")
                            Text(String(localized: "Use AI estimate: \(estimate) min"))
                        }
                        .font(AppTheme.body.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignTokens.spacingXL)
                        .padding(.vertical, DesignTokens.spacingMD)
                        .background(
                            Capsule()
                                .fill(DesignTokens.accentActive.opacity(0.25))
                        )
                    }
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Active Timer View
    
    private var activeTimerView: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            Spacer()
            
            // Circular progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 8)
                    .frame(width: 240, height: 240)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(
                        progressGradient,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? .none : .easeOut(duration: 0.3), value: timer.progress)
                
                // Center content
                VStack(spacing: DesignTokens.spacingXS) {
                    Text(timer.formattedRemaining)
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    
                    TaskIconView(emoji: item.emoji, actionType: item.actionType, size: .medium, accentColor: DesignTokens.accentActive)
                    
                    Text(item.content)
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 160)
                }
            }
            
            // Encouragement (fades in periodically)
            if showEncouragement {
                Text(encouragementText)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textTertiary)
                    .transition(.opacity)
                    .padding(.horizontal, DesignTokens.spacingXXL)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: DesignTokens.spacingXXL) {
                // Reset
                Button {
                    resetTimer()
                } label: {
                    VStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20))
                        Text(String(localized: "Reset"))
                            .font(AppTheme.caption)
                    }
                    .foregroundStyle(DesignTokens.textTertiary)
                }
                
                // Play/Pause
                Button {
                    togglePause()
                } label: {
                    Circle()
                        .fill(DesignTokens.accentActive)
                        .frame(width: 72, height: 72)
                        .overlay {
                            Image(systemName: timer.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                        }
                }
                
                // Done (complete task)
                Button {
                    completeTask()
                } label: {
                    VStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20))
                        Text(String(localized: "Done"))
                            .font(AppTheme.caption)
                    }
                    .foregroundStyle(DesignTokens.accentComplete)
                }
            }
            .padding(.bottom, DesignTokens.spacingXXXL)
        }
    }
    
    // MARK: - Progress Color
    
    private var progressColor: Color {
        if timer.progress < 0.5 {
            return DesignTokens.accentActive
        } else if timer.progress < 0.85 {
            return DesignTokens.accentStale
        } else {
            return DesignTokens.accentComplete
        }
    }
    
    private var progressGradient: AngularGradient {
        AngularGradient(
            colors: [DesignTokens.accentActive, progressColor],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * timer.progress)
        )
    }
    
    // MARK: - Timer Logic
    
    private func startTimer(minutes: Int) {
        timer.totalSeconds = minutes * 60
        timer.remainingSeconds = minutes * 60
        timer.isRunning = true
        timer.isPaused = false
        lastEncouragementTime = 0
        
        HapticService.shared.micStart()
        
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard timer.isRunning, !timer.isPaused else { return }
            
            if timer.remainingSeconds > 0 {
                timer.remainingSeconds -= 1
                checkEncouragement()
            } else {
                timerComplete()
            }
        }
    }
    
    private func togglePause() {
        timer.isPaused.toggle()
        HapticService.shared.snoozeTimeSelected()
    }
    
    private func resetTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
        timer.isRunning = false
        timer.isPaused = false
        timer.remainingSeconds = 0
        timer.totalSeconds = 0
        showEncouragement = false
    }
    
    private func endSession() {
        // Record actual time spent
        if timer.isRunning || timer.isPaused {
            let elapsed = timer.elapsedSeconds
            if elapsed > 30 { // Only record if > 30 seconds
                item.actualMinutes = (item.actualMinutes ?? 0) + (elapsed / 60)
                item.updatedAt = Date()
                try? modelContext.save()
            }
        }
        
        tickTimer?.invalidate()
        tickTimer = nil
        isPresented = false
    }
    
    private func timerComplete() {
        tickTimer?.invalidate()
        tickTimer = nil
        timer.isRunning = false
        
        HapticService.shared.swipeDone()
        SoundService.shared.play(.allClear)
        
        // Record actual time
        item.actualMinutes = (item.actualMinutes ?? 0) + (timer.totalSeconds / 60)
        item.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func completeTask() {
        // Record time and mark done
        if timer.isRunning || timer.isPaused {
            let elapsed = timer.elapsedSeconds
            item.actualMinutes = (item.actualMinutes ?? 0) + max(1, elapsed / 60)
        }
        
        let repo = NudgeRepository(modelContext: modelContext)
        repo.markDone(item)
        
        // Reward
        let isAllClear = repo.activeCount() == 0
        RewardService.shared.recordCompletion(context: modelContext, item: item, isAllClear: isAllClear)
        
        HapticService.shared.swipeDone()
        SoundService.shared.play(.taskDone)
        
        tickTimer?.invalidate()
        tickTimer = nil
        isPresented = false
    }
    
    // MARK: - Encouragement
    
    private let encouragements: [String] = [
        String(localized: "You're doing great, keep going! 🐧"),
        String(localized: "One thing at a time. You've got this."),
        String(localized: "Focus looks good on you ✨"),
        String(localized: "Almost there, stay with it!"),
        String(localized: "Your future self is going to thank you."),
        String(localized: "Breathe. You're exactly where you need to be."),
        String(localized: "Small progress is still progress 💪"),
        String(localized: "The hardest part was starting. Look at you go!"),
    ]
    
    private func checkEncouragement() {
        let elapsed = timer.elapsedSeconds
        // Show encouragement every 5 minutes
        let interval = 300
        
        if elapsed > 0 && elapsed % interval == 0 && elapsed != lastEncouragementTime {
            lastEncouragementTime = elapsed
            encouragementText = encouragements.randomElement() ?? ""
            
            withAnimation(.easeOut(duration: 0.5)) {
                showEncouragement = true
            }
            
            // Hide after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showEncouragement = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var presented = true
    let item = NudgeItem(content: "Call the dentist", emoji: "📞", estimatedMinutes: 15)
    FocusTimerView(item: item, isPresented: $presented)
        .environment(PenguinState())
}
