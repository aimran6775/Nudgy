//
//  NudgyChatView.swift
//  Nudge
//
//  Conversational chat UI with Nudgy the penguin.
//  Users can talk to Nudgy about their tasks, ask for help,
//  and Nudgy can look up and act on real task data via tools.
//
//  Features:
//  • Real-time streaming responses
//  • Contextual suggestion chips based on current task state
//  • Tool action notifications (task created, completed, etc.)
//  • AI status indicator
//
//  Presented as a sheet from the main screen.
//

import SwiftUI
import SwiftData

struct NudgyChatView: View {
    
    /// Optional dismiss handler for inline mode (when not presented as sheet)
    var onDismiss: (() -> Void)?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(PenguinState.self) private var penguinState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            
            Divider()
                .overlay(DesignTokens.cardBorder)
            
            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DesignTokens.spacingMD) {
                        // Empty state welcome
                        if penguinState.chatMessages.isEmpty && !penguinState.isChatGenerating {
                            chatWelcome
                                .padding(.top, DesignTokens.spacingXXL)
                        }
                        
                        ForEach(penguinState.chatMessages) { message in
                            chatBubble(for: message)
                                .id(message.id)
                        }
                        
                        // Streaming indicator
                        if penguinState.isChatGenerating {
                            streamingBubble
                                .id("streaming")
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.vertical, DesignTokens.spacingMD)
                }
                .onChange(of: penguinState.chatMessages.count) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        if penguinState.isChatGenerating {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        } else if let last = penguinState.chatMessages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: penguinState.streamingText) {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
            
            Divider()
                .overlay(DesignTokens.cardBorder)
            
            // Suggestion chips (above input when few messages)
            if penguinState.chatMessages.count <= 2 {
                suggestionChipRow
            }
            
            // Input bar
            chatInputBar
        }
        .background {
            ZStack {
                Color.black
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [DesignTokens.accentActive.opacity(0.04), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
                    .offset(x: -80, y: -160)
                    .blur(radius: 50)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Only start chatting if not already in chat mode
            // (NudgyHomeView may have already started it)
            if penguinState.interactionMode != .chatting {
                NudgyEngine.shared.startChat()
            }
            isInputFocused = true
        }
    }
    
    // MARK: - Header
    
    private var chatHeader: some View {
        HStack {
            // Mini penguin avatar
            LottieNudgyView(
                expression: penguinState.isChatGenerating ? .thinking : penguinState.expression,
                size: 36,
                accentColor: DesignTokens.accentActive
            )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignTokens.spacingXS) {
                    Text(String(localized: "Nudgy"))
                        .font(AppTheme.headline)
                        .foregroundStyle(DesignTokens.textPrimary)
                    
                    // AI status dot
                    Circle()
                        .fill(NudgyEngine.shared.isAvailable
                              ? DesignTokens.accentComplete
                              : DesignTokens.textTertiary)
                        .frame(width: 6, height: 6)
                }
                
                Text(penguinState.isChatGenerating
                     ? String(localized: "*thinking noises*")
                     : NudgyEngine.shared.isAvailable
                        ? String(localized: "your penguin • AI-powered")
                        : String(localized: "your penguin buddy"))
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            
            Spacer()
            
            // Clear chat button
            if !penguinState.chatMessages.isEmpty {
                Button {
                    NudgyEngine.shared.clearChat()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .nudgeAccessibility(
                    label: String(localized: "Clear chat"),
                    hint: String(localized: "Clears the conversation history"),
                    traits: .isButton
                )
            }
            
            // Close button
            Button {
                if let onDismiss {
                    onDismiss()
                } else {
                    NudgyEngine.shared.exitChat()
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .nudgeAccessibility(
                label: String(localized: "Close chat"),
                hint: String(localized: "Returns to the main screen"),
                traits: .isButton
            )
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.vertical, DesignTokens.spacingMD)
        .background(DesignTokens.cardSurface.opacity(0.5))
    }
    
    // MARK: - Chat Welcome
    
    private var chatWelcome: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            LottieNudgyView(
                expression: .waving,
                size: DesignTokens.penguinSizeMedium,
                accentColor: DesignTokens.accentActive
            )
            
            VStack(spacing: DesignTokens.spacingSM) {
                Text(String(localized: "*happy waddle* 🐧"))
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Text(String(localized: "Talk to me about your tasks, ask me to help you prioritize, or just vent. I'm a penguin — I don't judge."))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            .padding(.horizontal, DesignTokens.spacingXL)
        }
    }
    
    // MARK: - Chat Bubbles
    
    @ViewBuilder
    private func chatBubble(for message: ChatMessage) -> some View {
        if message.role == .system {
            // System messages: compact centered pill (like iMessage timestamps)
            HStack {
                Spacer()
                Text(message.text)
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingXS)
                    .background {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                    }
                Spacer()
            }
        } else {
            HStack {
                if message.role == .user {
                    Spacer(minLength: 60)
                }
                
                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                    Text(message.text)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .multilineTextAlignment(message.role == .user ? .trailing : .leading)
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM + 2)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(message.role == .user
                                          ? DesignTokens.accentActive.opacity(0.15)
                                          : Color.white.opacity(0.03))
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        message.role == .user
                                            ? DesignTokens.accentActive.opacity(0.25)
                                            : Color.white.opacity(0.06),
                                        lineWidth: 0.5
                                    )
                            }
                        }
                }
                .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)
                
                if message.role == .nudgy {
                    Spacer(minLength: 60)
                }
            }
        }
    }
    
    // MARK: - Streaming Bubble
    
    private var streamingBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if penguinState.streamingText.isEmpty {
                    // Thinking dots
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(DesignTokens.textTertiary)
                                .frame(width: 6, height: 6)
                                .opacity(0.5)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(i) * 0.2),
                                    value: penguinState.isChatGenerating
                                )
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingMD)
                } else {
                    Text(penguinState.streamingText)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM + 2)
                }
            }
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.03))
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                }
            }
            .frame(maxWidth: 280, alignment: .leading)
            
            Spacer(minLength: 60)
        }
    }
    
    // MARK: - Suggestion Chips
    
    private var suggestionChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.spacingSM) {
                suggestionChip("What should I tackle first?", icon: "star.fill")
                suggestionChip("How's my day looking?", icon: "chart.bar.fill")
                suggestionChip("Help me break this down", icon: "sparkles")
                suggestionChip("Anything overdue?", icon: "exclamationmark.triangle.fill")
                suggestionChip("Add something new", icon: "plus.circle.fill")
            }
            .padding(.horizontal, DesignTokens.spacingLG)
        }
        .padding(.vertical, DesignTokens.spacingSM)
    }
    
    private func suggestionChip(_ text: String, icon: String? = nil) -> some View {
        Button {
            inputText = text
            sendMessage()
        } label: {
            HStack(spacing: DesignTokens.spacingXS) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(text)
                    .font(AppTheme.caption)
            }
            .foregroundStyle(DesignTokens.accentActive)
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM)
            .background(
                Capsule()
                    .fill(DesignTokens.accentActive.opacity(0.08))
                    .overlay(
                        Capsule()
                            .strokeBorder(DesignTokens.accentActive.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Input Bar
    
    private var chatInputBar: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            TextField(
                String(localized: "Talk to Nudgy..."),
                text: $inputText,
                axis: .vertical
            )
            .font(AppTheme.body)
            .foregroundStyle(DesignTokens.textPrimary)
            .lineLimit(1...4)
            .focused($isInputFocused)
            .onSubmit { sendMessage() }
            .textFieldStyle(.plain)
            
            // Send button
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? DesignTokens.textTertiary
                            : DesignTokens.accentActive
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || penguinState.isChatGenerating)
            .nudgeAccessibility(
                label: String(localized: "Send message"),
                hint: String(localized: "Sends your message to Nudgy"),
                traits: .isButton
            )
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.vertical, DesignTokens.spacingMD)
        .background(DesignTokens.cardSurface.opacity(0.5))
    }
    
    // MARK: - Send
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !penguinState.isChatGenerating else { return }
        
        inputText = ""
        HapticService.shared.prepare()
        
        // Route through NudgyEngine for OpenAI-powered conversation
        NudgyEngine.shared.chat(text, modelContext: modelContext)
    }
}

// MARK: - Preview

#Preview {
    let state = PenguinState()
    state.startChatting()
    
    return NudgyChatView()
        .modelContainer(for: [NudgeItem.self, BrainDump.self], inMemory: true)
        .environment(state)
        .environment(AppSettings())
}
