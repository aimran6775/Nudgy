//
//  NudgyConfig.swift
//  Nudge
//
//  Phase 1: Central configuration for the NudgyEngine.
//  All settings, API keys, model selection, and feature flags live here.
//  Modular and replaceable — swap LLM providers by changing config.
//

import Foundation

// MARK: - NudgyConfig

/// Central configuration for the Nudgy conversational engine.
/// Reads API keys from Secrets.xcconfig via Info.plist, with runtime overrides.
nonisolated enum NudgyConfig {
    
    // MARK: - LLM Provider
    
    enum LLMProvider: String {
        case openAI       // GPT-4o via OpenAI API
        case onDevice     // Apple Foundation Models (fallback)
    }
    
    /// Which LLM backend to use for conversation.
    static var activeProvider: LLMProvider = .openAI
    
    // MARK: - OpenAI Configuration
    
    enum OpenAI {
        /// API key — loaded from Secrets.xcconfig → Info.plist, or set at runtime.
        static var apiKey: String {
            // 1. Check runtime override
            if let override = _apiKeyOverride, !override.isEmpty {
                return override
            }
            // 2. Check Info.plist (from Secrets.xcconfig)
            if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
               !plistKey.isEmpty, !plistKey.hasPrefix("$(") {
                return plistKey
            }
            // No key available — NudgyEngine will fall back to Apple FM / curated
            return ""
        }
        
        private static var _apiKeyOverride: String?
        
        /// Set API key at runtime (e.g., from settings).
        static func setAPIKey(_ key: String) {
            _apiKeyOverride = key
        }
        
        /// Base URL for OpenAI API.
        static let baseURL = "https://api.openai.com/v1"
        
        /// Model to use for conversation.
        static var chatModel = "gpt-4o-mini"
        
        /// Model for task extraction (can be cheaper).
        static var extractionModel = "gpt-4o-mini"
        
        /// Max tokens per response.
        static var maxTokens = 500
        
        /// Temperature for conversation (higher = more creative).
        static var conversationTemperature: Double = 0.85
        
        /// Temperature for task extraction (lower = more precise).
        static var extractionTemperature: Double = 0.3
    }
    
    // MARK: - Voice Configuration
    
    enum Voice {
        /// Whether Nudgy speaks responses aloud.
        static var isEnabled: Bool {
            get { UserDefaults.standard.object(forKey: "nudgyVoiceEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "nudgyVoiceEnabled") }
            set { UserDefaults.standard.set(newValue, forKey: "nudgyVoiceEnabled") }
        }
        
        /// TTS pitch multiplier (1.0 = normal, >1.0 = higher).
        /// Slightly above neutral for gentle warmth — not squeaky, not deep.
        static let pitchMultiplier: Float = 1.04
        
        /// TTS speech rate multiplier.
        /// Deliberately unhurried — Pooh-inspired pacing. Let words breathe.
        static let rateMultiplier: Float = 0.82
        
        /// TTS volume (0.0-1.0).
        static let volume: Float = 0.85
        
        /// Whether to use OpenAI TTS API for higher quality voice.
        /// Defaults to true when API key is available. Persisted in UserDefaults.
        static var useOpenAITTS: Bool {
            get {
                // Default to true if never set and API key is available
                if UserDefaults.standard.object(forKey: "nudgyUseOpenAITTS") == nil {
                    return !NudgyConfig.OpenAI.apiKey.isEmpty
                }
                return UserDefaults.standard.bool(forKey: "nudgyUseOpenAITTS")
            }
            set { UserDefaults.standard.set(newValue, forKey: "nudgyUseOpenAITTS") }
        }
        
        /// OpenAI TTS voice name. Persisted in UserDefaults.
        /// Options: alloy, echo, fable, onyx, nova, shimmer
        /// nova = warm, friendly, unhurried — perfect for gentle Pooh-penguin companion
        static var openAIVoice: String {
            get { UserDefaults.standard.string(forKey: "nudgyOpenAIVoice") ?? "nova" }
            set { UserDefaults.standard.set(newValue, forKey: "nudgyOpenAIVoice") }
        }
        
        /// OpenAI TTS model.
        static var openAITTSModel = "tts-1"
        
        /// Available OpenAI voices with display metadata.
        static let availableVoices: [(id: String, name: String, description: String)] = [
            ("nova", "Nova", "Warm & gentle (recommended)"),
            ("fable", "Fable", "Soft & expressive"),
            ("shimmer", "Shimmer", "Bright & upbeat"),
            ("alloy", "Alloy", "Balanced & clear"),
            ("echo", "Echo", "Calm & smooth"),
            ("onyx", "Onyx", "Deep & steady"),
        ]
        
        /// Speed for OpenAI TTS (0.25-4.0, default 0.92)
        /// Slightly slower than normal for unhurried, warm delivery.
        static var openAISpeed: Double {
            get {
                let stored = UserDefaults.standard.double(forKey: "nudgyOpenAISpeed")
                return stored > 0 ? stored : 0.92
            }
            set { UserDefaults.standard.set(newValue, forKey: "nudgyOpenAISpeed") }
        }
    }
    
    // MARK: - Memory Configuration
    
    enum Memory {
        /// Max conversation turns to keep in active context window.
        static let maxContextTurns = 30
        
        /// Max conversation turns before auto-summarizing old ones.
        static let summarizeAfter = 20
        
        /// Max stored conversations in persistent memory.
        static let maxStoredConversations = 50
        
        /// How long to keep conversation memory (days).
        static let retentionDays = 30
        
        /// App Group identifier for shared storage.
        static let appGroup = "group.com.tarsitgroup.nudge"
        
        /// UserDefaults key for memory store.
        static let memoryKey = "nudgyConversationMemory"
        
        /// File name for conversation archive.
        static let archiveFileName = "nudgy_memory.json"
    }
    
    // MARK: - Personality
    
    enum Personality {
        /// Max response length in words.
        static let maxResponseWords = 50
        
        /// Max response sentences.
        static let maxResponseSentences = 3
        
        /// Idle chatter interval range (seconds).
        static let idleChatInterval: ClosedRange<Double> = 45...90
        
        /// Max idle chatters per session.
        static let maxIdleChatsPerSession = 3
        
        /// Greeting settle delay (seconds).
        static let greetingSettleDelay: TimeInterval = 2.5
        
        /// Reaction display duration (seconds).
        static let reactionDuration: TimeInterval = 2.5
    }
    
    // MARK: - Feature Flags
    
    enum Features {
        /// Whether conversational memory is enabled.
        static var memoryEnabled = true
        
        /// Whether task extraction from conversation is enabled.
        static var taskExtractionEnabled = true
        
        /// Whether proactive nudges are enabled.
        static var proactiveNudgesEnabled = true
        
        /// Whether voice input is enabled.
        static var voiceInputEnabled = true
        
        /// Whether streaming responses are enabled.
        static var streamingEnabled = true
    }
    
    // MARK: - Availability
    
    /// Whether the NudgyEngine has a working LLM connection.
    static var isAvailable: Bool {
        switch activeProvider {
        case .openAI:
            return !OpenAI.apiKey.isEmpty
        case .onDevice:
            return false // Will check SystemLanguageModel at runtime
        }
    }
}
