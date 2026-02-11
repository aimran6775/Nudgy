//
//  HeroCardView.swift
//  Nudge
//
//  THE single card at the top of the Nudges page.
//  This is the task Nudgy picked for you. Not a list. One card.
//
//  Adapts its CTA based on action type:
//  - Action tasks (CALL/TEXT/EMAIL/LINK) → action button + draft preview
//  - Timer tasks (has estimatedMinutes) → "Start Focus" button
//  - Generic tasks → "I did it ✓" button
//
//  Shows:
//  - Nudgy's reason for picking this task (speech bubble)
//  - Fish bounty preview (species + snowflakes + streak multiplier)
//  - Task content + metadata
//  - Primary action CTA
//  - Draft preview (if available)
//  - Swipe right → done, left → snooze
//
//  ADHD insight: The card EXECUTES tasks, not just displays them.
//  Reddit validated: "I know what to do, I just can't do it" (716 upvotes)
//

import SwiftUI

struct HeroCardView: View {
    
    let item: NudgeItem
    let reason: String
    let streak: Int
    let onDone: () -> Void
    let onSnooze: () -> Void
    let onSkip: () -> Void
    let onAction: () -> Void
    let onFocus: (() -> Void)?
    let onRegenerate: (() -> Void)?
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var cardRotation: Double = 0
    @State private var showDoneFlash = false
    @State private var appeared = false
    @State private var cardOpacity: Double = 1.0
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let swipeThreshold: CGFloat = AnimationConstants.swipeDoneThreshold
    
