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
    @State private var showInlineChat = false
    @State private var isVoiceEnabled: Bool = NudgyConfig.Voice.isEnabled
    
    /// Whether we're in voice conversation mode (auto-listen → send → speak → auto-listen loop)
    @State private var isVoiceConversation = false
    /// Tracks if we're waiting for Nudgy to finish speaking before auto-resuming
    @State private var awaitingTTSFinish = false
    


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

                // Top bar — mute + wardrobe + snowflakes
                topBar
                    .padding(.horizontal, DesignTokens.spacingLG)

                Spacer()

                // ★ Nudgy — the whole point
                nudgyCharacter

                // Listening indicator (when mic is active)
                if isListeningToUser {
                    listeningIndicator
                        .transition(.scale.combined(with: .opacity))
                }

                // Thinking indicator (when generating response)
                if penguinState.isChatGenerating && !isListeningToUser {
                    thinkingIndicator
                        .transition(.opacity)
                }
                
                // Conversation mode: "Nudgy is speaking..." indicator
                if isVoiceConversation && awaitingTTSFinish && !penguinState.isChatGenerating && !isListeningToUser {
                    speakingIndicator
                        .transition(.opacity)
                }

                Spacer()

                // Bottom action buttons: glassmorphic chat + voice
                bottomActionButtons
            }
            .safeAreaPadding(.top, DesignTokens.spacingSM)

            // Inline chat — glassmorphic text input at bottom
            if showInlineChat {
                inlineChatBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            greetIfNeeded()
            startBreathingAnimation()
        }
        .onChange(of: speechService.state) { _, newState in
            handleSpeechStateChange(newState)
        }
        .onChange(of: isVoiceConversation) { _, active in
            penguinState.isVoiceConversationActive = active
            speechService.silenceAutoSendEnabled = active
            if !active {
                awaitingTTSFinish = false
            }
        }
        .onChange(of: NudgyVoiceOutput.shared.isSpeaking) { wasSpeaking, isSpeaking in
            // Auto-resume listening when TTS finishes in conversation mode
            if wasSpeaking && !isSpeaking && isVoiceConversation && awaitingTTSFinish {
                print("🔄 Voice conversation: TTS finished (onChange), auto-resuming listening")
                awaitingTTSFinish = false
                Task {
                    // Give the audio system time to fully release the playback session
                    try? await Task.sleep(for: .seconds(0.4))
                    guard isVoiceConversation else { return }
                    startListening()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgyTTSSkipped)) { _ in
            // TTS was skipped (voice disabled) — auto-resume listening anyway
            guard isVoiceConversation && awaitingTTSFinish else { return }
            print("🔄 Voice conversation: TTS skipped, auto-resuming listening")
            awaitingTTSFinish = false
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                guard isVoiceConversation else { return }
                startListening()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            greetIfNeeded()
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
        GeometryReader { geo in
            ZStack {
                // Antarctic environment — Nudgy's home
                AntarcticEnvironment(
                    mood: RewardService.shared.environmentMood,
                    unlockedProps: RewardService.shared.unlockedProps,
                    sceneWidth: geo.size.width,
                    sceneHeight: geo.size.height
                )

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
        }
        .ignoresSafeArea()
    }

    // MARK: - Nudgy Character (center of screen)

    private var nudgyCharacter: some View {
        PenguinSceneView(
            size: .hero,
            onTap: {
                // Tapping Nudgy during conversation = end conversation
                if isVoiceConversation {
                    endVoiceConversation()
                } else if isListeningToUser {
                    stopListening()
                } else if penguinState.isChatGenerating {
                    // Nudgy is thinking — let the user know
                    HapticService.shared.prepare()
                } else {
                    // Start voice conversation — Nudgy is a companion you TALK to
                    startVoiceConversation()
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

            // Live transcript preview — larger in conversation mode
            if !speechService.liveTranscript.isEmpty {
                Text(speechService.liveTranscript)
                    .font(isVoiceConversation ? AppTheme.body : AppTheme.caption)
                    .foregroundStyle(isVoiceConversation ? DesignTokens.textPrimary : DesignTokens.textSecondary)
                    .lineLimit(isVoiceConversation ? 4 : 2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.15), value: speechService.liveTranscript)
            }

            // Hint text
            if isVoiceConversation {
                Text(speechService.liveTranscript.isEmpty
                     ? String(localized: "brain dump — listening...")
                     : String(localized: "pause to send"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.accentActive.opacity(0.6))
            } else {
                Text(String(localized: "tap Nudgy to send"))
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.textTertiary.opacity(0.6))
            }
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
    
    // MARK: - Speaking Indicator (conversation mode — Nudgy is speaking)
    
    private var speakingIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.accentActive.opacity(0.7))
                .symbolEffect(.variableColor.iterative, isActive: true)
            
            Text(String(localized: "Nudgy is speaking..."))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignTokens.textTertiary)
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

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Mute/unmute button
            Button {
                HapticService.shared.prepare()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isVoiceEnabled.toggle()
                    NudgyConfig.Voice.isEnabled = isVoiceEnabled
                }
            } label: {
                Image(systemName: isVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isVoiceEnabled ? DesignTokens.accentActive : DesignTokens.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(
                label: isVoiceEnabled
                    ? String(localized: "Mute Nudgy")
                    : String(localized: "Unmute Nudgy"),
                hint: String(localized: "Toggle Nudgy's voice on or off"),
                traits: .isButton
            )

            Spacer()

            Button {
                HapticService.shared.prepare()
                showWardrobe = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "snowflake")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.cyan)
                        .symbolRenderingMode(.hierarchical)

                    Text("\(RewardService.shared.snowflakes)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(DesignTokens.textPrimary)

                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignTokens.accentActive)
                        .symbolRenderingMode(.hierarchical)
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingXS)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(
                label: String(localized: "Wardrobe — \(RewardService.shared.snowflakes) snowflakes"),
                hint: String(localized: "Open the wardrobe to dress up Nudgy"),
                traits: .isButton
            )
        }
    }

    // MARK: - Bottom Action Buttons (glassmorphic)

    private var bottomActionButtons: some View {
        HStack(spacing: DesignTokens.spacingLG) {
            // Chat history badge
            if !penguinState.chatMessages.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showHistory.toggle()
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(DesignTokens.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                            .glassEffect(.regular.interactive(), in: .circle)

                        Text("\(penguinState.chatMessages.count)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(DesignTokens.accentActive))
                            .offset(x: 4, y: -2)
                    }
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Voice conversation button (mic / brain dump)
            Button {
                if isVoiceConversation {
                    endVoiceConversation()
                } else if isListeningToUser {
                    stopListening()
                } else {
                    startVoiceConversation()
                }
            } label: {
                ZStack {
                    if isVoiceConversation {
                        Circle()
                            .stroke(DesignTokens.accentActive.opacity(0.4), lineWidth: 2)
                            .frame(width: 64, height: 64)
                            .scaleEffect(breatheAnimation ? 1.15 : 1.0)
                            .opacity(breatheAnimation ? 0.3 : 0.7)
                            .animation(
                                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                                value: breatheAnimation
                            )
                    }

                    Circle()
                        .fill(isVoiceConversation
                              ? AnyShapeStyle(DesignTokens.accentActive)
                              : isListeningToUser
                                  ? AnyShapeStyle(DesignTokens.accentActive.opacity(0.8))
                                  : AnyShapeStyle(DesignTokens.cardSurface))
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .opacity(isVoiceConversation || isListeningToUser ? 0 : 1)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isVoiceConversation || isListeningToUser
                                        ? DesignTokens.accentActive
                                        : Color.white.opacity(0.12),
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(color: DesignTokens.accentActive.opacity(0.15), radius: 12, y: 4)

                    Image(systemName: isVoiceConversation
                          ? "waveform.circle.fill"
                          : isListeningToUser
                              ? "stop.fill"
                              : "mic.fill")
                        .font(.system(size: isVoiceConversation ? 24 : isListeningToUser ? 16 : 20))
                        .foregroundStyle(isVoiceConversation || isListeningToUser ? .black : DesignTokens.accentActive)
                        .symbolEffect(.pulse, isActive: isVoiceConversation && isListeningToUser)
                }
            }
            .disabled(penguinState.isChatGenerating && !isVoiceConversation)
            .nudgeAccessibility(
                label: isVoiceConversation
                    ? String(localized: "End conversation")
                    : isListeningToUser
                        ? String(localized: "Stop listening")
                        : String(localized: "Talk to Nudgy"),
                hint: String(localized: "Tap to have a voice conversation with Nudgy"),
                traits: .isButton
            )

            // Type to chat button — toggles inline text input
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showInlineChat.toggle()
                    if showInlineChat {
                        isInputFocused = true
                    } else {
                        isInputFocused = false
                    }
                }
            } label: {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: showInlineChat ? "xmark" : "text.bubble.fill")
                        .font(.system(size: 14))
                        .contentTransition(.symbolEffect(.replace))
                    if !showInlineChat {
                        Text(String(localized: "Chat"))
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .foregroundStyle(showInlineChat ? DesignTokens.textSecondary : DesignTokens.textPrimary)
                .padding(.horizontal, showInlineChat ? DesignTokens.spacingMD : DesignTokens.spacingLG)
                .padding(.vertical, DesignTokens.spacingMD)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(penguinState.isChatGenerating)
            .nudgeAccessibility(
                label: String(localized: "Type to chat with Nudgy"),
                traits: .isButton
            )

            Spacer()

            // Clear history
            if !penguinState.chatMessages.isEmpty {
                Button {
                    withAnimation { NudgyEngine.shared.clearChat() }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .nudgeAccessibility(
                    label: String(localized: "Reset conversation"),
                    traits: .isButton
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.bottom, DesignTokens.spacingMD)
    }

    // MARK: - Inline Chat Bar (glassmorphic)

    private var inlineChatBar: some View {
        VStack(spacing: 0) {
            // Mini conversation context — last 3 messages
            if !penguinState.chatMessages.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: DesignTokens.spacingSM) {
                            ForEach(penguinState.chatMessages.suffix(20)) { message in
                                inlineChatBubble(for: message)
                                    .id(message.id)
                            }

                            if penguinState.isChatGenerating {
                                HStack(spacing: 6) {
                                    ForEach(0..<3, id: \.self) { i in
                                        Circle()
                                            .fill(DesignTokens.accentActive.opacity(0.5))
                                            .frame(width: 5, height: 5)
                                            .offset(y: penguinState.isChatGenerating ? -2 : 2)
                                            .animation(
                                                .easeInOut(duration: 0.45)
                                                    .repeatForever(autoreverses: true)
                                                    .delay(Double(i) * 0.12),
                                                value: penguinState.isChatGenerating
                                            )
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, DesignTokens.spacingSM)
                                .id("typing")
                            }
                        }
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM)
                    }
                    .frame(maxHeight: 200)
                    .onChange(of: penguinState.chatMessages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            if penguinState.isChatGenerating {
                                proxy.scrollTo("typing", anchor: .bottom)
                            } else {
                                proxy.scrollTo(penguinState.chatMessages.last?.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Input field
            HStack(spacing: DesignTokens.spacingSM) {
                TextField(
                    String(localized: "Message Nudgy..."),
                    text: $inputText,
                    axis: .vertical
                )
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .lineLimit(1...3)
                .focused($isInputFocused)
                .onSubmit { sendTextMessage() }
                .textFieldStyle(.plain)

                if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        sendTextMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(DesignTokens.accentActive)
                    }
                    .disabled(penguinState.isChatGenerating)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM + 2)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
            )
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
            .padding(.horizontal, DesignTokens.spacingLG)
        }
        .padding(.bottom, DesignTokens.spacingSM)
        .background(
            // Scrim behind chat area
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.black.opacity(0.4), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea(edges: .bottom)
        )
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func inlineChatBubble(for message: ChatMessage) -> some View {
        if message.role == .system {
            Text(message.text)
                .font(.system(size: 11))
                .foregroundStyle(DesignTokens.textTertiary)
                .padding(.horizontal, DesignTokens.spacingSM)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.04)))
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            HStack {
                if message.role == .user { Spacer(minLength: 48) }

                Text(message.text)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(message.role == .user
                                  ? DesignTokens.accentActive.opacity(0.2)
                                  : Color.white.opacity(0.06))
                    )
                    .frame(maxWidth: 260, alignment: message.role == .user ? .trailing : .leading)

                if message.role == .nudgy { Spacer(minLength: 48) }
            }
        }
    }

    // MARK: - Voice Conversation Loop
    
    /// Curated "brain dump starting" lines for when the user taps the penguin.
    private static let brainDumpGreetings: [String] = [
        "Brain dump time! Tell me everything!",
        "Ooh, let it all out! I'll catch every task!",
        "Talk to me! I'll sort the chaos!",
        "Go go go! Dump everything on your mind!",
        "Ready! Say everything, I'll organize it!",
        "Hit me! What's bouncing around in there?",
        "Brain dump mode! Just talk, I'll handle the rest!",
    ]
    
    /// Start or stop voice conversation mode
    private func toggleVoiceConversation() {
        if isVoiceConversation {
            endVoiceConversation()
        } else {
            startVoiceConversation()
        }
    }
    
    /// Begin voice conversation mode — brain dump: auto-listen → extract tasks → speak → auto-listen loop
    private func startVoiceConversation() {
        print("🎙️🔄 Starting voice conversation (brain dump mode)")
        isVoiceConversation = true
        speechService.silenceAutoSendEnabled = true
        HapticService.shared.micStart()
        
        // Initialize brain dump conversation with specialized system prompt
        NudgyEngine.shared.startBrainDumpConversation(modelContext: modelContext)
        
        // Greet aloud with brain dump intro, then start listening after TTS finishes
        let greeting = Self.brainDumpGreetings.randomElement() ?? "Brain dump time!"
        penguinState.expression = .listening
        penguinState.say(greeting, style: .speech, autoDismiss: 3.0)
        NudgyVoiceOutput.shared.speak(greeting)
        
        Task {
            // Wait for the greeting TTS to finish before starting the mic
            while NudgyVoiceOutput.shared.isSpeaking {
                try? await Task.sleep(for: .milliseconds(150))
            }
            // Small buffer after TTS finishes to let audio hardware release
            try? await Task.sleep(for: .milliseconds(300))
            guard isVoiceConversation else { return }
            startListening()
        }
    }
    
    /// End voice conversation mode — stop everything
    private func endVoiceConversation() {
        print("🎙️🔄 Ending voice conversation mode")
        let wasBrainDump = NudgyEngine.shared.isBrainDumpMode
        
        isVoiceConversation = false
        speechService.silenceAutoSendEnabled = false
        awaitingTTSFinish = false
        
        if isListeningToUser {
            speechService.stopRecording()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isListeningToUser = false
            }
        }
        
        NudgyVoiceOutput.shared.stop()
        HapticService.shared.micStop()
        
        // End brain dump conversation and get summary
        if wasBrainDump {
            let tasksCreated = NudgyEngine.shared.endBrainDumpConversation()
            
            penguinState.expression = .happy
            
            if tasksCreated > 0 {
                let summary: String
                if tasksCreated == 1 {
                    summary = String(localized: "Brain dump done! Captured 1 task — go check your nudges! 🐧✨")
                } else {
                    summary = String(localized: "Brain dump done! Captured \(tasksCreated) tasks — they're all in your nudges! 🐧🎉")
                }
                penguinState.say(summary, style: .announcement, autoDismiss: 5.0)
                NudgyVoiceOutput.shared.speak(summary)
                
                // Notify data changed so the nudges view refreshes
                NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
            } else {
                let msg = String(localized: "No tasks this time — but I'm here whenever your brain needs a dump! 🧠🐧")
                penguinState.say(msg, autoDismiss: 4.0)
                NudgyVoiceOutput.shared.speak(msg)
            }
            
            // Return to idle after announcement
            Task {
                try? await Task.sleep(for: .seconds(5.0))
                if self.penguinState.expression == .happy {
                    self.penguinState.expression = .idle
                    self.penguinState.interactionMode = .ambient
                }
            }
        } else {
            // Normal conversation end
            NudgyEngine.shared.conversation.endConversation()
            penguinState.expression = .idle
            penguinState.say(String(localized: "Talk anytime! 🐧"), autoDismiss: 2.0)
        }
    }

    private func startListening() {
        // Ensure chat mode so responses go through AI
        if penguinState.interactionMode != .chatting {
            penguinState.startChatting()
        }

        // For single-mic-tap mode, show greeting (conversation mode greets in startVoiceConversation)
        if !isVoiceConversation {
            let greeting = Self.brainDumpGreetings.randomElement() ?? "I'm listening!"
            penguinState.say(greeting, style: .speech, autoDismiss: 2.5)
            HapticService.shared.micStart()
        }

        Task {
            let authorized = await speechService.requestPermission()
            guard authorized else {
                withAnimation { isListeningToUser = false }
                penguinState.expression = .confused
                penguinState.say(
                    String(localized: "Please allow mic & speech access in Settings 🐧"),
                    autoDismiss: 4.0
                )
                if isVoiceConversation { endVoiceConversation() }
                return
            }

            
            // CRITICAL: Always stop TTS and wait before touching the audio session.
            // On real devices, if TTS is still releasing the audio hardware when we
            // try to configure .playAndRecord, the mic fails silently.
            NudgyVoiceOutput.shared.stop()
            // Give the audio system a moment to fully release
            try? await Task.sleep(for: .milliseconds(400))

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isListeningToUser = true
            }

            penguinState.expression = .listening

            do {
                try await speechService.startRecordingWithRetry()
            } catch {
                withAnimation { isListeningToUser = false }
                penguinState.expression = .confused
                #if DEBUG
                penguinState.say("🔴 \(error.localizedDescription)", autoDismiss: 8.0)
                #else
                penguinState.say(
                    String(localized: "*taps ear* Hmm, my hearing is acting up. Type below instead! 🐧"),
                    autoDismiss: 3.5
                )
                #endif
                isInputFocused = true
                
                // End conversation mode if recording fails
                if isVoiceConversation {
                    endVoiceConversation()
                }
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
                String(localized: "I didn't catch that — type it below instead! 🐧"),
                autoDismiss: 3.5
            )
            isInputFocused = true
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
            
        case .silenceDetected(let transcript):
            // Auto-send from silence detection (conversation mode)
            // Note: don't guard on isListeningToUser — the teardown already set it false
            print("🎙️🔄 Silence detected — auto-sending: '\(transcript.prefix(80))'")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isListeningToUser = false
            }
            let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                HapticService.shared.micStop()
                
                // Check for goodbye words — end conversation after sending
                if isGoodbyeMessage(cleaned) {
                    sendToNudgy(cleaned)
                    // End conversation after this final exchange
                    Task {
                        // Wait for response to finish generating + speaking
                        try? await Task.sleep(for: .seconds(1.0))
                        while penguinState.isChatGenerating || NudgyVoiceOutput.shared.isSpeaking {
                            try? await Task.sleep(for: .seconds(0.5))
                        }
                        try? await Task.sleep(for: .seconds(0.5))
                        if isVoiceConversation {
                            endVoiceConversation()
                        }
                    }
                } else {
                    sendToNudgy(cleaned)
                }
            }
            
        case .emptySilence:
            // Long silence with no speech — end conversation
            guard isListeningToUser || isVoiceConversation else { return }
            print("🎙️🔄 Empty silence — ending conversation")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isListeningToUser = false
            }
            endVoiceConversation()
            // endVoiceConversation already shows the brain dump summary or goodbye message
            
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
            #if DEBUG
            // Show actual error in debug builds so we can diagnose
            penguinState.say("🔴 \(msg)", autoDismiss: 8.0)
            #else
            penguinState.say(
                String(localized: "Mic trouble — type below instead! 🐧"),
                autoDismiss: 3.0
            )
            #endif
            isInputFocused = true
            
            // End conversation mode on error
            if isVoiceConversation {
                endVoiceConversation()
            }
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
        print("💬 sendToNudgy: '\(text.prefix(80))' (conversation mode: \(isVoiceConversation))")

        // Ensure we're in chat mode
        if penguinState.interactionMode != .chatting {
            NudgyEngine.shared.startChat()
        }

        // Show thinking state immediately
        penguinState.expression = .thinking
        penguinState.say(String(localized: "Let me think..."), style: .thought, autoDismiss: nil)
        HapticService.shared.prepare()
        
        // In conversation mode, mark that we're waiting for TTS to finish
        if isVoiceConversation {
            awaitingTTSFinish = true
        }
        
        NudgyEngine.shared.chat(text, modelContext: modelContext)
    }

    // MARK: - Helpers
    
    /// Detect goodbye-style messages that should end the conversation loop
    private func isGoodbyeMessage(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let goodbyeWords = [
            "bye", "goodbye", "good bye", "see ya", "see you",
            "thanks", "thank you", "that's all", "thats all",
            "i'm done", "im done", "done", "nothing", "never mind",
            "nevermind", "night", "goodnight", "good night",
            "later", "talk later", "gotta go", "got to go"
        ]
        return goodbyeWords.contains(where: { lower.hasPrefix($0) || lower == $0 })
    }

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
