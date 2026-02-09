//
//  SoundGenerator.swift
//  Nudge
//
//  Generates placeholder .caf sound files programmatically using AVFoundation.
//  These are used when bundled .caf files are missing (dev/testing).
//  For production, replace with professionally designed sounds.
//

import AVFoundation
import Foundation

/// Generates simple synthesized sounds and saves them as .caf files.
/// Call `SoundGenerator.generateMissingSounds()` on first launch to create
/// placeholder audio files if the real assets aren't bundled yet.
enum SoundGenerator {
    
    private static let sampleRate: Double = 44100
    
    // MARK: - Public
    
    /// Check for missing sound files and generate placeholders in the app's
    /// support directory. Returns the directory URL for SoundService to load from.
    @discardableResult
    static func generateMissingSounds() -> URL {
        let dir = supportDirectory()
        
        let sounds: [(String, () -> [Float])] = [
            ("brain-dump-start", { synthesizePop() }),
            ("task-done",        { synthesizeChime() }),
            ("all-clear",        { synthesizeChord() }),
            ("nudge-knock",      { synthesizeKnock() }),
        ]
        
        for (name, generator) in sounds {
            let fileURL = dir.appendingPathComponent("\(name).caf")
            // Skip if the file already exists (either bundled copy or previously generated)
            if FileManager.default.fileExists(atPath: fileURL.path) { continue }
            
            let samples = generator()
            writeSamplesToCAF(samples, url: fileURL)
        }
        
        return dir
    }
    
    // MARK: - Synthesis
    
    /// Soft "pop" — sine burst that decays quickly (0.2s)
    private static func synthesizePop() -> [Float] {
        let duration = 0.2
        let count = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: count)
        
        let freq: Float = 880 // A5
        for i in 0..<count {
            let t = Float(i) / Float(sampleRate)
            let envelope = max(0, 1.0 - t / Float(duration)) * (1.0 - t / Float(duration))
            samples[i] = sin(2 * .pi * freq * t) * envelope * 0.4
        }
        return samples
    }
    
    /// Two-note ascending chime: C5 → E5 (0.3s)
    private static func synthesizeChime() -> [Float] {
        let duration = 0.3
        let count = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: count)
        
        let halfPoint = count / 2
        let freqC5: Float = 523.25
        let freqE5: Float = 659.25
        
        for i in 0..<count {
            let t = Float(i) / Float(sampleRate)
            let freq = i < halfPoint ? freqC5 : freqE5
            let localT = i < halfPoint ? t : t - Float(halfPoint) / Float(sampleRate)
            let envelope = max(0, 1.0 - localT / (Float(duration) * 0.6))
            samples[i] = sin(2 * .pi * freq * t) * envelope * 0.35
        }
        return samples
    }
    
    /// Warm three-note chord: C4-E4-G4 simultaneously (0.5s)
    private static func synthesizeChord() -> [Float] {
        let duration = 0.5
        let count = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: count)
        
        let freqs: [Float] = [261.63, 329.63, 392.0] // C4, E4, G4
        
        for i in 0..<count {
            let t = Float(i) / Float(sampleRate)
            let envelope = max(0, 1.0 - t / Float(duration))
            var sum: Float = 0
            for f in freqs {
                sum += sin(2 * .pi * f * t)
            }
            samples[i] = (sum / Float(freqs.count)) * envelope * 0.3
        }
        return samples
    }
    
    /// Double knock pattern (0.5s) — two short bursts of noise
    private static func synthesizeKnock() -> [Float] {
        let duration = 0.5
        let count = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: count)
        
        // Knock 1: 0.0s–0.06s, Knock 2: 0.15s–0.21s
        let knock1Start = 0
        let knock1End = Int(0.06 * sampleRate)
        let knock2Start = Int(0.15 * sampleRate)
        let knock2End = Int(0.21 * sampleRate)
        
        for i in 0..<count {
            let t = Float(i) / Float(sampleRate)
            let isKnock1 = i >= knock1Start && i < knock1End
            let isKnock2 = i >= knock2Start && i < knock2End
            
            if isKnock1 || isKnock2 {
                let knockStart: Float = isKnock1 ? 0 : 0.15
                let localT = t - knockStart
                let envelope = max(0, 1.0 - localT / 0.06)
                // Low thud + filtered noise
                let thud = sin(2 * .pi * 120 * t) * envelope * 0.5
                let noise = Float.random(in: -0.2...0.2) * envelope * 0.3
                samples[i] = thud + noise
            }
        }
        return samples
    }
    
    // MARK: - File I/O
    
    private static func supportDirectory() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NudgeSounds")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    /// Write raw float samples to a .caf file using AVAudioFile
    private static func writeSamplesToCAF(_ samples: [Float], url: URL) {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else { return }
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ) else { return }
        
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<samples.count {
                channelData[i] = samples[i]
            }
        }
        
        do {
            let file = try AVAudioFile(
                forWriting: url,
                settings: format.settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
            try file.write(from: buffer)
        } catch {
            print("⚠️ SoundGenerator: Failed to write \(url.lastPathComponent): \(error)")
        }
    }
}
