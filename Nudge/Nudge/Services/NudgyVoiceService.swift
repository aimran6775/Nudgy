//
//  NudgyVoiceService.swift
//  Nudge
//
//  Gives Nudgy a voice using AVSpeechSynthesizer.
//  Speaks responses aloud with a distinctive, slightly higher-pitched
//  voice that matches Nudgy's playful personality.
//
//  On-device only — no network needed.
//  Respects the user's voice toggle in settings.
//  Strips emojis before speaking for natural-sounding output.
//

import AVFoundation
import UIKit

/// Manages Nudgy's text-to-speech voice output.
@MainActor @Observable
final class NudgyVoiceService: NSObject {
    
    static let shared = NudgyVoiceService()
    
    // MARK: - State
    
    private(set) var isSpeaking = false
    
    /// Whether voice is enabled (defaults to ON — Nudgy has a voice!)
    var isEnabled: Bool {
        get {
            // Default to true if never set
            if UserDefaults.standard.object(forKey: "nudgyVoiceEnabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "nudgyVoiceEnabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: "nudgyVoiceEnabled") }
    }
    
    // MARK: - Private
    
    private let synthesizer = AVSpeechSynthesizer()
    
    /// The preferred voice for Nudgy — slightly higher pitch, moderate rate.
    private var nudgyVoice: AVSpeechSynthesisVoice? {
        // Try to find a compact/premium voice first for better quality
        // Prefer "Samantha" (en-US) or similar friendly voice
        let preferred = [
            "com.apple.voice.compact.en-US.Samantha",
            "com.apple.voice.enhanced.en-US.Samantha",
            "com.apple.voice.compact.en-GB.Daniel",
            "com.apple.voice.enhanced.en-GB.Daniel"
        ]
        
        for id in preferred {
            if let voice = AVSpeechSynthesisVoice(identifier: id) {
                return voice
            }
        }
        
        // Fallback: default English voice
        return AVSpeechSynthesisVoice(language: "en-US")
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
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
        } catch {
            #if DEBUG
            print("⚠️ NudgyVoice: Audio session config failed: \(error)")
            #endif
        }
    }
    
    // MARK: - Speak
    
    /// Speak text aloud as Nudgy. Strips emojis and cleans up for natural speech.
    func speak(_ text: String) {
        guard isEnabled else { return }
        
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let cleaned = cleanForSpeech(text)
        guard !cleaned.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = nudgyVoice
        
        // Nudgy's voice characteristics:
        // Slightly higher pitch (1.1x) — sounds youthful/cute
        // Moderate rate — conversational, not rushed
        // Normal volume — not jarring
        utterance.pitchMultiplier = 1.12
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.volume = 0.85
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.0
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    /// Stop speaking immediately.
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
    
    // MARK: - Text Cleaning
    
    /// Clean text for natural speech output.
    /// Strips emojis, markdown-like formatting, and normalizes punctuation.
    private func cleanForSpeech(_ text: String) -> String {
        var cleaned = text
        
        // Remove emojis
        cleaned = cleaned.unicodeScalars.filter { scalar in
            // Keep basic Latin, Latin supplement, general punctuation, spaces
            // Remove emoji ranges
            let value = scalar.value
            if value > 0x1F000 { return false } // Most emojis
            if (0x2600...0x27BF).contains(value) { return false } // Misc symbols
            if (0xFE00...0xFE0F).contains(value) { return false } // Variation selectors
            if (0x200D...0x200D).contains(value) { return false } // Zero-width joiner
            if (0x2702...0x27B0).contains(value) { return false } // Dingbats
            return true
        }.map { String($0) }.joined()
        
        // Remove markdown-style formatting
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

extension NudgyVoiceService: AVSpeechSynthesizerDelegate {
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
