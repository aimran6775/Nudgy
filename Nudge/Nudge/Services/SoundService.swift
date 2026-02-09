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
    
    // MARK: - Sound Events (from PRD Sound Design)
    
    enum SoundEvent: String, CaseIterable {
        case brainDumpStart = "brain-dump-start"   // Soft "pop" — bubble appearing (0.2s)
        case taskDone       = "task-done"           // Gentle chime — C5→E5 (0.3s)
        case allClear       = "all-clear"           // Warm chord — C4-E4-G4 (0.5s)
        case nudgeKnock     = "nudge-knock"         // Knock knock pattern (0.5s)
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
