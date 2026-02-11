//
//  NudgeExpandedCard.swift
//  Nudge
//
//  Inline expansion panel — appears BELOW the compact row.
//  No duplicate header — the compact row handles identity.
//
//  Architecture:
//    • Actionable Nudgy whisper (category-aware, not motivational fluff)
//    • Category-specific action area (CALL/TEXT/EMAIL/LINK/navigate each unique)
//    • Opt-in micro-steps + snooze (progressive disclosure)
//    • Compact toolbar with 44pt touch targets (Apple HIG)
//    • Max height capped at 50% screen, scrollable overflow
//    • Delete lives ONLY in toolbar (not swipe — swipe = snooze)
//

import SwiftUI
import SafariServices

// MARK: - Expanded Card View

/// Focused inline expansion — slides below the compact row.
/// The compact row handles task identity (emoji, title, contact).
/// This card shows ONLY actionable content.
struct NudgeExpandedCard: View {
    
    let item: NudgeItem
    
    // Actions
    var onDone: (() -> Void)?
    var onSnooze: ((Date) -> Void)?
    var onDelete: (() -> Void)?
    var onCollapse: (() -> Void)?
    var onFocus: (() -> Void)?
    var onAction: (() -> Void)?
    var onContentChanged: (() -> Void)?
    
    // State
    @State private var isEditing = false
    @State private var editedContent: String = ""
    @State private var showSnoozeOptions = false
    @State private var showMicroSteps = false
    @State private var microSteps: [MicroStep] = []
    @State private var isLoadingSteps = false
    @State private var showInAppBrowser = false
    @State private var browserURL: URL?
    @State private var showDraftFull = false
    @State private var showDeleteConfirm = false
    
    // Nudgy whisper (actionable, category-aware)
    @State private var nudgyWhisper: String = ""
    @State private var isWhisperLoading = true
    
    // Completion celebration
    @State private var showDoneCelebration = false
    @State private var celebrationText: String = ""
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var accentColor: Color {
        AccentColorSystem.shared.color(for: item.accentStatus)
    }
    
