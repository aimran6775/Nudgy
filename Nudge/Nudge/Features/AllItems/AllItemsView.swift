//
//  AllItemsView.swift
//  Nudge
//
//  The "escape hatch" — scrollable list of all items grouped by status.
//  Sections: Up Next (active), Snoozed, Done Today.
//  Supports long-press context menu + swipe actions.
//

import SwiftUI
import SwiftData
import TipKit

struct AllItemsView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(PenguinState.self) private var penguinState
    
    @State private var repository: NudgeRepository?
    @State private var activeItems: [NudgeItem] = []
    @State private var snoozedItems: [NudgeItem] = []
    @State private var doneItems: [NudgeItem] = []
    @State private var editingItem: NudgeItem?
    @State private var showEditSheet = false
    @State private var showSnoozeFor: NudgeItem?
    
    // Tips
    private let shareTip = ShareTip()
    
    // Undo state
    @State private var undoItem: NudgeItem?
    @State private var undoPreviousSortOrder: Int = 0
    @State private var showUndoToast = false
    @State private var undoTimerTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if activeItems.isEmpty && snoozedItems.isEmpty && doneItems.isEmpty {
                emptyView
            } else {
                VStack(spacing: 0) {
                    TipView(shareTip)
                        .tipBackground(DesignTokens.cardSurface)
                        .padding(.horizontal, DesignTokens.spacingLG)
                        .padding(.top, DesignTokens.spacingSM)
                    
                    listContent
                }
            }
            
            // Undo toast overlay
            if showUndoToast {
                undoToastView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            setupRepository()
            refreshData()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            repository?.resurfaceExpiredSnoozes()
            refreshData()
        }
        .sheet(item: $editingItem) { item in
            ItemEditSheet(item: item) {
                refreshData()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(DesignTokens.cardSurface)
        }
        .sheet(item: $showSnoozeFor) { item in
            SnoozePickerView(item: item) { date in
                repository?.snooze(item, until: date)
                showSnoozeFor = nil
                refreshData()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(DesignTokens.cardSurface)
        }
    }
    
    // MARK: - List Content
    
    private var listContent: some View {
        List {
            // Up Next section
            if !activeItems.isEmpty {
                Section {
                    ForEach(activeItems, id: \.id) { item in
                        ItemRowView(item: item) {
                            editingItem = item
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .swipeActions(edge: .trailing) {
                            Button {
                                markDoneWithUndo(item)
                            } label: {
                                Label(String(localized: "Done"), systemImage: "checkmark")
                            }
                            .tint(DesignTokens.accentComplete)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                showSnoozeFor = item
                            } label: {
                                Label(String(localized: "Snooze"), systemImage: "clock")
                            }
                            .tint(DesignTokens.accentStale)
                        }
                        .contextMenu { contextMenu(for: item) }
                    }
                } header: {
                    sectionHeader(
                        title: String(localized: "Up Next"),
                        count: activeItems.count,
                        color: DesignTokens.accentActive
                    )
                }
            }
            
            // Snoozed section
            if !snoozedItems.isEmpty {
                Section {
                    ForEach(snoozedItems, id: \.id) { item in
                        ItemRowView(item: item) {
                            editingItem = item
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .contextMenu { contextMenu(for: item) }
                    }
                } header: {
                    sectionHeader(
                        title: String(localized: "Snoozed"),
                        count: snoozedItems.count,
                        color: DesignTokens.textSecondary
                    )
                }
            }
            
            // Done Today section
            if !doneItems.isEmpty {
                Section {
                    ForEach(doneItems, id: \.id) { item in
                        ItemRowView(item: item) {
                            editingItem = item
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .contextMenu { contextMenu(for: item) }
                    }
                } header: {
                    sectionHeader(
                        title: String(localized: "Done Today"),
                        count: doneItems.count,
                        color: DesignTokens.accentComplete
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { refreshData() }
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(title: String, count: Int, color: Color) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.headline)
                .foregroundStyle(DesignTokens.textPrimary)
            
            Text("\(count)")
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(color.opacity(0.15))
                )
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(count) \(count == 1 ? String(localized: "item") : String(localized: "items"))")
        .padding(.vertical, DesignTokens.spacingSM)
        .padding(.horizontal, DesignTokens.spacingXS)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func contextMenu(for item: NudgeItem) -> some View {
        if item.status != .done {
            Button {
                markDoneWithUndo(item)
            } label: {
                Label(String(localized: "Mark Done"), systemImage: "checkmark.circle")
            }
        }
        
        if item.status == .active {
            Button {
                showSnoozeFor = item
            } label: {
                Label(String(localized: "Snooze"), systemImage: "clock")
            }
            
            Button {
                repository?.skip(item)
                refreshData()
            } label: {
                Label(String(localized: "Move to Bottom"), systemImage: "arrow.down.to.line")
            }
        }
        
        if item.status == .snoozed {
            Button {
                repository?.resurfaceItem(item)
                refreshData()
            } label: {
                Label(String(localized: "Bring Back Now"), systemImage: "arrow.uturn.left")
            }
        }
        
        Divider()
        
        Button(role: .destructive) {
            repository?.delete(item)
            refreshData()
        } label: {
            Label(String(localized: "Delete"), systemImage: "trash")
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            // Nudgy is resting — he tells you it's empty
            PenguinSceneView(
                size: .large,
                expressionOverride: .sleeping,
                accentColorOverride: DesignTokens.textTertiary
            )
            .onAppear {
                penguinState.expression = .sleeping
                penguinState.say(
                    String(localized: "Nothing here yet!\nTap the mic to get started."),
                    style: .whisper,
                    autoDismiss: 6.0
                )
            }
            
            Button {
                NotificationCenter.default.post(name: .nudgeOpenBrainDump, object: nil)
            } label: {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "mic.fill")
                    Text(String(localized: "Start a Brain Dump"))
                }
                .font(AppTheme.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, DesignTokens.spacingXL)
                .padding(.vertical, DesignTokens.spacingMD)
                .background(
                    Capsule()
                        .fill(DesignTokens.accentActive)
                )
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(
                label: String(localized: "Start a brain dump"),
                hint: String(localized: "Opens the voice brain dump recorder"),
                traits: .isButton
            )
            
            Button {
                NotificationCenter.default.post(name: .nudgeOpenQuickAdd, object: nil)
            } label: {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "plus")
                    Text(String(localized: "Type a Task"))
                }
                .font(AppTheme.body.weight(.medium))
                .foregroundStyle(DesignTokens.accentActive)
                .padding(.horizontal, DesignTokens.spacingXL)
                .padding(.vertical, DesignTokens.spacingMD)
                .background(
                    Capsule()
                        .strokeBorder(DesignTokens.accentActive, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(
                label: String(localized: "Type a task"),
                hint: String(localized: "Opens a text field to add a task manually"),
                traits: .isButton
            )
        }
    }
    
    // MARK: - Undo
    
    private func markDoneWithUndo(_ item: NudgeItem) {
        // Stash sort order for undo
        undoPreviousSortOrder = item.sortOrder
        
        repository?.markDone(item)
        HapticService.shared.swipeDone()
        
        // Show undo toast
        undoItem = item
        undoTimerTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showUndoToast = true
        }
        undoTimerTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            dismissUndoToast()
        }
        
        refreshData()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
    }
    
    private func undoLastDone() {
        guard let item = undoItem else { return }
        repository?.undoDone(item, restoreSortOrder: undoPreviousSortOrder)
        
        undoTimerTask?.cancel()
        dismissUndoToast()
        
        HapticService.shared.prepare()
        refreshData()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
    }
    
    private func dismissUndoToast() {
        withAnimation(.easeOut(duration: 0.25)) {
            showUndoToast = false
        }
        undoItem = nil
    }
    
    private var undoToastView: some View {
        VStack {
            Spacer()
            
            HStack(spacing: DesignTokens.spacingMD) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignTokens.accentComplete)
                
                Text(String(localized: "Marked done"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Spacer()
                
                Button {
                    undoLastDone()
                } label: {
                    Text(String(localized: "Undo"))
                        .font(AppTheme.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.accentActive)
                }
                .nudgeAccessibility(
                    label: String(localized: "Undo completion"),
                    hint: String(localized: "Returns the task to your active list"),
                    traits: .isButton
                )
            }
            .padding(DesignTokens.spacingLG)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(DesignTokens.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                            .strokeBorder(DesignTokens.cardBorder, lineWidth: DesignTokens.cardBorderWidth)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 16, y: 4)
            )
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Helpers
    
    private func setupRepository() {
        if repository == nil {
            repository = NudgeRepository(modelContext: modelContext)
        }
    }
    
    private func refreshData() {
        guard let repository else { return }
        let grouped = repository.fetchAllGrouped()
        activeItems = grouped.active
        snoozedItems = grouped.snoozed
        doneItems = grouped.doneToday
    }
}

// MARK: - Item Edit Sheet

struct ItemEditSheet: View {
    
    let item: NudgeItem
    var onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedContent: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.canvas.ignoresSafeArea()
                
                VStack(spacing: DesignTokens.spacingLG) {
                    // Content editor
                    TextField(String(localized: "Task"), text: $editedContent, axis: .vertical)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .padding(DesignTokens.spacingLG)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                                .fill(Color.white.opacity(0.05))
                        )
                        .lineLimit(1...5)
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                        Label(item.sourceType.label, systemImage: item.sourceType.icon)
                        Label(item.createdAt.relativeDescription, systemImage: "clock")
                        if let action = item.actionType {
                            Label(action.label, systemImage: action.icon)
                        }
                    }
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                }
                .padding(DesignTokens.spacingXL)
            }
            .navigationTitle(String(localized: "Edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        item.content = editedContent
                        onSave()
                        dismiss()
                    }
                    .disabled(editedContent.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            editedContent = item.content
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: NudgeItem.self, BrainDump.self, configurations: config)
    
    let ctx = container.mainContext
    ctx.insert(NudgeItem(content: "Call the dentist", emoji: "📞", actionType: .call, sortOrder: 1))
    ctx.insert(NudgeItem(content: "Buy dog food", emoji: "🐶", sortOrder: 2))
    ctx.insert(NudgeItem(content: "Read Jake's article", emoji: "📖", sortOrder: 3))
    
    let doneItem = NudgeItem(content: "Reply to Sarah", emoji: "💬", sortOrder: 0)
    doneItem.markDone()
    ctx.insert(doneItem)
    
    return AllItemsView()
        .modelContainer(container)
        .environment(AppSettings())
        .environment(PenguinState())
}
