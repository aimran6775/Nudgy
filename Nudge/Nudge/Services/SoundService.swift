//
//  SoundService.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import AVFoundation
import UIKit

/// Custom audio feedback. Respects Silent Mode — haptics are primary, sound is a bonus.
/// Sound files are .caf format, loaded once and cached.
@Observable
final class SoundService {
    
    static let shared = SoundService()
    
    private var soundIDs: [SoundEvent: SystemSoundID] = [:]
    private var isLoaded = false
    
    private init() {}
    
    // MARK: - Sound Events (Antarctic Sound Palette)
    
    enum SoundEvent: String, CaseIterable {
        case brainDumpStart = "brain-dump-start"   // Crystalline ice bubble (0.25s)
        case taskDone       = "task-done"           // Ascending ice chime — C5→E5→G5 (0.4s)
        case allClear       = "all-clear"           // Warm harmonic chord with shimmer (0.6s)
        case nudgeKnock     = "nudge-knock"         // Soft double knock on ice (0.5s)
        case tabSwitch      = "tab-switch"          // Subtle ice tap (0.12s)
        case snooze         = "snooze"              // Soft descending crystal — going to sleep (0.35s)
        case fishCaught     = "fish-caught"         // Underwater blub + sparkle (0.4s)
        case micStart       = "mic-start"           // Gentle activation tone (0.15s)
        case sendMessage    = "send-message"        // Soft whoosh-up (0.2s)
    }
    
    // MARK: - Setup
    
    /// Load all .caf sound files from the bundle. Call on app launch.
    func loadSounds() {
        guard !isLoaded else { return }
        
        // Generate placeholder sounds for any missing assets
        let fallbackDir = SoundGenerator.generateMissingSounds()
        
        for event in SoundEvent.allCases {
            // First try bundle, then fallback to generated directory
            let url = Bundle.main.url(forResource: event.rawValue, withExtension: "caf")
                ?? fallbackDir.appendingPathComponent("\(event.rawValue).caf")
            
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            
            var soundID: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
            soundIDs[event] = soundID
        }
        
        isLoaded = true
    }
    
    // MARK: - Playback
    
    /// Play a sound event. Respects the hardware silent switch automatically
    /// because we use AudioServicesPlaySystemSound (not AVAudioPlayer).
    func play(_ event: SoundEvent) {
        guard let soundID = soundIDs[event] else { return }
        AudioServicesPlaySystemSound(soundID)
    }
    
    // MARK: - Convenience
    
    func playBrainDumpStart() { play(.brainDumpStart) }
    func playTaskDone()       { play(.taskDone) }
    func playAllClear()       { play(.allClear) }
    func playNudgeKnock()     { play(.nudgeKnock) }
    func playTabSwitch()      { play(.tabSwitch) }
    func playSnooze()         { play(.snooze) }
    func playFishCaught()     { play(.fishCaught) }
    func playMicStart()       { play(.micStart) }
    func playSendMessage()    { play(.sendMessage) }
    
    // MARK: - Cleanup
    
    /// Dispose sound resources (call on app termination if needed)
    func disposeSounds() {
        for (_, soundID) in soundIDs {
            AudioServicesDisposeSystemSoundID(soundID)
        }
        soundIDs.removeAll()
        isLoaded = false
    }
}
