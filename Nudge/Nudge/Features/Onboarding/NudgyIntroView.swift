//
//  NudgyIntroView.swift
//  Nudge
//
//  Interactive animated intro journey — Nudgy's mountain adventure.
//  ~60-90 seconds, 6 tap-to-advance scenes with typewriter dialogue,
//  parallax mountain backdrop, and Nudgy's fish-obsessed personality.
//
//  Inspired by Tiimo/Focus Friends onboarding — narrative-first,
//  character-driven, ADHD-friendly (skippable, short scenes).
//
//  Scene Flow:
//    1. Emerge    — Landscape fades in, Nudgy appears, "Heyy!"
//    2. Journey   — Nudgy walks, "I'm climbing this mountain..."
//    3. Fish      — Fish reward explanation, "We earn fish together!"
//    4. Beanie    — Accessory reveal, "I just got this beanie!"
//    5. Together  — "I'll nudge you gently..."
//    6. Launch    — CTA, "Let's climb!"
//

import SwiftUI
import AuthenticationServices

// MARK: - Scene Definition

private enum IntroScene: Int, CaseIterable {
    case emerge = 0
    case journey
    case fish
    case beanie
    case together
    case launch
    
    var mood: LandscapeMood {
        switch self {
        case .emerge:   return .night
        case .journey:  return .night
        case .fish:     return .golden
        case .beanie:   return .dawn
        case .together: return .dawn
        case .launch:   return .summit
        }
    }
    
    var nudgyExpression: PenguinExpression {
        switch self {
        case .emerge:   return .waving
        case .journey:  return .happy
        case .fish:     return .celebrating
        case .beanie:   return .thumbsUp
        case .together: return .listening
        case .launch:   return .happy
        }
    }
    
    /// Nudgy's position on screen (fraction from left edge).
    var nudgyX: CGFloat {
        switch self {
        case .emerge:   return 0.5
        case .journey:  return 0.6
        case .fish:     return 0.5
        case .beanie:   return 0.5
        case .together: return 0.4
        case .launch:   return 0.5
        }
    }
    
    /// Cinematic scene label shown briefly during transitions.
    var sceneLabel: String? {
        switch self {
        case .emerge:   return nil  // No label for first scene
        case .journey:  return String(localized: "The Journey")
        case .fish:     return String(localized: "The Fish")
        case .beanie:   return String(localized: "The Loot")
        case .together: return String(localized: "The Deal")
        case .launch:   return nil  // Sign-in scene — no label
        }
    }
    
    /// Dialogue lines for each scene. Each string appears in sequence.
    var dialogueLines: [String] {
        switch self {
        case .emerge:
            return [
                String(localized: "Heyy! You made it!"),
                String(localized: "I'm Nudgy. This mountain behind me? That's home."),
            ]
        case .journey:
            return [
                String(localized: "I've been climbing to the top for a while now..."),
                String(localized: "It's way more fun with a buddy. Wanna come?"),
            ]
        case .fish:
            return [
                String(localized: "Oh wait — I should tell you about the fish."),
                String(localized: "Every time you finish something, we earn fish together!"),
                String(localized: "I think about fish a completely normal amount."),
            ]
        case .beanie:
            return [
                String(localized: "Sometimes I trade fish with friends for cool stuff..."),
                String(localized: "Look what I got! Pretty fresh, right?"),
            ]
        case .together:
            return [
                String(localized: "Here's how I work — I'll give you a gentle nudge."),
                String(localized: "No overwhelming lists. Just one thing at a time."),
                String(localized: "Your brain does enough already. I got the rest."),
            ]
        case .launch:
            return [
                String(localized: "Alright, the summit's waiting. Let's climb!"),
            ]
        }
    }
}

// MARK: - NudgyIntroView

