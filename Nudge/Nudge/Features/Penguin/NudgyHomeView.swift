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
    @Environment(\.selectedTab) private var selectedTab

    @State private var hasGreeted = false
    @State private var breatheAnimation = false
    @State private var inputText = ""
    @State private var isListeningToUser = false
    @State private var speechService = SpeechService()
    @State private var showHistory = false
    @FocusState private var isInputFocused: Bool
    // Wardrobe is now accessible via the unified inventory sheet
    @State private var showInventory = false
    @State private var isVoiceEnabled: Bool = NudgyConfig.Voice.isEnabled
    
    /// Whether we're in voice conversation mode (auto-listen → send → speak → auto-listen loop)
    @State private var isVoiceConversation = false
    /// Whether the current voice conversation is brain dump mode (task extraction) vs companion chat
    @State private var isBrainDumpVoice = false
    /// Tracks if we're waiting for Nudgy to finish speaking before auto-resuming
    @State private var awaitingTTSFinish = false
    
    /// Active task queue for the task bubble
    @State private var activeQueue: [NudgeItem] = []
    /// Fish HUD position for reward animation target
    @State private var fishHUDPosition: CGPoint = .zero
    
    /// Stage-up celebration overlay
    @State private var showStageUpCelebration = false
    @State private var stageUpTier: StageTier = .bareIce
    
    /// Fish sparkle effect on the HUD
    @State private var showFishSparkle = false
    
    // Option C: Fish pile munch when returning to penguin tab
    @State private var showFishPileMunch = false
    @State private var fishPileSpecies: FishSpecies? = nil
    
    /// Idle actions engine
    private let idleActions = NudgyIdleActions.shared
    
    /// Mood reactor for Nudgy expressions
    private let moodReactor = PenguinMoodReactor.shared


    var body: some View {
        ZStack {
            // OLED canvas + subtle ambient glow
            ambientBackground

            // Ambient swimming fish (behind Nudgy, on the ice shelf)
            ambientFishLayer

            VStack(spacing: 0) {
                // Conversation history (scrollable above Nudgy)
                if showHistory && !penguinState.chatMessages.isEmpty {
                    conversationHistory
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Top bar — mute + celestial button
                topBar
                    .padding(.horizontal, DesignTokens.spacingLG)

                // At-a-glance stats strip — always visible, minimal
                atAGlanceStats
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.top, DesignTokens.spacingSM)

                Spacer()

                // ★ Nudgy — the whole point, positioned on the ice cliff
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

                // Offset to seat Nudgy on the ice cliff platform
                Spacer()
                    .frame(maxHeight: 20)

                // Bottom action buttons removed — NudgyCaptureBar
                // is now the universal input surface on every tab.
                // Voice conversation + brain dump voice remain accessible
                // via the capture bar's mic button.
                
                // Spacer so Nudgy doesn't sit behind the capture bar
                Spacer()
                    .frame(height: 80)
            }
            .safeAreaPadding(.top, DesignTokens.spacingSM)

            // Fish reward animation overlay
            FishRewardOverlay()
            
            // Celebratory fish burst overlay (task completion)
            CompletionFishBurst()
            
            // Option C: Fish pile munch overlay (when returning with pending fish)
            if showFishPileMunch {
                NudgyPeekMunch(isActive: $showFishPileMunch, species: fishPileSpecies)
                    .allowsHitTesting(false)
                    .zIndex(50)
            }
            
            // Stage-up celebration overlay
            if showStageUpCelebration {
                StageUpCelebration(newStage: stageUpTier) {
                    showStageUpCelebration = false
                    RewardService.shared.acknowledgeStageUp()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .fullScreenCover(isPresented: $showInventory) {
            CelestialExpandedOverlay(
                isExpanded: $showInventory,
                level: RewardService.shared.level,
                fishCount: RewardService.shared.snowflakes,
                streak: RewardService.shared.currentStreak,
                levelProgress: RewardService.shared.levelProgress,
                tasksToday: RewardService.shared.tasksCompletedToday,
                totalCompleted: totalCompletedCount,
                activeCount: activeQueue.count,
                stage: StageTier.from(level: RewardService.shared.level),
                challenges: RewardService.shared.dailyChallenges
            )
            .environment(penguinState)
            .presentationBackground(.clear)
            .preferredColorScheme(.dark)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            greetIfNeeded()
            startBreathingAnimation()
            refreshActiveQueue()
            updateMoodReactor()
            // Start idle action engine
            idleActions.start(penguinState: penguinState)
            
            // Option C: Check for pending fish to munch
            checkPendingFishPile()
        }
        .onDisappear {
            idleActions.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeDataChanged)) { _ in
            refreshActiveQueue()
            updateMoodReactor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeStageUp)) { notification in
            if let newStage = notification.object as? StageTier {
                stageUpTier = newStage
                HapticService.shared.prepare()
                withAnimation(.spring(response: 0.4)) {
                    showStageUpCelebration = true
                }
                penguinState.expression = .celebrating
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: RewardConstants.challengeCompletedNotification)) { _ in
            // Nudgy reacts to challenge completion
            HapticService.shared.prepare()
        }
        .onChange(of: speechService.state) { _, newState in
            handleSpeechStateChange(newState)
        }
        .onChange(of: isVoiceConversation) { _, active in
            penguinState.isVoiceConversationActive = active
            speechService.silenceAutoSendEnabled = active
            if active {
                // Pause idle actions during conversation
                idleActions.stop()
            } else {
                awaitingTTSFinish = false
                // Resume idle actions after conversation
                idleActions.start(penguinState: penguinState)
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


    }

    // MARK: - Ambient Background

    private var ambientBackground: some View {
        GeometryReader { geo in
            ZStack {
                AntarcticEnvironment(
                    mood: RewardService.shared.environmentMood,
                    unlockedProps: RewardService.shared.unlockedProps,
                    fishCount: RewardService.shared.snowflakes,
                    level: RewardService.shared.level,
                    stage: StageTier.from(level: RewardService.shared.level),
                    sceneWidth: geo.size.width,
                    sceneHeight: geo.size.height,
                    isActive: selectedTab == .nudgy
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

    // MARK: - Home Weather Layer

    private var homeWeatherLayer: some View {
        let hour = Calendar.current.component(.hour, from: .now)
        let time: AntarcticTimeOfDay = {
            switch hour {
            case 5...7:   return .dawn
            case 8...17:  return .day
            case 18...20: return .dusk
            default:      return .night
            }
        }()
        return HomeWeatherOverlay(
            mood: RewardService.shared.environmentMood,
            timeOfDay: time
        )
    }

    // MARK: - Ambient Fish Layer

    private var ambientFishLayer: some View {
        GeometryReader { geo in
            AmbientFishScene(
                fishEarned: min(RewardService.shared.tasksCompletedToday, 6),
                sceneWidth: geo.size.width,
                sceneHeight: geo.size.height
            )
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    // MARK: - Nudgy Character (center of screen)

    private var nudgyCharacter: some View {
        ZStack {
            PenguinSceneView(
                size: .hero,
                onTap: {
                    moodReactor.userDidInteract()
                    // Tapping Nudgy during conversation = end conversation
                    if isVoiceConversation {
                        endVoiceConversation()
                    } else if isListeningToUser {
                        stopListening()
                    } else if penguinState.isChatGenerating {
                        // Nudgy is thinking — let the user know
                        HapticService.shared.prepare()
                    } else {
                        // Tap = companion conversation (just talk)
                        startCompanionConversation()
                    }
                },
                onChatTap: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showHistory.toggle()
                    }
                }
            )
            .shiverEffect(moodReactor.isShivering && !isListeningToUser && !isVoiceConversation)
            
            // Sleep z-bubbles when Nudgy is napping
            if moodReactor.isSleeping {
                SleepBubble()
                    .offset(x: 30, y: -60)
                    .transition(.opacity)
            }
            
            // Micro-reaction bubble (mood reactor)
            if let reaction = moodReactor.microReaction {
                Text(reaction)
                    .font(AppTheme.hintFont)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
                    .offset(y: -90)
                    .transition(.opacity.combined(with: .offset(y: 10)))
            }
        }
    }

    // MARK: - Listening Indicator

    private var listeningIndicator: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            // Waveform bars in a glass pill
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
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingSM)
            .glassEffect(.regular, in: .capsule)

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
                     ? String(localized: "brain unload — listening...")
                     : String(localized: "pause to send"))
                    .font(AppTheme.hintFont)
                    .foregroundStyle(DesignTokens.accentActive.opacity(0.6))
            } else {
                Text(String(localized: "tap Nudgy to send"))
                    .font(AppTheme.hintFont)
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
                    .fill(DesignTokens.accentActive.opacity(0.8))
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
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.vertical, DesignTokens.spacingSM)
        .glassEffect(.regular, in: .capsule)
        .padding(.top, DesignTokens.spacingSM)
    }
    
    // MARK: - Speaking Indicator (conversation mode — Nudgy is speaking)
    
    private var speakingIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.accentActive.opacity(0.8))
                .symbolEffect(.variableColor.iterative, isActive: true)
            
            Text(String(localized: "Nudgy is speaking..."))
                .font(AppTheme.hintFont)
                .foregroundStyle(DesignTokens.textSecondary)
        }
        .padding(.horizontal, DesignTokens.spacingLG)
        .padding(.vertical, DesignTokens.spacingSM)
        .glassEffect(.regular, in: .capsule)
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
                .glassEffect(.regular, in: .capsule)
        } else {
            HStack(alignment: .bottom, spacing: 6) {
                if message.role == .user { Spacer(minLength: 80) }

                // Tiny penguin avatar for Nudgy messages
                if message.role == .nudgy {
                    Text("🐧")
                        .font(.system(size: 12))
                        .frame(width: 20, height: 20)
                        .offset(y: -2)
                }

                Text(message.text)
                    .font(AppTheme.caption)
                    .foregroundStyle(
                        message.role == .user
                            ? DesignTokens.textPrimary
                            : DesignTokens.textSecondary
                    )
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .background {
                        if message.role == .user {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(DesignTokens.accentActive.opacity(0.1))
                        }
                    }
                    .glassEffect(
                        message.role == .user ? .regular.interactive() : .regular,
                        in: .rect(cornerRadius: 12)
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
                    // Stop any in-progress speech when muting
                    if !isVoiceEnabled {
                        NudgyVoiceOutput.shared.stop()
                    }
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

            // Celestial button (sun/moon) — expands into inventory overlay
            CelestialButton(
                isExpanded: $showInventory,
                fishCount: RewardService.shared.snowflakes,
                levelProgress: RewardService.shared.levelProgress
            )
        }
    }

    // MARK: - At-a-Glance Stats
    
    /// Compact, always-visible stats below the top bar.
    /// Shows daily progress, streak, and fish — just enough context without overwhelm.
    private var atAGlanceStats: some View {
        let done = RewardService.shared.tasksCompletedToday
        let active = activeQueue.count
        let total = done + active
        let streak = RewardService.shared.currentStreak
        let fish = RewardService.shared.snowflakes
        
        return HStack(spacing: DesignTokens.spacingLG) {
            // Daily progress — "2 done · 3 to go"
            HStack(spacing: 4) {
                if total > 0 {
                    Text("\(done)/\(total)")
                        .font(AppTheme.rounded(.caption2, weight: .bold))
                        .foregroundStyle(done > 0 ? DesignTokens.accentComplete : DesignTokens.textTertiary)
                    Text(String(localized: "done"))
                        .font(AppTheme.rounded(.caption2, weight: .medium))
                        .foregroundStyle(DesignTokens.textTertiary)
                } else {
                    Text(String(localized: "No tasks yet"))
                        .font(AppTheme.rounded(.caption2, weight: .medium))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            
            if streak > 0 {
                HStack(spacing: 2) {
                    FlameIcon(size: 10)
                    Text("\(streak)")
                        .font(AppTheme.rounded(.caption2, weight: .bold))
                        .foregroundStyle(streak >= 3 ? DesignTokens.streakOrange : DesignTokens.textTertiary)
                }
            }
            
            if fish > 0 {
                HStack(spacing: 2) {
                    MiniFishIcon(size: 10, species: nil)
                    Text("\(fish)")
                        .font(AppTheme.rounded(.caption2, weight: .bold))
                        .foregroundStyle(DesignTokens.goldCurrency)
                }
            }
            
            Spacer()
        }
        .opacity(0.8)
        .nudgeAccessibility(
            label: String(localized: "\(done) of \(total) tasks done, \(streak) day streak, \(fish) fish"),
            hint: String(localized: "Your daily progress at a glance"),
            traits: .isStaticText
        )
    }

    // MARK: - Voice Conversation Loop
    
    /// Curated companion greetings — warm, not task-focused
    private static let companionGreetings: [String] = [
        "Hey! What's up?",
        "I'm here. What's on your mind?",
        "*looks up* Hey!",
        "Talk to me!",
        "I'm listening.",
    ]
    
    /// Build a companion greeting that may reference something Nudgy remembers.
    /// 40% chance of a memory callback if facts exist — makes it feel like continuity.
    private func companionGreetingWithMemory() -> String {
        let memory = NudgyMemory.shared
        let facts = memory.store.facts
        
        // 40% chance to use a memory callback, if we have facts
        if !facts.isEmpty, Double.random(in: 0...1) < 0.4 {
            let fact = facts.randomElement()!
            
            // Soft references, not "I REMEMBER THAT YOU..."
            if let name = memory.userName {
                return String(localized: "Hey, \(name). 💙")
            } else if fact.category == .personal {
                return String(localized: "*remembers* …Hey. I was thinking about you 🐧")
            } else if fact.category == .emotional {
                return String(localized: "Hey. …How are you doing? 💙")
            } else {
                return String(localized: "*perks up* Oh! Hey 🐧")
            }
        }
        
        return Self.companionGreetings.randomElement() ?? "Hey!"
    }
    
    /// Curated brain dump greetings — task-extraction focused
    private static let brainDumpGreetings: [String] = [
        "Unload time! Tell me everything!",
        "Let it all out! I'll catch every task!",
        "Brain dump mode! Just talk, I'll sort it!",
        "Ready! Say everything, I'll organize it!",
    ]
    
    /// Start or stop voice conversation mode
    private func toggleVoiceConversation() {
        if isVoiceConversation {
            endVoiceConversation()
        } else {
            startCompanionConversation()
        }
    }
    
    /// Begin companion voice conversation — just talk to Nudgy, no forced task extraction.
    /// Mic starts IMMEDIATELY — no TTS greeting delay.
    private func startCompanionConversation() {
        print("🎙️🔄 Starting companion voice conversation")
        isVoiceConversation = true
        isBrainDumpVoice = false
        speechService.silenceAutoSendEnabled = true
        HapticService.shared.micStart()
        SoundService.shared.playMicStart()
        
        // Show a brief text bubble — NO TTS for the greeting (instant start)
        let greeting = companionGreetingWithMemory()
        penguinState.expression = .listening
        penguinState.say(greeting, style: .speech, autoDismiss: 2.0)
        
        // Start listening immediately — no waiting for TTS
        startListening()
    }
    
    /// Begin brain dump voice conversation — task extraction mode with specialized prompt.
    private func startBrainDumpVoice() {
        print("🎙️🔄 Starting brain dump voice conversation")
        isVoiceConversation = true
        isBrainDumpVoice = true
        speechService.silenceAutoSendEnabled = true
        HapticService.shared.micStart()
        
        // Initialize brain dump conversation with specialized system prompt
        NudgyEngine.shared.startBrainDumpConversation(modelContext: modelContext)
        
        // Show brain dump greeting as text only — start mic right away
        let greeting = Self.brainDumpGreetings.randomElement() ?? "Unload time!"
        penguinState.expression = .listening
        penguinState.say(greeting, style: .speech, autoDismiss: 2.5)
        
        // Start listening immediately
        startListening()
    }
    
    /// End voice conversation mode — stop everything
    private func endVoiceConversation() {
        print("🎙️🔄 Ending voice conversation mode (brainDump=\(isBrainDumpVoice))")
        let wasBrainDump = isBrainDumpVoice
        
        isVoiceConversation = false
        isBrainDumpVoice = false
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
        
        if wasBrainDump {
            // End brain dump conversation and get summary
            let tasksCreated = NudgyEngine.shared.endBrainDumpConversation()
            
            penguinState.expression = .happy
            
            if tasksCreated > 0 {
                let summary: String
                if tasksCreated == 1 {
                    summary = String(localized: "All unloaded! Captured 1 task — go check your nudges! 🐧✨")
                } else {
                    summary = String(localized: "All unloaded! Captured \(tasksCreated) tasks — they're all in your nudges! 🐧🎉")
                }
                penguinState.say(summary, style: .announcement, autoDismiss: 5.0)
                NudgyVoiceOutput.shared.speak(summary)
                NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
            } else {
                // Brain dump with no tasks — gentle, not transactional
                let msg = String(localized: "Sometimes you just need to talk it out. I'm always here 💙")
                penguinState.say(msg, autoDismiss: 3.5)
            }
        } else {
            // Companion conversation end — warm goodbye
            NudgyEngine.shared.conversation.endConversation()
            penguinState.expression = .happy
            let goodbyes = [
                "Talk anytime. I'm right here 🐧",
                "*quiet nod* I'll be on my iceberg 💙",
                "See you soon 🧊",
                "I'm here whenever. …Always 🐧",
            ]
            let goodbye = goodbyes.randomElement()!
            penguinState.say(goodbye, autoDismiss: 3.0)
        }
        
        // Return to idle after a moment
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            if self.penguinState.expression == .happy || self.penguinState.expression == .waving {
                self.penguinState.expression = .idle
                self.penguinState.interactionMode = .ambient
            }
            // Resume idle actions
            self.idleActions.start(penguinState: self.penguinState)
        }
    }

    private func startListening() {
        // Ensure chat mode so responses go through AI
        if penguinState.interactionMode != .chatting {
            penguinState.startChatting()
        }

        // For single-mic-tap mode (non-conversation), show a brief greeting
        if !isVoiceConversation {
            penguinState.say("I'm listening…", style: .speech, autoDismiss: 2.0)
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

    /// Smart micro-reactions — instant contextual acknowledgment while AI is thinking.
    /// Replaces the generic "Let me think..." with something that shows Nudgy heard you.
    private static let thinkingReactions: [(keywords: [String], reactions: [String])] = [
        (["tired", "exhausted", "drained", "burnt", "can't"],
         ["*sits closer* …", "Mmm. I hear you…", "Hey… 💙"]),
        (["stressed", "overwhelm", "anxious", "worry", "scared"],
         ["*quiet nod*", "I'm here…", "Breathe… 💙"]),
        (["happy", "great", "awesome", "good", "nice", "excited"],
         ["Oh! 🐧", "*perks up*", "Ooh…"]),
        (["help", "how do", "what should", "can you"],
         ["Hmm…", "*tilts head*", "Let me see…"]),
        (["add", "create", "remind", "need to", "gotta", "have to"],
         ["*grabs notepad*", "On it…", "📝"]),
    ]
    
    /// Pick a contextual micro-reaction based on what the user said.
    private func microReaction(for text: String) -> String {
        let lower = text.lowercased()
        for (keywords, reactions) in Self.thinkingReactions {
            if keywords.contains(where: { lower.contains($0) }) {
                return reactions.randomElement()!
            }
        }
        // Default gentle acknowledgment
        return ["Mmm…", "*nods*", "Hmm…", "…"].randomElement()!
    }
    
    /// Core send — works for both voice and text input.
    /// Nudgy responds via speech bubble + spoken voice (NOT chat bubbles).
    /// Routes through NudgyEngine for OpenAI-powered conversation with memory.
    private func sendToNudgy(_ text: String) {
        print("💬 sendToNudgy: '\(text.prefix(80))' (conversation mode: \(isVoiceConversation), brainDump: \(isBrainDumpVoice))")

        // Ensure we're in chat mode
        if penguinState.interactionMode != .chatting {
            NudgyEngine.shared.startChat()
        }

        // ADHD: Detect mood from user's text and adjust penguin expression
        let mood = NudgyEngine.shared.detectMood(from: text)
        switch mood {
        case .overwhelmed, .anxious, .sad:
            penguinState.expression = .confused
        case .frustrated:
            penguinState.expression = .confused
        case .positive, .neutral:
            penguinState.expression = .thinking
        }

        // Show instant micro-reaction instead of generic "Let me think..."
        let reaction = microReaction(for: text)
        penguinState.say(reaction, style: .thought, autoDismiss: nil)
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

        // Record activity timestamp
        settings.recordActivity()
        
        // ── ONE smart greeting that weaves in context ──
        // Instead of 8 queued bubbles, build one rich greeting.
        NudgyEngine.shared.greet(
            userName: settings.userName,
            activeTaskCount: activeQueue.count,
            overdueCount: overdueCount,
            staleCount: staleCount,
            doneToday: doneToday
        )
        
        // ── At most ONE follow-up (delayed, not queued on top of greeting) ──
        Task {
            try? await Task.sleep(for: .seconds(6))
            guard self.penguinState.interactionMode != .chatting,
                  !self.isVoiceConversation else { return }
            
            // Priority: welcome-back > streak > memory callback > evening review > check-in
            // Only show ONE of these.
            if let welcomeBack = NudgyEngine.shared.welcomeBack(settings: settings, activeQueue: activeQueue) {
                penguinState.say(welcomeBack, style: .speech, autoDismiss: 5.0)
                return
            }
            
            let streak = RewardService.shared.currentStreak
            if streak >= 3, let streakMsg = NudgyEngine.shared.streakMessage(days: streak) {
                penguinState.say(streakMsg, style: .whisper, autoDismiss: 4.0)
                return
            }
            
            // Memory callback — reference something Nudgy remembers
            // Only once every ~3 opens to avoid being creepy
            if let memoryLine = self.memoryFollowUp() {
                penguinState.say(memoryLine, style: .whisper, autoDismiss: 5.0)
                return
            }
            
            let hour = Calendar.current.component(.hour, from: .now)
            if hour >= 20 {
                let review = ProactiveNudgyService.generateEveningReview(modelContext: modelContext)
                if review.completed > 0 || review.remaining > 0 {
                    penguinState.say(review.moodNote, style: .speech, autoDismiss: 6.0)
                    return
                }
            }
            
            // Emotional check-in (only if nothing else was shown)
            if NudgyEngine.shared.shouldCheckIn {
                if let checkIn = await NudgyEngine.shared.emotionalCheckIn() {
                    penguinState.say(checkIn, style: .speech, autoDismiss: 6.0)
                }
            }
        }
    }

    /// Occasionally surface a memory fact as a gentle follow-up.
    /// Returns nil most of the time — only fires ~30% when facts exist.
    private func memoryFollowUp() -> String? {
        let memory = NudgyMemory.shared
        let facts = memory.store.facts
        guard !facts.isEmpty else { return nil }
        
        // Only fire ~30% of the time so it doesn't feel formulaic
        guard Double.random(in: 0...1) < 0.30 else { return nil }
        
        // Pick a random fact and build a soft reference
        guard let fact = facts.randomElement() else { return nil }
        
        switch fact.category {
        case .personal:
            if let name = memory.userName {
                return String(localized: "I was thinking… it's nice knowing your name, \(name) 🐧")
            }
            return String(localized: "*adjusts scarf* …I remember things about you, you know 💙")
        case .preference:
            return String(localized: "I've been noticing your patterns. …Not in a creepy way. I'm a penguin 🧊")
        case .emotional:
            return String(localized: "Hey. …Just wanted to check — how are you really doing? 💙")
        case .behavioral:
            return String(localized: "I notice things. …Like how you use this app. It's kind of nice 🐧")
        case .contextual:
            return String(localized: "*sits closer* …I feel like I know you a little better now 💙")
        }
    }

    private func startBreathingAnimation() {
        breatheAnimation = true
    }

    // MARK: - Active Task Queue

    private func refreshActiveQueue() {
        let repo = NudgeRepository(modelContext: modelContext)
        activeQueue = repo.fetchActiveQueue()
    }

    /// Total lifetime completed count for inventory display
    private var totalCompletedCount: Int {
        let repo = NudgeRepository(modelContext: modelContext)
        return repo.completedCount()
    }

    /// Update the mood reactor with the current environment state.
    private func updateMoodReactor() {
        // Determine time of day
        let hour = Calendar.current.component(.hour, from: .now)
        let time: AntarcticTimeOfDay
        switch hour {
        case 5...7:   time = .dawn
        case 8...17:  time = .day
        case 18...20: time = .dusk
        default:      time = .night
        }

        // Check for overdue tasks
        let hasOverdue = activeQueue.contains { $0.accentStatus == .overdue }

        // Determine if user is actively interacting
        let isActive = isListeningToUser || isVoiceConversation || penguinState.isChatGenerating

        moodReactor.update(
            mood: RewardService.shared.environmentMood,
            timeOfDay: time,
            streak: RewardService.shared.currentStreak,
            fishCount: RewardService.shared.snowflakes,
            tasksToday: RewardService.shared.tasksCompletedToday,
            isUserActive: isActive
        )

        // Apply mood-recommended expression only when in ambient mode
        if penguinState.interactionMode == .ambient && !isActive {
            penguinState.expression = moodReactor.recommendedExpression
        }
    }

    // MARK: - Option C: Fish Pile Munch
    
    /// When the user navigates to the penguin tab with pending fish, Nudgy munches them.
    private func checkPendingFishPile() {
        guard penguinState.pendingFishToMunch > 0 else { return }
        
        // Determine the species to show (use last catch or default to catfish)
        fishPileSpecies = RewardService.shared.lastFishCatch?.species ?? .catfish
        
        // Delay slightly so the view is settled before animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Trigger the munch
            showFishPileMunch = true
            
            // Nudgy reacts happily
            penguinState.expression = .celebrating
            
            // Show dialogue about the fish
            let count = penguinState.pendingFishToMunch
            let message: String
            if count == 1 {
                message = String(localized: "Yum! 🐟 Thanks for the fish!")
            } else {
                message = String(localized: "Yum! 🐟×\(count) That's a feast!")
            }
            penguinState.say(message)
            
            // Clear the pile
            penguinState.pendingFishToMunch = 0
            
            // Return to ambient after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if penguinState.interactionMode == .ambient {
                    penguinState.expression = .happy
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NudgyHomeView()
        .modelContainer(for: [NudgeItem.self, BrainDump.self], inMemory: true)
        .environment(AppSettings())
        .environment(PenguinState())
}
