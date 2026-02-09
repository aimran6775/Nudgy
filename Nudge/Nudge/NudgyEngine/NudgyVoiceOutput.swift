//
//  NudgyVoiceOutput.swift
//  Nudge
//
//  Phase 11: Modular text-to-speech output.
//  Supports two backends:
//  1. AVSpeechSynthesizer (on-device, free, instant)
//  2. OpenAI TTS API (higher quality, requires API key)
//
//  The active backend is selected via NudgyConfig.Voice.useOpenAITTS.
//  Modular: can be replaced with any open-source voice model.
//

import AVFoundation
import Foundation

// MARK: - NudgyVoiceOutput

/// Manages Nudgy's text-to-speech voice output.
@MainActor @Observable
final class NudgyVoiceOutput: NSObject {
    
    static let shared = NudgyVoiceOutput()
    
    // MARK: - State
    
    private(set) var isSpeaking = false
    
    /// Whether Nudgy's voice output is enabled. Backed by NudgyConfig.
    var isEnabled: Bool {
        get { NudgyConfig.Voice.isEnabled }
        set { NudgyConfig.Voice.isEnabled = newValue }
    }
    
    // MARK: - Private
    
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    
    /// The preferred AVSpeech voice.
    private var systemVoice: AVSpeechSynthesisVoice? {
        // Try to find a good English voice
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            return voice
        }
        // Absolute fallback
        return AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en")
    }
    
    // MARK: - Init
    
    private override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("⚠️ NudgyVoiceOutput: Audio session config failed: \(error)")
            #endif
        }
    }
    
    // MARK: - Speak
    
    /// Speak text aloud as Nudgy.
    func speak(_ text: String) {
        guard NudgyConfig.Voice.isEnabled else {
            print("🔇 NudgyVoiceOutput: Voice disabled, skipping")
            return
        }
        
        let cleaned = cleanForSpeech(text)
        guard !cleaned.isEmpty else {
            print("🔇 NudgyVoiceOutput: Text empty after cleaning, skipping")
            return
        }
        print("🐧 NudgyVoiceOutput: speak() called with: \(cleaned.prefix(80))")
        
        if NudgyConfig.Voice.useOpenAITTS {
            speakWithOpenAI(cleaned)
        } else {
            speakWithSystem(cleaned)
        }
    }
    
    /// Stop speaking immediately.
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
    }
    
    // MARK: - System TTS (AVSpeechSynthesizer)
    
    private func speakWithSystem(_ text: String) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Configure audio session for playback
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ NudgyVoiceOutput: Audio session setup failed: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = systemVoice
        utterance.pitchMultiplier = NudgyConfig.Voice.pitchMultiplier
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * NudgyConfig.Voice.rateMultiplier
        utterance.volume = 1.0  // Max volume — NudgyConfig can lower if needed
        utterance.preUtteranceDelay = 0.2
        utterance.postUtteranceDelay = 0.1
        
        isSpeaking = true
        print("🔊 NudgyVoiceOutput: Speaking: \(text.prefix(60))...")
        synthesizer.speak(utterance)
    }
    
    // MARK: - OpenAI TTS
    
    private func speakWithOpenAI(_ text: String) {
        isSpeaking = true
        
        Task {
            do {
                let audioData = try await NudgyLLMService.shared.textToSpeech(text: text)
                
                // Write to temp file and play
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("nudgy_speech_\(UUID().uuidString).mp3")
                try audioData.write(to: tempURL)
                
                let player = try AVAudioPlayer(contentsOf: tempURL)
                self.audioPlayer = player
                player.play()
                
                // Clean up after playback
                Task {
                    try? await Task.sleep(for: .seconds(player.duration + 0.5))
                    try? FileManager.default.removeItem(at: tempURL)
                    self.isSpeaking = false
                }
            } catch {
                #if DEBUG
                print("⚠️ OpenAI TTS failed: \(error). Falling back to system TTS.")
                #endif
                // Fallback to system TTS
                self.speakWithSystem(text)
            }
        }
    }
    
    // MARK: - Text Cleaning
    
    private func cleanForSpeech(_ text: String) -> String {
        var cleaned = text
        
        // Remove emojis
        cleaned = cleaned.unicodeScalars.filter { scalar in
            let value = scalar.value
            if value > 0x1F000 { return false }
            if (0x2600...0x27BF).contains(value) { return false }
            if (0xFE00...0xFE0F).contains(value) { return false }
            if (0x200D...0x200D).contains(value) { return false }
            if (0x2702...0x27B0).contains(value) { return false }
            return true
        }.map { String($0) }.joined()
        
        // Remove markdown
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "*", with: "")
        cleaned = cleaned.replacingOccurrences(of: "_", with: "")
        
        // Normalize whitespace
        cleaned = cleaned.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension NudgyVoiceOutput: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🔊 NudgyVoiceOutput: didStart speaking")
        Task { @MainActor in self.isSpeaking = true }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🔊 NudgyVoiceOutput: didFinish speaking")
        Task { @MainActor in self.isSpeaking = false }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("🔊 NudgyVoiceOutput: didCancel speaking")
        Task { @MainActor in self.isSpeaking = false }
    }
}