    private var accentColor: Color {
        AccentColorSystem.shared.color(for: item.accentStatus)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Nudgy's reason speech bubble ──
            nudgyReasonBubble
                .padding(.bottom, DesignTokens.spacingSM)
            
            // ── Main card ──
            mainCard
                .offset(x: dragOffset)
                .opacity(cardOpacity)
                .rotationEffect(.degrees(cardRotation), anchor: .bottom)
                .gesture(swipeGesture)
                .animation(
                    isDragging
                        ? nil
                        : (reduceMotion ? .easeOut(duration: 0.2) : AnimationConstants.springSmooth),
                    value: dragOffset
                )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            guard !reduceMotion else {
                appeared = true
                return
            }
            withAnimation(AnimationConstants.cardAppear.delay(0.1)) {
                appeared = true
            }
        }
    }
    
    // MARK: - Nudgy Reason Bubble
    
    private var nudgyReasonBubble: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            Image("NudgyMascot")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Text("“\(reason)”")
                .font(AppTheme.nudgyBubbleFont)
                .foregroundStyle(DesignTokens.textSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                .fill(Color.white.opacity(0.04))
        }
        .nudgeAccessibility(
            label: String(localized: "Nudgy says: \(reason)"),
            hint: nil,
            traits: .isStaticText
        )
    }
    
    // MARK: - Main Card
    
    private var mainCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            // ── Top row: Icon + Content + Bounty ──
            HStack(alignment: .top, spacing: DesignTokens.spacingMD) {
                // Task icon
                TaskIconView(
                    emoji: item.emoji,
                    actionType: item.actionType,
                    size: .large,
                    accentColor: accentColor
                )
                
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    // Task content
                    Text(item.content)
                        .font(AppTheme.headline)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    // Contact name
                    if let contact = item.contactName, !contact.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(AppTheme.caption)
                            Text(contact)
                        }
                        .font(AppTheme.footnote)
                        .foregroundStyle(DesignTokens.textSecondary)
                    }
                    
                    // Metadata row: duration + stale badge + due date
                    metadataRow
                }
                
                Spacer(minLength: 0)
            }
            
            // ── Fish bounty ──
            FishBountyLabel(item: item, streak: streak)
            
            // ── Draft preview (if available) ──
            DraftPreviewBanner(item: item, onRegenerate: onRegenerate)
            
            // ── Primary action CTA ──
            ActionCTAButton(
                item: item,
                onAction: onAction,
                onDone: onDone,
                onFocus: onFocus
            )
            
            // ── Swipe hint ──
            swipeHint
        }
        .padding(DesignTokens.spacingLG)
        .background {
            // Accent glow
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.12), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .background {
            // Done flash
            if showDoneFlash {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(DesignTokens.accentComplete.opacity(0.3))
                    .transition(.opacity)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                .strokeBorder(
                    LinearGradient(
                        colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        .shadow(color: accentColor.opacity(0.08), radius: 20, y: 8)
    }
    
    // MARK: - Metadata Row
    
    private var metadataRow: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            // Duration
            if let label = item.durationLabel {
                metadataPill(icon: "clock", text: label)
            }
            
            // Due date
            if let dueDate = item.dueDate {
                let isPast = dueDate < Date()
                metadataPill(
                    icon: isPast ? "exclamationmark.triangle.fill" : "calendar",
                    text: dueDateLabel(dueDate),
                    color: isPast ? DesignTokens.accentOverdue : nil
                )
            }
            
            // Stale badge
            if item.isStale {
                metadataPill(
                    icon: "exclamationmark.triangle.fill",
                    text: String(localized: "\(item.ageInDays)d old"),
                    color: DesignTokens.accentStale
                )
            }
            
            // Energy level
            if let energy = item.energyLevel {
                metadataPill(icon: energy.icon, text: energy.label)
            }
        }
    }
    
    private func metadataPill(icon: String, text: String, color: Color? = nil) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(AppTheme.caption)
            Text(text)
        }
        .font(AppTheme.caption)
        .foregroundStyle(color ?? DesignTokens.textTertiary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill((color ?? Color.white).opacity(0.06))
        )
    }
    
    private func dueDateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInTomorrow(date) { return String(localized: "Tomorrow") }
        if date < Date() { return String(localized: "Overdue") }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    // MARK: - Swipe Hint
    
    private var swipeHint: some View {
        HStack {
            Spacer()
            HStack(spacing: DesignTokens.spacingXL) {
                HStack(spacing: 4) {
                    Text(String(localized: "Swipe"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                    Image(systemName: "arrow.right")
                        .font(AppTheme.captionBold)
                        .foregroundStyle(DesignTokens.accentComplete.opacity(0.5))
                    Text(String(localized: "done"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.accentComplete.opacity(0.5))
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left")
                        .font(AppTheme.captionBold)
                        .foregroundStyle(DesignTokens.accentStale.opacity(0.5))
                    Text(String(localized: "snooze"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.accentStale.opacity(0.5))
                }
            }
            Spacer()
        }
        .padding(.top, DesignTokens.spacingXS)
    }
    
    // MARK: - Swipe Gesture
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                isDragging = true
                let translation = value.translation.width
                
                // Rubber-band past threshold
                if abs(translation) > swipeThreshold {
                    let excess = abs(translation) - swipeThreshold
                    let dampened = swipeThreshold + excess * 0.3
                    dragOffset = translation > 0 ? dampened : -dampened
                } else {
                    dragOffset = translation
                }
                
                // Rotation proportional to drag (capped at ±15°)
                let maxRotation = AnimationConstants.swipeDoneRotation
                cardRotation = min(max(Double(dragOffset) / 30.0, -maxRotation), maxRotation)
                
                // Opacity fade as card moves away
                let progress = min(abs(dragOffset) / (swipeThreshold * 1.5), 1.0)
                cardOpacity = 1.0 - (progress * 0.3)
                
                // Haptic at threshold
                if abs(translation) > swipeThreshold - 3 && abs(translation) < swipeThreshold + 5 {
                    HapticService.shared.prepare()
                }
            }
            .onEnded { value in
                isDragging = false
                let translation = value.translation.width
                let predictedEnd = value.predictedEndTranslation.width
                
                // Accept swipe if past threshold OR fast flick (velocity > 600)
                let isSwipeRight = translation > swipeThreshold || (translation > 40 && predictedEnd > swipeThreshold * 2)
                let isSwipeLeft = translation < -swipeThreshold || (translation < -40 && predictedEnd < -swipeThreshold * 2)
                
                let screenWidth = UIScreen.main.bounds.width
                
                if isSwipeRight {
                    // Swipe right → Done
                    withAnimation(AnimationConstants.cardSwipeDone) {
                        dragOffset = screenWidth + 100
                        cardRotation = AnimationConstants.swipeDoneRotation
                        cardOpacity = 0
                        showDoneFlash = true
                    }
                    HapticService.shared.swipeDone()
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.3))
                        onDone()
                    }
                } else if isSwipeLeft {
                    // Swipe left → Snooze
                    withAnimation(AnimationConstants.cardSwipeSnooze) {
                        dragOffset = -(screenWidth + 100)
                        cardRotation = -AnimationConstants.swipeDoneRotation
                        cardOpacity = 0
                    }
                    HapticService.shared.swipeSnooze()
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.35))
                        onSnooze()
                    }
                } else {
                    // Snap back
                    withAnimation(AnimationConstants.cardSnapBack) {
                        dragOffset = 0
                        cardRotation = 0
                        cardOpacity = 1.0
                    }
                }
            }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ScrollView {
            VStack(spacing: 32) {
                // Call task
                HeroCardView(
                    item: {
                        let item = NudgeItem(content: "Call Dr. Patel about prescription renewal", emoji: "📞", actionType: .call, actionTarget: "555-1234", contactName: "Dr. Patel", sortOrder: 1)
                        item.aiDraft = "Ask about prescription renewal\nConfirm next appointment\nMention side effects"
                        item.estimatedMinutes = 10
                        return item
                    }(),
                    reason: "this one's been waiting 4 days…",
                    streak: 5,
                    onDone: {},
                    onSnooze: {},
                    onSkip: {},
                    onAction: {},
                    onFocus: {},
                    onRegenerate: {}
                )
                
                // Generic task
                HeroCardView(
                    item: NudgeItem(content: "Do laundry", emoji: "👕", sortOrder: 2),
                    reason: "a quick one to get you going",
                    streak: 1,
                    onDone: {},
                    onSnooze: {},
                    onSkip: {},
                    onAction: {},
                    onFocus: nil,
                    onRegenerate: nil
                )
            }
            .padding()
        }
    }
    .preferredColorScheme(.dark)
}