    var body: some View {
        ZStack {
            // Main content with max height cap
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    
                    // ─── Nudgy whisper (actionable, category-aware) ───
                    nudgyWhisperLine
                    
                    // ─── Edit mode (inline — replaces whisper area when active) ───
                    if isEditing {
                        editArea
                    }
                    
                    // ─── Compact metadata chips ───
                    compactMeta
                    
                    divider
                    
                    // ─── Primary Action Area (category-specific) ───
                    primaryActionArea
                    
                    // ─── Micro-steps (opt-in via toolbar) ───
                    if showMicroSteps {
                        divider
                        microStepsArea
                    }
                    
                    // ─── Snooze options (opt-in via toolbar) ───
                    if showSnoozeOptions {
                        divider
                        snoozeChips
                    }
                    
                    divider
                    
                    // ─── Toolbar (44pt touch targets, Apple HIG) ───
                    toolbar
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM)
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.50)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.06), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
            
            // ─── Completion celebration overlay ───
            if showDoneCelebration {
                doneCelebrationOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        } // ZStack
        .onAppear {
            editedContent = item.content
            generateNudgyWhisper()
        }
        .sheet(isPresented: $showInAppBrowser) {
            if let url = browserURL {
                InAppBrowserView(url: url) {
                    showInAppBrowser = false
                    browserURL = nil
                }
                .ignoresSafeArea()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .alert(String(localized: "Delete this task?"), isPresented: $showDeleteConfirm) {
            Button(String(localized: "Delete"), role: .destructive) {
                onDelete?()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This can't be undone."))
        }
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
    }
    
    // MARK: - Edit Area (inline task editing)
    
    private var editArea: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            TextField(
                String(localized: "Task description"),
                text: $editedContent,
                axis: .vertical
            )
            .font(AppTheme.body.weight(.medium))
            .foregroundStyle(DesignTokens.textPrimary)
            .lineLimit(1...5)
            .textFieldStyle(.plain)
            .padding(DesignTokens.spacingSM)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(accentColor.opacity(0.3), lineWidth: 0.5)
                    )
            )
            
            HStack {
                Spacer()
                Button(String(localized: "Cancel")) {
                    isEditing = false
                    editedContent = item.content
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.textSecondary)
                .buttonStyle(.plain)
                
                Button(String(localized: "Save")) {
                    saveEdit()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentColor)
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Compact Metadata (max 4 chips — reduces scanning)
    
    private var compactMeta: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            // Priority
            if let priority = item.priority {
                metadataChip(
                    icon: priority == .high ? "flame.fill" : priority == .medium ? "equal" : "arrow.down",
                    text: priority.rawValue.capitalized,
                    color: priority == .high ? DesignTokens.accentOverdue : priority == .medium ? DesignTokens.accentStale : DesignTokens.textTertiary
                )
            }
            
            // Duration
            if let dur = item.durationLabel {
                metadataChip(icon: "clock", text: dur, color: DesignTokens.textSecondary)
            }
            
            // Due date
            if let due = item.dueDate {
                metadataChip(
                    icon: "calendar",
                    text: due.formatted(.dateTime.month(.abbreviated).day()),
                    color: due.isPast ? DesignTokens.accentOverdue : DesignTokens.textSecondary
                )
            }
            
            // Stale warning
            if item.isStale {
                metadataChip(
                    icon: "exclamationmark.triangle.fill",
                    text: String(localized: "\(item.ageInDays)d old"),
                    color: DesignTokens.accentStale
                )
            }
            
            Spacer()
        }
    }
    
    private func metadataChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8))
            Text(text).font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.10)))
    }
    
    // MARK: - Primary Action Area (category-specific mini-apps)
    
    @ViewBuilder
    private var primaryActionArea: some View {
        switch item.actionType {
        case .call:
            callCard
        case .text:
            messageCard(type: .text)
        case .email:
            messageCard(type: .email)
        case .openLink:
            linkCard
        case .navigate:
            navigateCard
        case .addToCalendar:
            calendarCard
        case .search:
            searchCard
        case nil:
            // No action type — show smart URL suggestions if any
            genericActionArea
        }
    }
    
    // MARK: ── CALL Card ──
    /// Contact card with avatar, name, duration estimate, one-tap call button.
    
    private var callCard: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            // Contact identity row
            HStack(spacing: DesignTokens.spacingMD) {
                // Avatar circle with initial
                contactAvatar(for: item.contactName, color: Color(hex: "34C759"))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.contactName ?? String(localized: "Contact"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignTokens.textPrimary)
                    
                    HStack(spacing: 6) {
                        if let dur = item.estimatedMinutes {
                            Label(String(localized: "~\(dur) min"), systemImage: "clock")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        if let target = item.actionTarget, !target.isEmpty {
                            Text(target)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(DesignTokens.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Call button — full width, prominent
            actionButton(
                icon: "phone.fill",
                label: item.contactName.map { String(localized: "Call \($0)") }
                    ?? String(localized: "Call"),
                color: Color(hex: "34C759")
            ) {
                onAction?()
            }
        }
        .padding(DesignTokens.spacingSM)
        .background(actionCardBackground(Color(hex: "34C759")))
    }
    
    // MARK: ── MESSAGE Card (Text / Email) ──
    /// Unified card for TEXT and EMAIL — shows draft if available, compose button.
    
    private func messageCard(type: ActionType) -> some View {
        let isEmail = type == .email
        let tint = isEmail ? Color(hex: "5E5CE6") : Color(hex: "007AFF")
        
        return VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            // Recipient row
            if let contact = item.contactName, !contact.isEmpty {
                HStack(spacing: DesignTokens.spacingSM) {
                    contactAvatar(for: contact, color: tint, size: 28)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(localized: "To:"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DesignTokens.textTertiary)
                        Text(contact)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignTokens.textPrimary)
                    }
                    
                    Spacer()
                    
                    // Type badge
                    Label(isEmail ? String(localized: "Email") : String(localized: "Text"), systemImage: type.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(tint.opacity(0.10)))
                }
            }
            
            // Subject line (email only)
            if isEmail, let subject = item.aiDraftSubject, !subject.isEmpty {
                HStack(spacing: 4) {
                    Text(String(localized: "Subject:"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text(subject)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineLimit(1)
                }
            }
            
            // Draft preview (if available)
            if item.hasDraft {
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text(item.aiDraft ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignTokens.textSecondary.opacity(0.8))
                        .lineLimit(showDraftFull ? nil : 4)
                        .fixedSize(horizontal: false, vertical: showDraftFull)
                    
                    HStack {
                        // Word count
                        if let draft = item.aiDraft {
                            let wordCount = draft.split(separator: " ").count
                            Text(String(localized: "\(wordCount) words"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        
                        Spacer()
                        
                        // Expand/collapse toggle
                        if (item.aiDraft?.count ?? 0) > 120 {
                            Button {
                                withAnimation(AnimationConstants.springSmooth) {
                                    showDraftFull.toggle()
                                }
                            } label: {
                                Text(showDraftFull ? String(localized: "Less") : String(localized: "More"))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(tint)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(DesignTokens.spacingSM)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(tint.opacity(0.08), lineWidth: 0.5)
                        )
                )
            }
            
            // Send / Compose button
            actionButton(
                icon: item.hasDraft ? "paperplane.fill" : "square.and.pencil",
                label: item.hasDraft
                    ? (isEmail ? String(localized: "Send Email") : String(localized: "Send Text"))
                    : (isEmail ? String(localized: "Compose Email") : String(localized: "Compose Text")),
                color: tint
            ) {
                onAction?()
            }
        }
        .padding(DesignTokens.spacingSM)
        .background(actionCardBackground(tint))
    }
    
    // MARK: ── LINK Card ──
    /// Link preview with domain, favicon-style icon, open button.
    
    private var linkCard: some View {
        let url = item.actionTarget.flatMap { URL(string: $0) }
        let domain = url?.host ?? String(localized: "link")
        let tint = Color(hex: "FF9F0A")
        
        return VStack(spacing: DesignTokens.spacingSM) {
            // Link preview row
            HStack(spacing: DesignTokens.spacingMD) {
                // Favicon-style icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "globe")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(tint)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(domain)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .lineLimit(1)
                    
                    if let target = item.actionTarget {
                        Text(target)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(DesignTokens.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                Spacer()
            }
            
            // Open button
            actionButton(
                icon: "arrow.up.right",
                label: String(localized: "Open \(domain)"),
                color: tint
            ) {
                if let url {
                    browserURL = url
                    showInAppBrowser = true
                } else {
                    onAction?()
                }
            }
            
            // Smart URL suggestions beneath
            let urls = URLActionGenerator.generateActions(
                for: item.content,
                actionType: item.actionType,
                actionTarget: item.actionTarget
            )
            if !urls.isEmpty {
                ForEach(Array(urls.prefix(2).enumerated()), id: \.offset) { _, action in
                    urlRow(action)
                }
            }
        }
        .padding(DesignTokens.spacingSM)
        .background(actionCardBackground(tint))
    }
    
    // MARK: ── NAVIGATE Card ──
    /// Location card with address, distance hint, "Open in Maps" button.
    
    private var navigateCard: some View {
        let destination = item.actionTarget ?? item.content
        let tint = Color(hex: "30D158")
        
        return VStack(spacing: DesignTokens.spacingSM) {
            // Location row
            HStack(spacing: DesignTokens.spacingMD) {
                // Map pin icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(tint)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .lineLimit(2)
                    
                    Text(String(localized: "Tap for directions"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                
                Spacer()
            }
            
            // Open in Maps button
            actionButton(
                icon: "location.fill",
                label: String(localized: "Open in Maps"),
                color: tint
            ) {
                onAction?()
            }
        }
        .padding(DesignTokens.spacingSM)
        .background(actionCardBackground(tint))
    }
    
    // MARK: ── CALENDAR Card ──
    /// Schedule card with date display, add-to-calendar button.
    
    private var calendarCard: some View {
        let tint = Color(hex: "FF453A")
        
        return VStack(spacing: DesignTokens.spacingSM) {
            // Date info row
            HStack(spacing: DesignTokens.spacingMD) {
                // Calendar icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay {
                        let displayDate = item.dueDate ?? Date()
                        VStack(spacing: 0) {
                            Text(displayDate.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(tint)
                            Text(displayDate.formatted(.dateTime.day()))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(DesignTokens.textPrimary)
                        }
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    if let due = item.dueDate {
                        Text(due.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignTokens.textPrimary)
                        
                        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
                        Text(daysUntil == 0
                            ? String(localized: "Today")
                            : daysUntil == 1
                                ? String(localized: "Tomorrow")
                                : daysUntil > 0
                                    ? String(localized: "In \(daysUntil) days")
                                    : String(localized: "\(abs(daysUntil)) days ago"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(due.isPast ? DesignTokens.accentOverdue : DesignTokens.textTertiary)
                    } else {
                        Text(String(localized: "No date set"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignTokens.textSecondary)
                        Text(String(localized: "Tap to schedule"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                
                Spacer()
            }
            
            // Add to Calendar button
            actionButton(
                icon: "calendar.badge.plus",
                label: String(localized: "Add to Calendar"),
                color: tint
            ) {
                onAction?()
            }
        }
        .padding(DesignTokens.spacingSM)
        .background(actionCardBackground(tint))
    }
    
    // MARK: ── SEARCH Card ──
    /// Search card with smart URL suggestions.
    
    private var searchCard: some View {
        let tint = DesignTokens.accentActive
        let urls = URLActionGenerator.generateActions(
            for: item.content,
            actionType: item.actionType,
            actionTarget: item.actionTarget
        )
        
        return VStack(spacing: DesignTokens.spacingSM) {
            // Search header
            HStack(spacing: DesignTokens.spacingMD) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(tint)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Search"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignTokens.textPrimary)
                    Text(String(localized: "Smart suggestions based on your task"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                
                Spacer()
            }
            
            if !urls.isEmpty {
                ForEach(Array(urls.prefix(3).enumerated()), id: \.offset) { _, action in
                    urlRow(action)
                }
            } else {
                actionButton(
                    icon: "magnifyingglass",
                    label: String(localized: "Search the Web"),
                    color: tint
                ) {
                    onAction?()
                }
            }
        }
        .padding(DesignTokens.spacingSM)
        .background(actionCardBackground(tint))
    }
    
    // MARK: ── Generic Action Area (no specific type) ──
    
    private var genericActionArea: some View {
        let urls = URLActionGenerator.generateActions(
            for: item.content,
            actionType: item.actionType,
            actionTarget: item.actionTarget
        )
        
        return Group {
            if item.hasDraft {
                // Has a draft without a specific action type — show preview + send
                draftPreview
            } else if !urls.isEmpty {
                VStack(spacing: DesignTokens.spacingXS) {
                    ForEach(Array(urls.prefix(2).enumerated()), id: \.offset) { _, action in
                        urlRow(action)
                    }
                }
            }
            // else: no action area — just whisper + metadata + toolbar
        }
    }
    
    // MARK: ── Draft Preview (generic) ──
    
    private var draftPreview: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            if let subject = item.aiDraftSubject, !subject.isEmpty {
                Text(subject)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .lineLimit(1)
            }
            
            Text(item.aiDraft ?? "")
                .font(.system(size: 13))
                .foregroundStyle(DesignTokens.textSecondary.opacity(0.8))
                .lineLimit(showDraftFull ? nil : 4)
                .fixedSize(horizontal: false, vertical: showDraftFull)
            
            if (item.aiDraft?.count ?? 0) > 120 {
                Button {
                    withAnimation(AnimationConstants.springSmooth) { showDraftFull.toggle() }
                } label: {
                    Text(showDraftFull ? String(localized: "Less") : String(localized: "More"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
            }
            
            actionButton(
                icon: "paperplane.fill",
                label: String(localized: "Review & Send"),
                color: accentColor
            ) {
                onAction?()
            }
        }
        .padding(DesignTokens.spacingSM)
        .background(actionCardBackground(accentColor))
    }
    
    // MARK: ── Shared Components ──
    
    /// Consistent contact avatar circle with initial.
    private func contactAvatar(for name: String?, color: Color, size: CGFloat = 36) -> some View {
        Circle()
            .fill(color.opacity(0.15))
            .frame(width: size, height: size)
            .overlay {
                Text(String((name ?? "?").prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(color)
            }
    }
    
    /// Consistent full-width action button.
    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            HapticService.shared.actionButtonTap()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Capsule().fill(color))
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: label,
            hint: "",
            traits: .isButton
        )
    }
    
    /// Consistent card background with subtle tint.
    private func actionCardBackground(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(color.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(color.opacity(0.08), lineWidth: 0.5)
            )
    }
    
    /// URL suggestion row.
    private func urlRow(_ action: URLAction) -> some View {
        Button {
            HapticService.shared.actionButtonTap()
            if action.openInApp {
                browserURL = action.url
                showInAppBrowser = true
            } else {
                UIApplication.shared.open(action.url)
            }
        } label: {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: action.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.accentActive)
                    .frame(width: 20)
                
                Text(action.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Spacer()
                
                Text(action.displayDomain)
                    .font(.system(size: 9))
                    .foregroundStyle(DesignTokens.textTertiary)
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(.horizontal, DesignTokens.spacingSM)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Micro-Steps Area (opt-in via toolbar ✨)
    
    private var microStepsArea: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            // Progress header
            if !microSteps.isEmpty {
                let done = microSteps.filter(\.isComplete).count
                HStack(spacing: 4) {
                    Text(String(localized: "Steps"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .textCase(.uppercase)
                    
                    Text("\(done)/\(microSteps.count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignTokens.accentActive)
                    
                    Spacer()
                    
                    Button {
                        withAnimation(AnimationConstants.springSmooth) {
                            showMicroSteps = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if isLoadingSteps {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(DesignTokens.accentActive)
                        .scaleEffect(0.7)
                    Text(String(localized: "Breaking it down…"))
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .padding(.vertical, DesignTokens.spacingSM)
            } else {
                ForEach($microSteps) { $step in
                    Button {
                        withAnimation(AnimationConstants.springSmooth) {
                            step.isComplete.toggle()
                        }
                        HapticService.shared.swipeDone()
                        checkAllComplete()
                    } label: {
                        HStack(spacing: DesignTokens.spacingSM) {
                            Image(systemName: step.isComplete ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16))
                                .foregroundStyle(step.isComplete ? DesignTokens.accentComplete : DesignTokens.textTertiary.opacity(0.4))
                            
                            StepIconView(emoji: step.emoji, size: 13)
                            
                            Text(step.content)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(step.isComplete ? DesignTokens.textTertiary : DesignTokens.textPrimary)
                                .strikethrough(step.isComplete, color: DesignTokens.textTertiary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Snooze Chips (horizontal scroll — saves vertical space)
    
    private var snoozeChips: some View {
        let cal = Calendar.current
        let now = Date()
        let tonight: Date = {
            let base = cal.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now
            return base <= now ? cal.date(byAdding: .day, value: 1, to: base) ?? base : base
        }()
        let options: [(String, String, Date)] = [
            ("2h", "clock.fill", cal.date(byAdding: .hour, value: 2, to: now)!),
            ("Tonight", "moon.fill", tonight),
            ("Tomorrow", "sunrise.fill", cal.date(byAdding: .day, value: 1, to: cal.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now)!),
            ("Next Week", "calendar", cal.date(byAdding: .day, value: 7, to: cal.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now)!)
        ]
        
        return VStack(spacing: DesignTokens.spacingSM) {
            HStack {
                Text(String(localized: "Snooze until…"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    withAnimation(AnimationConstants.springSmooth) {
                        showSnoozeOptions = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
            
            // Nudgy snooze intelligence
            if item.isStale {
                HStack(spacing: 6) {
                    Text("🐧")
                        .font(.system(size: 10))
                    Text(item.ageInDays >= 7
                        ? String(localized: "snoozed a few times… want to break it down instead?")
                        : String(localized: "been here a bit. …sometimes dropping it is okay too"))
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .italic()
                        .foregroundStyle(DesignTokens.accentStale.opacity(0.7))
                }
                .padding(.vertical, 2)
            }
            
            // Horizontal scroll chips (saves vertical space vs grid)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.spacingSM) {
                    ForEach(options, id: \.0) { label, icon, date in
                        Button {
                            HapticService.shared.actionButtonTap()
                            onSnooze?(date)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: icon)
                                    .font(.system(size: 11))
                                Text(String(localized: String.LocalizationValue(label)))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(DesignTokens.accentStale)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(DesignTokens.accentStale.opacity(0.06))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(DesignTokens.accentStale.opacity(0.15), lineWidth: 0.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    // MARK: - Toolbar (44pt touch targets — Apple HIG compliant)
    
    private var toolbar: some View {
        HStack(spacing: 0) {
            // Edit
            toolbarBtn(
                icon: "pencil",
                label: String(localized: "Edit"),
                color: isEditing ? accentColor : DesignTokens.textSecondary,
                isActive: isEditing
            ) {
                withAnimation(AnimationConstants.springSmooth) {
                    if isEditing { saveEdit() } else { isEditing = true; editedContent = item.content }
                }
            }
            
            // Break it down
            toolbarBtn(
                icon: "sparkles",
                label: String(localized: "Steps"),
                color: showMicroSteps ? DesignTokens.accentActive : DesignTokens.textSecondary,
                isActive: showMicroSteps
            ) {
                withAnimation(AnimationConstants.springSmooth) {
                    showMicroSteps.toggle()
                    if showMicroSteps && microSteps.isEmpty {
                        generateExecutionSteps()
                    }
                }
            }
            
            // Snooze
            toolbarBtn(
                icon: "moon.zzz.fill",
                label: String(localized: "Snooze"),
                color: showSnoozeOptions ? DesignTokens.accentStale : DesignTokens.textSecondary,
                isActive: showSnoozeOptions
            ) {
                withAnimation(AnimationConstants.springSmooth) {
                    showSnoozeOptions.toggle()
                }
            }
            
            // Focus timer
            toolbarBtn(
                icon: "timer",
                label: String(localized: "Focus"),
                color: DesignTokens.textSecondary,
                isActive: false
            ) {
                onFocus?()
            }
            
            // Delete (destructive — confirmation required)
            toolbarBtn(
                icon: "trash",
                label: String(localized: "Delete"),
                color: DesignTokens.textTertiary,
                isActive: false
            ) {
                showDeleteConfirm = true
            }
            
            // Done
            toolbarBtn(
                icon: "checkmark.circle.fill",
                label: String(localized: "Done"),
                color: DesignTokens.accentComplete,
                isActive: false
            ) {
                triggerDoneCelebration()
            }
        }
    }
    
    private func toolbarBtn(icon: String, label: String, color: Color, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticService.shared.actionButtonTap()
            action()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isActive ? color : DesignTokens.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44) // Apple HIG minimum touch target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: label,
            hint: "",
            traits: .isButton
        )
    }
    
    // MARK: - Helpers
    
    private func saveEdit() {
        if !editedContent.isEmpty && editedContent != item.content {
            item.content = editedContent
            item.updatedAt = Date()
            onContentChanged?()
        }
        isEditing = false
    }
    
    private func generateExecutionSteps() {
        guard microSteps.isEmpty else { return }
        isLoadingSteps = true
        Task {
            let steps = await MicroStepGenerator.generate(for: item.content, emoji: item.emoji)
            withAnimation(AnimationConstants.springSmooth) {
                microSteps = steps
                isLoadingSteps = false
            }
        }
    }
    
    private func checkAllComplete() {
        if !microSteps.isEmpty && microSteps.allSatisfy(\.isComplete) {
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                triggerDoneCelebration()
            }
        }
    }
    
    // MARK: - Nudgy Whisper (Actionable, Category-Aware)
    
    /// Category-aware, actionable whisper — NOT motivational fluff.
    /// Tells the user something USEFUL about this specific task.
    private var nudgyWhisperLine: some View {
        Group {
            if !nudgyWhisper.isEmpty {
                HStack(alignment: .top, spacing: DesignTokens.spacingSM) {
                    Text("🐧")
                        .font(.system(size: 12))
                    
                    Text(nudgyWhisper)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .italic()
                        .foregroundStyle(DesignTokens.textSecondary.opacity(0.8))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .contentTransition(.numericText())
            }
        }
        .animation(.easeOut(duration: 0.4), value: nudgyWhisper)
    }
    
    // MARK: - Done Celebration Overlay
    
    private var doneCelebrationOverlay: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.accentComplete)
                .symbolEffect(.bounce, value: showDoneCelebration)
            
            Text(celebrationText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .italic()
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                .fill(Color.black.opacity(0.85))
        }
    }
    
    // MARK: - AI Whisper Generation (Actionable, Not Motivational)
    
    /// Generates category-aware, actionable whispers.
    /// Each whisper tells the user something USEFUL, not "you got this! 💪"
    private func generateNudgyWhisper() {
        // ─── Snooze intelligence (highest priority) ───
        if item.isStale, let snoozeNote = snoozeIntelligenceNote {
            nudgyWhisper = snoozeNote
            isWhisperLoading = false
            return
        }
        
        // ─── Category-specific actionable whispers ───
        switch item.actionType {
        case .call:
            if let contact = item.contactName {
                nudgyWhisper = String(localized: "tap to call \(contact) — \(item.estimatedMinutes ?? 5) min")
            } else {
                nudgyWhisper = String(localized: "quick call — tap the button when ready")
            }
            
        case .text:
            if item.hasDraft {
                let wordCount = item.aiDraft?.split(separator: " ").count ?? 0
                nudgyWhisper = String(localized: "draft ready — \(wordCount) words. review and send 📬")
            } else if let contact = item.contactName {
                nudgyWhisper = String(localized: "text \(contact) — tap to compose")
            } else {
                nudgyWhisper = String(localized: "message ready to write — tap to start")
            }
            
        case .email:
            if item.hasDraft {
                let wordCount = item.aiDraft?.split(separator: " ").count ?? 0
                if let subject = item.aiDraftSubject, !subject.isEmpty {
                    nudgyWhisper = String(localized: "draft: \"\(subject)\" — \(wordCount) words, ready to send")
                } else {
                    nudgyWhisper = String(localized: "email draft ready — \(wordCount) words. review and send 📬")
                }
            } else {
                nudgyWhisper = String(localized: "email to write — tap to start drafting")
            }
            
        case .openLink:
            if let target = item.actionTarget, let url = URL(string: target) {
                let domain = url.host ?? "link"
                nudgyWhisper = String(localized: "opens \(domain) — tap to view")
            } else {
                nudgyWhisper = String(localized: "has a link — tap to open")
            }
            
        case .navigate:
            if let target = item.actionTarget {
                nudgyWhisper = String(localized: "navigate to \(target) — tap for Maps")
            } else {
                nudgyWhisper = String(localized: "location task — tap for directions")
            }
            
        case .addToCalendar:
            if let due = item.dueDate {
                nudgyWhisper = String(localized: "schedule for \(due.formatted(.dateTime.weekday(.wide).hour().minute()))")
            } else {
                nudgyWhisper = String(localized: "needs a time slot — tap to schedule")
            }
            
        case .search:
            nudgyWhisper = String(localized: "search task — tap to look it up")
            
        case nil:
            // No specific action type — use context-aware whispers
            generateGeneralWhisper()
            return
        }
        
        isWhisperLoading = false
        upgradeWhisperWithAI()
    }
    
    /// General whisper for tasks without a specific action type.
    /// Still actionable — based on task state, not generic motivation.
    private func generateGeneralWhisper() {
        if item.isStale && item.ageInDays >= 5 {
            nudgyWhisper = String(localized: "\(item.ageInDays) days old — break it down or drop it?")
        } else if item.isOverdue {
            nudgyWhisper = String(localized: "past due — reschedule or do it now?")
        } else if let dur = item.estimatedMinutes, dur <= 5 {
            nudgyWhisper = String(localized: "\(dur) min task — quick win")
        } else if let dur = item.estimatedMinutes, dur > 30 {
            nudgyWhisper = String(localized: "\(dur) min — might want to break this down ✨")
        } else if item.isStale {
            nudgyWhisper = String(localized: "\(item.ageInDays) days — still need this?")
        } else if let due = item.dueDate {
            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
            if daysUntil == 0 {
                nudgyWhisper = String(localized: "due today")
            } else if daysUntil == 1 {
                nudgyWhisper = String(localized: "due tomorrow")
            } else if daysUntil > 0 {
                nudgyWhisper = String(localized: "due in \(daysUntil) days")
            } else {
                nudgyWhisper = String(localized: "\(abs(daysUntil)) days overdue")
            }
        } else {
            // Last resort — still informational, not motivational
            if let dur = item.estimatedMinutes {
                nudgyWhisper = String(localized: "~\(dur) min to complete")
            } else {
                // Minimal factual whisper
                nudgyWhisper = String(localized: "added \(item.createdAt.formatted(.relative(presentation: .named)))")
            }
        }
        isWhisperLoading = false
        upgradeWhisperWithAI()
    }
    
    /// Snooze intelligence note for avoidance patterns.
    private var snoozeIntelligenceNote: String? {
        guard item.isStale else { return nil }
        let age = item.ageInDays
        if age >= 7 {
            return String(localized: "\(age) days — break it smaller or drop it?")
        } else if age >= 4 {
            return String(localized: "\(age) days old — still need this?")
        }
        return nil
    }
    
    /// Async AI upgrade — replaces curated whisper if AI responds.
    private func upgradeWhisperWithAI() {
        guard NudgyEngine.shared.isAvailable else { return }
        
        Task {
            let smart = await NudgyDialogueEngine.shared.smartTaskPresentation(
                content: item.content,
                position: 1,
                total: 1,
                isStale: item.isStale,
                isOverdue: item.isOverdue
            )
            
            if !smart.isEmpty && smart != nudgyWhisper {
                withAnimation(.easeOut(duration: 0.3)) {
                    nudgyWhisper = smart
                }
            }
        }
    }
    
    /// Trigger celebration, then call onDone.
    private func triggerDoneCelebration() {
        celebrationText = NudgyPersonality.CuratedLines.completionCelebrations.randomElement()
            ?? "done. …that took something 💙"
        
        HapticService.shared.swipeDone()
        
        withAnimation(AnimationConstants.springSmooth) {
            showDoneCelebration = true
        }
        
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            onDone?()
        }
    }
}
