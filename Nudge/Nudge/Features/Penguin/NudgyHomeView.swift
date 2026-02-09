//
//  NudgyHomeView.swift
//  Nudge
//
//  The main tab — "Nudgy". Your penguin companion lives here.
//
//  This is NOT a chatbot. Nudgy is a character you interact with:
//  - Tap the mic to talk (voice-first)
//  - Or type in the text bar (fallback)
//  - Nudgy responds via speech bubbles above the character + spoken voice
//  - Conversation history scrolls behind Nudgy (secondary, not primary)
//  - The penguin's expression changes in real-time
//
//  The emotional center of the app — a companion, not a tool.
//

import SwiftUI
import SwiftData
import Speech

struct NudgyHomeView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(PenguinState.self) private var penguinState
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hasGreeted = false
    @State private var breatheAnimation = false
    @State private var inputText = ""
    @State private var isListeningToUser = false
    @State private var speechService = SpeechService()
    @State private var showHistory = false
    @FocusState private var isInputFocused: Bool
    @State private var showWardrobe = false

    var body: some View {
        ZStack {
            // OLED canvas + subtle ambient glow
            ambientBackground

            VStack(spacing: 0) {
                // Conversation history (scrollable above Nudgy)
                if showHistory && !penguinState.chatMessages.isEmpty {
                    conversationHistory
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Top bar — wardrobe + snowflakes
                HStack {
                    Spacer()

                    Button {
                        HapticService.shared.prepare()
                        showWardrobe = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("❄️ \(RewardService.shared.snowflakes)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(DesignTokens.textPrimary)

                            Image(systemName: "tshirt.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(DesignTokens.accentActive)
                        }
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingXS)
                        .background(
                            Capsule()
                                .fill(DesignTokens.cardSurface)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(DesignTokens.cardBorder, lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .nudgeAccessibility(
                        label: String(localized: "Wardrobe — \(RewardService.shared.snowflakes) snowflakes"),
                        hint: String(localized: "Open the wardrobe to dress up Nudgy"),
                        traits: .isButton
                    )
                }
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.top, DesignTokens.spacingXS)

                Spacer()

                // ★ Nudgy — the whole point
                nudgyCharacter

                // Listening indicator (when mic is active)
                if isListeningToUser {
                    listeningIndicator
                        .transition(.scale.combined(with: .opacity))
                }

                // Thinking indicator
                if penguinState.isChatGenerating && !isListeningToUser {
                    thinkingIndicator
                        .transition(.opacity)
                }

                Spacer()

                // Bottom interaction bar: mic + text input
                interactionBar
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            greetIfNeeded()
            startBreathingAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            greetIfNeeded()
        }
        .onChange(of: speechService.state) { _, newState in
            handleSpeechStateChange(newState)
        }
        .sheet(isPresented: $showWardrobe) {
            WardrobeView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(DesignTokens.cardSurface)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Ambient Background

    private var ambientBackground: some View {
        ZStack {
            // Antarctic environment — Nudgy's home
            AntarcticEnvironment(
                mood: RewardService.shared.environmentMood,
                unlockedProps: RewardService.shared.unlockedProps,
                sceneHeight: UIScreen.main.bounds.height
            )
            .ignoresSafeArea()

            // Subtle breathing glow behind penguin
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            penguinState.accentColor.opacity(breatheAnimation ? 0.06 : 0.02),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .animation(
                    reduceMotion
                        ? nil
                        : .easeInOut(duration: 4).repeatForever(autoreverses: true),
                    value: breatheAnimation
                )

            // Listening pulse ring
            if isListeningToUser {
                Circle()
                    .stroke(DesignTokens.accentActive.opacity(0.15), lineWidth: 2)
                    .frame(width: 300, height: 300)
                    .scaleEffect(breatheAnimation ? 1.1 : 0.9)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: breatheAnimation
                    )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Nudgy Character (center of screen)

    private var nudgyCharacter: some View {
        PenguinSceneView(
            size: .hero,
            onTap: {
                // Tapping Nudgy = start listening (voice-first companion)
                if isListeningToUser {
                    stopListening()
                } else if penguinState.isChatGenerating {
                    // Nudgy is thinking — let the user know
                    HapticService.shared.prepare()
                } else {
                    // Start voice input — Nudgy is a companion you TALK to
                    startListening()
                }
            },
            onChatTap: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showHistory.toggle()
                }
            }
        )
    }

    // MARK: - Listening Indicator

    private var listeningIndicator: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            // Waveform bars
            HStack(spacing: 3) {
                ForEach(0..<12, id: \.self) { i in
                    let level = i < speechService.waveformSamples.count
                        ? CGFloat(speechService.waveformSamples[i])
                        : 0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignTokens.accentActive)
                        .frame(width: 3, height: max(4, level * 30))
                        .animation(.easeOut(duration: 0.1), value: level)
                }
            }
            .frame(height: 34)

            // Live transcript preview
            if !speechService.liveTranscript.isEmpty {
                Text(speechService.liveTranscript)
                    .font(AppTheme.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.spacingXL)
                    .transition(.opacity)
            }

            Text(String(localized: "tap Nudgy to send"))
                .font(.system(size: 11))
                .foregroundStyle(DesignTokens.textTertiary.opacity(0.6))
        }
        .padding(.top, DesignTokens.spacingSM)
    }

    // MARK: - Thinking Indicator

    private var thinkingIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(DesignTokens.accentActive.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .offset(y: breatheAnimation ? -4 : 4)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: breatheAnimation
                    )
            }
        }
        .padding(.top, DesignTokens.spacingSM)
    }

    // MARK: - Conversation History (scrollable, behind Nudgy)

    private var conversationHistory: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.spacingSM) {
                ForEach(penguinState.chatMessages) { message in
                    conversationBubble(for: message)
                }
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingSM)
        }
        .frame(maxHeight: 250)
        .mask(
            LinearGradient(
                colors: [.clear, .black, .black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private func conversationBubble(for message: ChatMessage) -> some View {
        if message.role == .system {
            Text(message.text)
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textTertiary)
                .padding(.horizontal, DesignTokens.spacingSM)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.04)))
        } else {
            HStack {
                if message.role == .user { Spacer(minLength: 80) }

                Text(message.text)
                    .font(AppTheme.caption)
                    .foregroundStyle(
                        message.role == .user
                            ? DesignTokens.textSecondary
                            : DesignTokens.textTertiary
                    )
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(message.role == .user
                                  ? DesignTokens.accentActive.opacity(0.08)
                                  : Color.white.opacity(0.03))
                    )
                    .frame(maxWidth: 250, alignment: message.role == .user ? .trailing : .leading)

                if message.role == .nudgy { Spacer(minLength: 80) }
            }
        }
    }

    // MARK: - Interaction Bar (bottom)

    private var interactionBar: some View {
        VStack(spacing: 0) {
            // History toggle (if messages exist)
            if !penguinState.chatMessages.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showHistory.toggle()
                    }
                } label: {
                    HStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: showHistory ? "chevron.down" : "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                        Text(showHistory
                             ? String(localized: "hide conversation")
                             : String(localized: "\(penguinState.chatMessages.count) messages"))
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(DesignTokens.textTertiary.opacity(0.5))
                    .padding(.vertical, DesignTokens.spacingXS)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: DesignTokens.spacingMD) {
                // Mic button — primary interaction
                Button {
                    if isListeningToUser {
                        stopListening()
                    } else {
                        startListening()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isListeningToUser
                                  ? DesignTokens.accentActive
                                  : DesignTokens.cardSurface)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        isListeningToUser
                                            ? DesignTokens.accentActive
                                            : DesignTokens.cardBorder,
                                        lineWidth: 0.5
                                    )
                            )

                        Image(systemName: isListeningToUser ? "stop.fill" : "mic.fill")
                            .font(.system(size: isListeningToUser ? 14 : 18))
                            .foregroundStyle(isListeningToUser ? .black : DesignTokens.accentActive)
                    }
                }
                .disabled(penguinState.isChatGenerating)
                .nudgeAccessibility(
                    label: isListeningToUser
                        ? String(localized: "Stop listening")
                        : String(localized: "Talk to Nudgy"),
                    hint: String(localized: "Use your voice to talk to Nudgy"),
                    traits: .isButton
                )

                // Text field — secondary
                HStack(spacing: DesignTokens.spacingSM) {
                    TextField(
                        String(localized: "or type here..."),
                        text: $inputText,
                        axis: .vertical
                    )
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(1...3)
                    .focused($isInputFocused)
                    .onSubmit { sendTextMessage() }
                    .textFieldStyle(.plain)

                    if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            sendTextMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(DesignTokens.accentActive)
                        }
                        .disabled(penguinState.isChatGenerating)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(DesignTokens.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(DesignTokens.cardBorder, lineWidth: 0.5)
                        )
                )

                // Clear history
                if !penguinState.chatMessages.isEmpty {
                    Button {
                        withAnimation { NudgyEngine.shared.clearChat() }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    .nudgeAccessibility(
                        label: String(localized: "Reset conversation"),
                        traits: .isButton
                    )
                }
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingMD)
            .background(
                DesignTokens.cardSurface.opacity(0.3)
                    .background(.ultraThinMaterial.opacity(0.5))
                    .ignoresSafeArea(.container, edges: .bottom)
            )
        }
    }

    // MARK: - Voice Input

    /// Curated "I'm listening" lines for when the user taps the penguin.
    private static let listeningGreetings: [String] = [
        "I'm all ears!",
        "Go ahead, I'm listening!",
        "Talk to me!",
        "What's on your mind?",
        "Listening!",
        "Yep, I'm here!",
        "Tell me!",
    ]

    private func startListening() {
        // Ensure chat mode so responses go through AI
        if penguinState.interactionMode != .chatting {
            penguinState.startChatting()
        }

        // Greet — speech bubble only (no TTS to avoid audio session conflict with mic)
        let greeting = Self.listeningGreetings.randomElement() ?? "I'm listening!"
        penguinState.say(greeting, style: .speech, autoDismiss: 2.5)
        HapticService.shared.micStart()

        Task {
            let authorized = await speechService.requestPermission()
            guard authorized else { return }

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isListeningToUser = true
            }

            penguinState.expression = .listening

            do {
                try speechService.startRecording()
                print("🎙️ Recording started")
            } catch {
                print("🎙️ Recording failed: \(error)")
                withAnimation { isListeningToUser = false }
                penguinState.expression = .confused
                penguinState.say(
                    String(localized: "*taps ear* Hmm, my hearing is acting up. Try typing? 🐧"),
                    autoDismiss: 3.0
                )
            }
        }
    }

    private func stopListening() {
        // Grab transcript BEFORE stopping (stopRecording resets state)
        let transcript = speechService.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🎙️ stopListening: transcript='\(transcript)'")

        // Mark as no longer listening FIRST to prevent handleSpeechStateChange from double-sending
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isListeningToUser = false
        }

        speechService.stopRecording()

        guard !transcript.isEmpty else {
            penguinState.expression = .confused
            penguinState.say(
                String(localized: "I didn't catch that! Try again? 🐧"),
                autoDismiss: 2.5
            )
            return
        }

        HapticService.shared.micStop()
        sendToNudgy(transcript)
    }

    private func handleSpeechStateChange(_ state: SpeechService.SpeechState) {
        switch state {
        case .recording:
            // Feed waveform to penguin state for reactivity
            penguinState.updateAudioLevel(speechService.audioLevel, samples: speechService.waveformSamples)
        case .finished(let transcript):
            // Only handle if we're still listening (stopListening handles its own send)
            guard isListeningToUser else {
                print("🎙️ .finished but already handled by stopListening")
                return
            }
            print("🎙️ .finished auto-trigger (timer/limit reached)")
            withAnimation { isListeningToUser = false }
            let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                HapticService.shared.micStop()
                sendToNudgy(cleaned)
            }
        case .error(let msg):
            print("🎙️ Speech error: \(msg)")
            withAnimation { isListeningToUser = false }
            penguinState.expression = .confused
        default:
            break
        }
    }

    // MARK: - Send Messages

    private func sendTextMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !penguinState.isChatGenerating else { return }

        inputText = ""
        isInputFocused = false
        sendToNudgy(text)
    }

    /// Core send — works for both voice and text input.
    /// Nudgy responds via speech bubble + spoken voice (NOT chat bubbles).
    /// Routes through NudgyEngine for OpenAI-powered conversation with memory.
    private func sendToNudgy(_ text: String) {
        print("💬 sendToNudgy: '\(text.prefix(80))'")

        // Ensure we're in chat mode
        if penguinState.interactionMode != .chatting {
            NudgyEngine.shared.startChat()
        }

        // Show thinking state immediately
        penguinState.expression = .thinking
        penguinState.say(String(localized: "Let me think..."), style: .thought, autoDismiss: nil)
        HapticService.shared.prepare()
        NudgyEngine.shared.chat(text, modelContext: modelContext)
    }

    // MARK: - Helpers

    private func greetIfNeeded() {
        guard !hasGreeted else { return }
        hasGreeted = true

        let repo = NudgeRepository(modelContext: modelContext)
        let activeQueue = repo.fetchActiveQueue()
        let grouped = repo.fetchAllGrouped()

        let overdueCount = activeQueue.filter { $0.accentStatus == .overdue }.count
        let staleCount = activeQueue.filter { $0.accentStatus == .stale }.count
        let doneToday = grouped.doneToday.count

        NudgyEngine.shared.greet(
            userName: settings.userName,
            activeTaskCount: activeQueue.count,
            overdueCount: overdueCount,
            staleCount: staleCount,
            doneToday: doneToday
        )
    }

    private func startBreathingAnimation() {
        breatheAnimation = true
    }
}

// MARK: - Preview

#Preview {
    NudgyHomeView()
        .modelContainer(for: [NudgeItem.self, BrainDump.self], inMemory: true)
        .environment(AppSettings())
        .environment(PenguinState())
}
