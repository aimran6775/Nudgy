//
//  QuickAddSheet.swift
//  Nudge
//
//  AI-powered natural language task entry.
//  Type naturally — Nudgy extracts the task, emoji, action type, and contacts.
//  Falls back to plain text entry when AI is unavailable.
//

import SwiftUI
import SwiftData

struct QuickAddSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var taskText = ""
    @State private var isExtracting = false
    @State private var extractedPreview: NaturalTaskExtraction?
    @State private var extractionTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool
    
    private var aiAvailable: Bool { NudgyEngine.shared.isAvailable || AIService.shared.isAvailable }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Glass background
                ZStack {
                    Color.black.ignoresSafeArea()
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [DesignTokens.accentActive.opacity(0.04), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)
                        .offset(x: -60, y: -80)
                        .blur(radius: 50)
                }
                .ignoresSafeArea()
                
                VStack(spacing: DesignTokens.spacingLG) {
                    // Task input
                    TextField(
                        aiAvailable
                            ? String(localized: "Tell Nudgy what you need to do...")
                            : String(localized: "What's on your mind?"),
                        text: $taskText,
                        axis: .vertical
                    )
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .padding(DesignTokens.spacingLG)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                            .fill(Color.white.opacity(0.05))
                    )
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .onChange(of: taskText) {
                        debounceExtraction()
                    }
                    
                    // AI extraction preview
                    if let preview = extractedPreview, preview.isActionable {
                        aiPreviewCard(preview)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if isExtracting {
                        HStack(spacing: DesignTokens.spacingSM) {
                            ProgressView()
                                .tint(DesignTokens.accentActive)
                                .controlSize(.small)
                            Text(String(localized: "Nudgy is parsing..."))
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                    }
                    
                    // Hint
                    if aiAvailable {
                        Label {
                            Text(String(localized: "Type naturally — Nudgy will extract the task, emoji & action"))
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.textTertiary)
                        } icon: {
                            Image(systemName: "apple.intelligence")
                                .font(.system(size: 10))
                                .foregroundStyle(DesignTokens.accentActive)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(String(localized: "Type a single task. For multiple tasks, use Brain Dump."))
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Quick examples (shown when empty)
                    if taskText.isEmpty && aiAvailable {
                        quickExamples
                    }
                    
                    Spacer()
                }
                .padding(DesignTokens.spacingXL)
            }
            .navigationTitle(String(localized: "Quick Add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Add")) {
                        saveTask()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignTokens.accentActive)
                    .disabled(taskText.trimmingCharacters(in: .whitespaces).isEmpty || isExtracting)
                }
            }
            .animation(.easeOut(duration: 0.2), value: extractedPreview?.taskContent)
            .animation(.easeOut(duration: 0.2), value: isExtracting)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            isFocused = true
        }
    }
    
    // MARK: - AI Preview Card
    
    private func aiPreviewCard(_ preview: NaturalTaskExtraction) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(String(localized: "Nudgy understood:"))
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textTertiary)
            
            HStack(spacing: DesignTokens.spacingSM) {
                Text(preview.emoji)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(preview.taskContent)
                        .font(AppTheme.body.weight(.medium))
                        .foregroundStyle(DesignTokens.textPrimary)
                    
                    HStack(spacing: DesignTokens.spacingSM) {
                        if !preview.actionType.isEmpty {
                            Label(preview.actionType, systemImage: actionIcon(for: preview.actionType))
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.accentActive)
                        }
                        if !preview.contactName.isEmpty {
                            Label(preview.contactName, systemImage: "person.fill")
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignTokens.accentComplete)
                    .font(.system(size: 18))
            }
            .padding(DesignTokens.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(DesignTokens.accentActive.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                            .strokeBorder(DesignTokens.accentActive.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
    }
    
    // MARK: - Quick Examples
    
    private var quickExamples: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(String(localized: "Try saying:"))
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textTertiary)
            
            ForEach(exampleInputs, id: \.self) { example in
                Button {
                    taskText = example
                    debounceExtraction()
                } label: {
                    Text(example)
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.accentActive.opacity(0.8))
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM)
                        .background(
                            Capsule()
                                .fill(DesignTokens.accentActive.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private let exampleInputs = [
        "Call Dr. Chen about my appointment",
        "Text Sarah about Saturday plans",
        "Buy groceries after work",
    ]
    
    // MARK: - AI Extraction
    
    private func debounceExtraction() {
        extractionTask?.cancel()
        extractedPreview = nil
        
        let trimmed = taskText.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 5, aiAvailable else {
            isExtracting = false
            return
        }
        
        isExtracting = true
        extractionTask = Task {
            // Debounce — wait 600ms after user stops typing
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled else { return }
            
            do {
                let extraction = try await AIService.shared.extractTask(from: trimmed)
                guard !Task.isCancelled else { return }
                
                withAnimation {
                    extractedPreview = extraction
                    isExtracting = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                isExtracting = false
            }
        }
    }
    
    // MARK: - Save
    
    private func saveTask() {
        let trimmed = taskText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        let repository = NudgeRepository(modelContext: modelContext)
        
        if let preview = extractedPreview, preview.isActionable {
            // AI-enhanced save: use extracted data, but go through createManual-style path
            let actionType: ActionType? = {
                switch preview.actionType.uppercased() {
                case "CALL": return .call
                case "TEXT": return .text
                case "EMAIL": return .email
                default: return nil
                }
            }()
            _ = repository.createManualWithDetails(
                content: preview.taskContent,
                emoji: preview.emoji,
                actionType: actionType,
                actionTarget: preview.actionTarget.isEmpty ? nil : preview.actionTarget,
                contactName: preview.contactName.isEmpty ? nil : preview.contactName
            )
        } else {
            // Plain text save
            _ = repository.createManual(content: trimmed)
        }
        
        HapticService.shared.shareSaved()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        dismiss()
    }
    
    private func actionIcon(for type: String) -> String {
        switch type.uppercased() {
        case "CALL": return "phone.fill"
        case "TEXT": return "message.fill"
        case "EMAIL": return "envelope.fill"
        default: return "bolt.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    QuickAddSheet()
        .modelContainer(for: [NudgeItem.self, BrainDump.self], inMemory: true)
}