struct NudgyIntroView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AuthSession.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var currentScene: IntroScene = .emerge
    @State private var currentDialogueIndex: Int = 0
    @State private var dialogueComplete: Bool = false
    @State private var sceneReady: Bool = false
    @State private var nudgyVisible: Bool = false
    @State private var nudgyScale: CGFloat = 0.3
    @State private var landscapeReveal: CGFloat = 0
    @State private var showFishBurst: Bool = false
    @State private var showBeanie: Bool = false
    @State private var showSkip: Bool = false
    @State private var nudgyWalkOffset: CGFloat = 0
    @State private var nudgyBounce: CGFloat = 0
    @State private var isSigningIn: Bool = false
    @State private var breatheScale: CGFloat = 1.0
    @State private var sceneTitle: String = ""
    @State private var showSceneTitle: Bool = false
    @State private var squashStretch: CGSize = CGSize(width: 1.0, height: 1.0)
    @State private var headTilt: Double = 0
    @State private var nudgyY: CGFloat = 0
    @State private var beanieWiggle: Double = 0
    
    // Animation coordination
    @State private var transitionTask: Task<Void, Never>?
    
    /// Pixar-style bouncy spring — snappy with slight overshoot.
    private var springAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.45, dampingFraction: 0.72, blendDuration: 0.1)
    }
    
    /// Heavy spring for character body (more mass = more follow-through).
    private var characterSpring: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.55, dampingFraction: 0.65, blendDuration: 0.15)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Layer 0: Mountain landscape backdrop — tappable to advance scenes
                MountainLandscape(
                    revealProgress: landscapeReveal,
                    mood: currentScene.mood,
                    showGlow: nudgyVisible
                )
                .animation(.easeInOut(duration: 1.2), value: currentScene.mood)
                .contentShape(Rectangle())
                .allowsHitTesting(!(currentScene == .launch && dialogueComplete))
                .onTapGesture { handleTap() }
                
                // Layer 1: Nudgy character
                nudgyCharacter(in: geo)
                    .allowsHitTesting(false) // Taps pass through to backdrop
                
                // Layer 2: Dialogue + UI overlay
                VStack(spacing: 0) {
                    // Skip button
                    topBar
                    
                    Spacer()
                        .contentShape(Rectangle())
                        .allowsHitTesting(!(currentScene == .launch && dialogueComplete))
                        .onTapGesture { handleTap() }
                    
                    // Dialogue bubble — disable tap on launch scene when sign-in is showing
                    dialogueArea
                        .padding(.bottom, DesignTokens.spacingXL)
                        .allowsHitTesting(!(currentScene == .launch && dialogueComplete))
                        .onTapGesture { handleTap() }
                    
                    // Bottom area: tap-to-continue indicator (non-launch scenes)
                    bottomArea
                        .padding(.bottom, geo.safeAreaInsets.bottom + DesignTokens.spacingXXL)
                }
                .padding(.horizontal, DesignTokens.spacingLG)
                
                // Layer 3: Fish burst overlay
                if currentScene == .fish {
                    FishBurst(trigger: showFishBurst)
                        .offset(y: -geo.size.height * 0.05)
                        .allowsHitTesting(false)
                }
                
                // Layer 4: Shooting stars (night/dawn moods)
                if currentScene.mood == .night || currentScene.mood == .dawn {
                    Group {
                        ShootingStar(startX: 0.75, startY: 0.08)
                        ShootingStar(startX: 0.55, startY: 0.15)
                    }
                    .allowsHitTesting(false)
                }
                
                // Layer 5: Gentle snowfall — never blocks taps
                SnowfallView(intensity: currentScene == .launch ? 0.7 : 0.3)
                    .opacity(landscapeReveal > 0.5 ? 1 : 0)
                    .animation(.easeIn(duration: 1.0), value: landscapeReveal)
                    .allowsHitTesting(false)
                
                // Layer 5.5: Scene title card (cinematic chapter marker)
                if showSceneTitle {
                    VStack(spacing: 4) {
                        // Decorative line
                        RoundedRectangle(cornerRadius: 1)
                            .fill(.white.opacity(0.15))
                            .frame(width: 32, height: 2)
                        
                        Text(sceneTitle)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .tracking(4)
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.4))
                        
                        RoundedRectangle(cornerRadius: 1)
                            .fill(.white.opacity(0.15))
                            .frame(width: 32, height: 2)
                    }
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.85)),
                            removal: .opacity.combined(with: .scale(scale: 1.1))
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 110)
                    .allowsHitTesting(false)
                }
                
                // Layer 6: Scene progress dots
                sceneProgressDots
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, geo.safeAreaInsets.bottom + DesignTokens.spacingSM)
                    .allowsHitTesting(false)
                
                // Layer 7: Sign In with Apple — TOPMOST in Z-order
                // Placed outside all animated containers so the UIKit button
                // has a direct presentation anchor to the window
                if currentScene == .launch && dialogueComplete {
                    VStack {
                        Spacer()
                        launchActions
                            .padding(.bottom, geo.safeAreaInsets.bottom + DesignTokens.spacingXXL)
                            .padding(.horizontal, DesignTokens.spacingLG)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear { beginIntro() }
        .onDisappear {
            transitionTask?.cancel()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Spacer()
            if showSkip {
                Button {
                    if currentScene == .launch {
                        // Already on sign-in scene — fast-forward dialogue so button appears
                        dialogueComplete = true
                        currentDialogueIndex = currentScene.dialogueLines.count - 1
                        sceneReady = true
                    } else {
                        skipToSignIn()
                    }
                } label: {
                    Text(String(localized: "Skip"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM)
                }
                .transition(.opacity)
            }
        }
        .frame(height: 56)
        .padding(.top, DesignTokens.spacingXXL)
        .animation(.easeOut(duration: 0.3), value: showSkip)
    }
    
    // MARK: - Nudgy Character
    
    private func nudgyCharacter(in geo: GeometryProxy) -> some View {
        let centerY = geo.size.height * 0.42
        let centerX = geo.size.width * currentScene.nudgyX
        
        return ZStack {
            // Scene-specific floating vector icons (behind Nudgy for depth)
            sceneFloatingIcons
            
            // Nudgy body with squash/stretch deformation
            PenguinMascot(
                expression: currentScene.nudgyExpression,
                size: 160,
                accentColor: DesignTokens.accentActive
            )
            .id(currentScene.rawValue)
            .scaleEffect(x: squashStretch.width, y: squashStretch.height, anchor: .bottom)
            .rotationEffect(.degrees(headTilt), anchor: .bottom)
            
            // Beanie sits on Nudgy's head — overlapping action (lags behind head)
            // Sized to match head width (head = p*0.605 = ~97pt at size 160)
            // Positioned so cuff hugs the crown of the elliptical head
            if showBeanie {
                BeanieView(size: 56)
                    .offset(y: -82)
                    .rotationEffect(.degrees(beanieWiggle), anchor: .bottom)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.05, anchor: .bottom)
                            .combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .scaleEffect(nudgyScale * breatheScale)
        .offset(x: nudgyWalkOffset, y: nudgyBounce + nudgyY)
        .opacity(nudgyVisible ? 1.0 : 0.0)
        .position(x: centerX, y: centerY)
        .animation(characterSpring, value: currentScene.nudgyX)
        .animation(characterSpring, value: nudgyScale)
        .animation(characterSpring, value: squashStretch.width)
        .animation(characterSpring, value: squashStretch.height)
        .animation(springAnimation, value: nudgyVisible)
        .animation(.spring(response: 0.5, dampingFraction: 0.55), value: showBeanie)
        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: headTilt)
        .animation(characterSpring, value: nudgyY)
    }
    
    // MARK: - Scene Floating Icons
    
    /// Decorative vector icons that float around Nudgy per scene.
    @ViewBuilder
    private var sceneFloatingIcons: some View {
        switch currentScene {
        case .emerge:
            // Mountain + star icons
            FloatingSceneIcons(icons: [
                (name: "mountain.2.fill", color: Color(hex: "90A8C8")),
                (name: "sparkle", color: .white),
                (name: "moon.stars.fill", color: Color(hex: "C8D8F0")),
            ], spread: 90)
            .opacity(sceneReady ? 1 : 0)
            .animation(.easeOut(duration: 0.8), value: sceneReady)
            
        case .journey:
            // Footsteps + path icons
            FloatingSceneIcons(icons: [
                (name: "figure.walk", color: Color(hex: "A0C4E8")),
                (name: "arrow.up.forward", color: Color(hex: "90A8C8")),
                (name: "flag.fill", color: Color(hex: "FFD54F")),
            ], spread: 85)
            .opacity(sceneReady ? 1 : 0)
            .animation(.easeOut(duration: 0.8), value: sceneReady)
            
        case .fish:
            // Vector fish swim around
            ZStack {
                FishView(size: 28, color: Color(hex: "4FC3F7"))
                    .offset(x: -60, y: -30)
                    .rotationEffect(.degrees(-15))
                FishView(size: 22, color: Color(hex: "FF8A65"))
                    .offset(x: 55, y: -50)
                    .scaleEffect(x: -1, y: 1)
                    .rotationEffect(.degrees(10))
                FishView(size: 18, color: Color(hex: "81C784"))
                    .offset(x: 45, y: 35)
                    .rotationEffect(.degrees(-5))
            }
            .opacity(sceneReady ? 0.6 : 0)
            .animation(.easeOut(duration: 0.8), value: sceneReady)
            
        case .beanie:
            // Gift / sparkle icons
            FloatingSceneIcons(icons: [
                (name: "gift.fill", color: Color(hex: "FF6B8A")),
                (name: "sparkles", color: Color(hex: "FFD54F")),
                (name: "heart.fill", color: Color(hex: "FF6B8A").opacity(0.6)),
            ], spread: 80)
            .opacity(sceneReady ? 1 : 0)
            .animation(.easeOut(duration: 0.8), value: sceneReady)
            
        case .together:
            // Brain / gentle icons
            FloatingSceneIcons(icons: [
                (name: "brain.filled.head.profile", color: Color(hex: "CE93D8")),
                (name: "hand.point.up.fill", color: Color(hex: "A0C4E8")),
                (name: "checkmark.circle.fill", color: Color(hex: "81C784")),
            ], spread: 85)
            .opacity(sceneReady ? 1 : 0)
            .animation(.easeOut(duration: 0.8), value: sceneReady)
            
        case .launch:
            // Summit sparkles
            ZStack {
                SparkleView(size: 18, color: Color(hex: "FFD54F"), delay: 0)
                    .offset(x: -50, y: -40)
                SparkleView(size: 14, color: .white, delay: 0.3)
                    .offset(x: 55, y: -55)
                SparkleView(size: 20, color: Color(hex: "4FC3F7"), delay: 0.6)
                    .offset(x: 40, y: 25)
                SparkleView(size: 12, color: Color(hex: "FF6B8A"), delay: 0.9)
                    .offset(x: -45, y: 30)
            }
            .opacity(sceneReady ? 1 : 0)
            .animation(.easeOut(duration: 0.8), value: sceneReady)
        }
    }
    
    // MARK: - Dialogue Area
    
    private var dialogueArea: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            let lines = currentScene.dialogueLines
            if currentDialogueIndex < lines.count && sceneReady {
                IntroDialogueBubble(
                    text: lines[currentDialogueIndex],
                    expression: currentScene.nudgyExpression,
                    typingSpeed: 0.032,
                    maxWidth: 320,
                    onTypingComplete: {
                        dialogueComplete = true
                    }
                )
                .id("\(currentScene.rawValue)-\(currentDialogueIndex)") // Force new bubble per line
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.85, anchor: .bottom)),
                    removal: .opacity
                ))
            }
        }
        .frame(height: 140) // Fixed height to prevent layout jumps
        .animation(springAnimation, value: currentDialogueIndex)
        .animation(springAnimation, value: currentScene)
    }
    
    // MARK: - Bottom Area
    
    private var bottomArea: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            if currentScene != .launch && dialogueComplete {
                TapToContinue(visible: true)
            }
        }
        .frame(minHeight: 80)
    }
    
    // MARK: - Launch Actions (Sign In with Apple)
    
    private var launchActions: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            // App title reveal
            VStack(spacing: 6) {
                Text("nudge")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(1.5)
                
                Text(String(localized: "One thing at a time"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            
            // Sign In with Apple
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleSignIn(result: result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(isSigningIn)
            .overlay {
                if isSigningIn {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                    ProgressView()
                        .tint(.black)
                }
            }
            
            // Privacy reassurance
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                Text(String(localized: "Your data stays on your device"))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.25))
        }
        .padding(.horizontal, DesignTokens.spacingXL)
    }
    
    // MARK: - Apple Sign In Handler
    
    private func handleAppleSignIn(result: Result<ASAuthorization, any Error>) {
        switch result {
        case .success(let authorization):
            guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential else {
                #if DEBUG
                print("🍎 Sign In: success but no ASAuthorizationAppleIDCredential")
                #endif
                return
            }
            #if DEBUG
            print("🍎 Sign In: got credential, user=\(cred.user.prefix(8))...")
            #endif
            isSigningIn = true
            HapticService.shared.swipeDone()
            
            Task {
                await auth.completeAppleSignIn(with: cred)
                
                // Auth succeeded — mark intro done (triggers routing to onboarding/main)
                withAnimation(.easeOut(duration: 0.4)) {
                    settings.hasSeenIntro = true
                }
            }
            
        case .failure(let error):
            #if DEBUG
            print("🍎 Sign In FAILED: \(error.localizedDescription)")
            #endif
            // User cancelled or error — stay on the intro, do nothing
            break
        }
    }
    
    // MARK: - Scene Progress Dots
    
    private var sceneProgressDots: some View {
        HStack(spacing: 6) {
            ForEach(IntroScene.allCases, id: \.rawValue) { scene in
                Capsule()
                    .fill(scene == currentScene ? .white.opacity(0.8) : .white.opacity(0.2))
                    .frame(
                        width: scene == currentScene ? 20 : 6,
                        height: 6
                    )
                    .animation(springAnimation, value: currentScene)
            }
        }
    }
    
    // MARK: - Scene Orchestration
    
    private func beginIntro() {
        showSkip = false
        
        // Start hidden below the snow line
        nudgyY = 40
        squashStretch = CGSize(width: 1.0, height: 0.6) // Pre-squashed
        
        transitionTask = Task { @MainActor in
            // Phase 1: Landscape reveals
            withAnimation(.easeInOut(duration: 2.2)) {
                landscapeReveal = 1.0
            }
            
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            
            // Phase 2: Nudgy pops up — anticipation squash then stretch upward
            nudgyVisible = true
            nudgyScale = 0.5
            
            // Stretch as Nudgy shoots up
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                nudgyScale = 1.05
                nudgyY = -8  // Overshoot above resting position
                squashStretch = CGSize(width: 0.88, height: 1.15) // Stretch tall
            }
            
            HapticService.shared.cardAppear()
            
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }
            
            // Phase 3: Squash on landing
            withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) {
                nudgyY = 2  // Compress down past rest
                squashStretch = CGSize(width: 1.12, height: 0.88) // Squash wide
                nudgyScale = 1.0
            }
            
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            
            // Phase 4: Settle to rest with slight tilt (personality!)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                nudgyY = 0
                squashStretch = CGSize(width: 1.0, height: 1.0)
                headTilt = 3 // Slight curious tilt
            }
            
            try? await Task.sleep(for: .seconds(0.25))
            guard !Task.isCancelled else { return }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                headTilt = 0 // Straighten up
            }
            
            // Start idle breathing animation
            startBreathingAnimation()
            
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            
            // Start first dialogue
            sceneReady = true
            dialogueComplete = false
            
            // Show skip quickly — ADHD users shouldn't have to wait
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            withAnimation { showSkip = true }
        }
    }
    
    private func handleTap() {
        let lines = currentScene.dialogueLines
        
        if !dialogueComplete {
            // Typing is in progress — the TypewriterText handles its own tap-to-complete
            // But we also want the full-screen tap to work
            dialogueComplete = true
            return
        }
        
        // Dialogue is complete — advance
        if currentDialogueIndex < lines.count - 1 {
            // More lines in this scene
            advanceDialogue()
        } else {
            // All lines done — advance scene
            advanceScene()
        }
    }
    
    private func advanceDialogue() {
        dialogueComplete = false
        withAnimation(springAnimation) {
            currentDialogueIndex += 1
        }
        HapticService.shared.actionButtonTap()
        
        // Nudgy nods — subtle bounce to acknowledge new dialogue line
        guard !reduceMotion else { return }
        Task { @MainActor in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) {
                nudgyBounce = -4
                squashStretch = CGSize(width: 0.96, height: 1.04)
            }
            try? await Task.sleep(for: .seconds(0.12))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                nudgyBounce = 0
                squashStretch = CGSize(width: 1.0, height: 1.0)
            }
        }
    }
    
    private func advanceScene() {
        guard let nextScene = IntroScene(rawValue: currentScene.rawValue + 1) else {
            // Already at last scene — CTA button handles exit
            return
        }
        
        transitionTask?.cancel()
        transitionTask = Task { @MainActor in
            HapticService.shared.actionButtonTap()
            
            // ── ANTICIPATION: Nudgy dips down (preparing to jump/exit) ──
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                squashStretch = CGSize(width: 1.1, height: 0.85)
                nudgyY = 4
                headTilt = 0
            }
            
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            
            // ── EXIT: Stretch up and shrink away ──
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                nudgyScale = 0.4
                nudgyY = -20
                squashStretch = CGSize(width: 0.8, height: 1.3)
            }
            
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }
            
            // ── SCENE CHANGE ──
            withAnimation(.easeInOut(duration: 0.5)) {
                currentScene = nextScene
                currentDialogueIndex = 0
                dialogueComplete = false
                sceneReady = false
            }
            
            // Flash scene title card
            if let label = nextScene.sceneLabel {
                sceneTitle = label
                withAnimation(.easeOut(duration: 0.4)) {
                    showSceneTitle = true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.8))
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSceneTitle = false
                    }
                }
            }
            
            // Reset position while invisible/small
            nudgyY = 30
            squashStretch = CGSize(width: 1.0, height: 0.7)
            
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            
            // ── ENTRANCE: Pop in from below with stretch ──
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                nudgyScale = 1.05
                nudgyY = -6
                squashStretch = CGSize(width: 0.88, height: 1.14)
            }
            
            try? await Task.sleep(for: .seconds(0.18))
            guard !Task.isCancelled else { return }
            
            // ── LAND: Squash on arrival ──
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                nudgyY = 2
                squashStretch = CGSize(width: 1.1, height: 0.9)
                nudgyScale = 1.0
            }
            
            try? await Task.sleep(for: .seconds(0.12))
            guard !Task.isCancelled else { return }
            
            // ── SETTLE: Return to neutral with personality tilt ──
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                nudgyY = 0
                squashStretch = CGSize(width: 1.0, height: 1.0)
                headTilt = nextScene == .together ? -3 : (nextScene == .fish ? 4 : 0)
            }
            
            // Scene-specific effects
            performSceneEffects(nextScene)
            
            try? await Task.sleep(for: .seconds(0.25))
            guard !Task.isCancelled else { return }
            
            // Settle the tilt
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                headTilt = 0
            }
            
            sceneReady = true
        }
    }
    
    private func performSceneEffects(_ scene: IntroScene) {
        switch scene {
        case .journey:
            // Waddle with weight shift — alternating tilt + walk offset
            startWaddleAnimation()
            
        case .fish:
            // Nudgy gets excited — little hops before fish burst
            Task { @MainActor in
                // Excited wiggle before the burst
                try? await Task.sleep(for: .seconds(0.8))
                guard !Task.isCancelled else { return }
                
                for _ in 0..<2 {
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
                        nudgyBounce = -6
                        squashStretch = CGSize(width: 0.92, height: 1.08)
                    }
                    try? await Task.sleep(for: .seconds(0.2))
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                        nudgyBounce = 0
                        squashStretch = CGSize(width: 1.04, height: 0.96)
                    }
                    try? await Task.sleep(for: .seconds(0.15))
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        squashStretch = CGSize(width: 1.0, height: 1.0)
                    }
                }
                
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                showFishBurst = true
                
                // Big excited bounce on burst
                withAnimation(.spring(response: 0.25, dampingFraction: 0.35)) {
                    nudgyBounce = -14
                    squashStretch = CGSize(width: 0.85, height: 1.18)
                }
                try? await Task.sleep(for: .seconds(0.2))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    nudgyBounce = 0
                    squashStretch = CGSize(width: 1.06, height: 0.94)
                }
                try? await Task.sleep(for: .seconds(0.15))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                    squashStretch = CGSize(width: 1.0, height: 1.0)
                }
            }
            
        case .beanie:
            // Beanie drops from above — Nudgy reacts to the weight
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.8))
                guard !Task.isCancelled else { return }
                
                withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) {
                    showBeanie = true
                }
                
                HapticService.shared.swipeDone()
                
                // Nudgy squashes from beanie "weight" landing on head
                try? await Task.sleep(for: .seconds(0.25))
                withAnimation(.spring(response: 0.18, dampingFraction: 0.4)) {
                    squashStretch = CGSize(width: 1.08, height: 0.92)
                    nudgyBounce = 3
                }
                
                try? await Task.sleep(for: .seconds(0.15))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                    squashStretch = CGSize(width: 1.0, height: 1.0)
                    nudgyBounce = 0
                }
                
                // Proud head wiggle with beanie
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                    headTilt = 6
                    beanieWiggle = -4
                }
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                    headTilt = -5
                    beanieWiggle = 5
                }
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    headTilt = 0
                    beanieWiggle = 0
                }
            }
            
        case .launch:
            // Summit celebration — big bounce sequence
            Task { @MainActor in
                // Anticipation dip
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    squashStretch = CGSize(width: 1.12, height: 0.82)
                    nudgyBounce = 4
                }
                
                try? await Task.sleep(for: .seconds(0.18))
                guard !Task.isCancelled else { return }
                
                // BIG jump
                withAnimation(.spring(response: 0.3, dampingFraction: 0.35)) {
                    nudgyBounce = -20
                    squashStretch = CGSize(width: 0.82, height: 1.22)
                }
                HapticService.shared.swipeDone()
                
                try? await Task.sleep(for: .seconds(0.25))
                guard !Task.isCancelled else { return }
                
                // Land with impact
                withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                    nudgyBounce = 3
                    squashStretch = CGSize(width: 1.15, height: 0.85)
                }
                
                try? await Task.sleep(for: .seconds(0.12))
                
                // Smaller settle bounce
                withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                    nudgyBounce = -6
                    squashStretch = CGSize(width: 0.94, height: 1.06)
                }
                
                try? await Task.sleep(for: .seconds(0.15))
                
                // Rest
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    nudgyBounce = 0
                    squashStretch = CGSize(width: 1.0, height: 1.0)
                }
            }
            
        default:
            break
        }
    }
    
    private func startWaddleAnimation() {
        guard !reduceMotion else { return }
        
        // Pixar-style waddle: alternating tilt + offset + squash per step
        Task { @MainActor in
            for step in 0..<6 {
                guard !Task.isCancelled else { return }
                let direction: CGFloat = step.isMultiple(of: 2) ? 1 : -1
                
                withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) {
                    nudgyWalkOffset = direction * 10
                    headTilt = Double(direction) * 5
                    squashStretch = CGSize(
                        width: 1.0 + (direction > 0 ? 0.04 : -0.04),
                        height: 1.0 + (direction > 0 ? -0.04 : 0.04)
                    )
                }
                
                try? await Task.sleep(for: .seconds(0.28))
            }
            
            // Settle
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                nudgyWalkOffset = 0
                headTilt = 0
                squashStretch = CGSize(width: 1.0, height: 1.0)
            }
        }
    }
    
    // MARK: - Breathing / Idle Animation
    
    /// Subtle idle "breathing" so Nudgy feels alive between interactions.
    private func startBreathingAnimation() {
        guard !reduceMotion else { return }
        withAnimation(
            .easeInOut(duration: 2.5)
            .repeatForever(autoreverses: true)
        ) {
            breatheScale = 1.035
        }
    }
    
    // MARK: - Skip to Sign In
    
    /// Skips the story scenes and jumps directly to the launch scene with Apple Sign In.
    private func skipToSignIn() {
        transitionTask?.cancel()
        HapticService.shared.actionButtonTap()
        
        transitionTask = Task { @MainActor in
            // Quick anticipation dip
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                squashStretch = CGSize(width: 1.08, height: 0.88)
                nudgyBounce = 3
            }
            
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            
            withAnimation(.easeInOut(duration: 0.45)) {
                currentScene = .launch
                currentDialogueIndex = 0
                dialogueComplete = false
                sceneReady = false
            }
            
            // Transition bounce
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                nudgyScale = 1.0
                nudgyBounce = -8
                squashStretch = CGSize(width: 0.9, height: 1.12)
            }
            
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }
            
            // Land
            withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                nudgyBounce = 2
                squashStretch = CGSize(width: 1.08, height: 0.92)
            }
            
            try? await Task.sleep(for: .seconds(0.12))
            
            // Settle
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                nudgyBounce = 0
                squashStretch = CGSize(width: 1.0, height: 1.0)
            }
            
            performSceneEffects(.launch)
            
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            
            sceneReady = true
        }
    }
    
}

// MARK: - Previews

#Preview("Full Intro") {
    NudgyIntroView()
        .environment(AppSettings())
        .environment(AuthSession())
        .environment(PenguinState())
}

#Preview("Scene 3 \u{2014} Fish") {
    NudgyIntroView()
        .environment(AppSettings())
        .environment(AuthSession())
        .environment(PenguinState())
}
