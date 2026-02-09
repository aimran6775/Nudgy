//
//  SpeechService.swift
//  Nudge
//
//  SFSpeechRecognizer wrapper — on-device speech-to-text.
//  Capped at 55 seconds (Apple's limit workaround).
//

import Speech
import AVFoundation

/// Wraps Apple's SFSpeechRecognizer for on-device voice recognition.
@MainActor @Observable
final class SpeechService {
    
    // MARK: - State
    
    enum SpeechState: Equatable {
        case idle
        case requesting       // Requesting permission
        case recording        // Actively recording
        case processing       // Stopped recording, finalizing transcript
        case finished(String) // Final transcript
        case error(String)    // Error message
    }
    
    private(set) var state: SpeechState = .idle
    private(set) var liveTranscript: String = ""
    private(set) var elapsedTime: TimeInterval = 0
    
    /// Audio level (0.0 – 1.0) for waveform visualization
    private(set) var audioLevel: Float = 0
    
    /// Recent audio level samples for waveform bars
    private(set) var waveformSamples: [Float] = Array(repeating: 0, count: 20)
    
    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }
    
    var remainingTime: TimeInterval {
        max(0, RecordingConfig.maxDuration - elapsedTime)
    }
    
    var showCountdown: Bool {
        remainingTime <= RecordingConfig.countdownThreshold && isRecording
    }
    
    // MARK: - Private
    
    private let speechRecognizer: SFSpeechRecognizer?  // nil if locale unsupported
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var timer: Timer?
    
    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    }
    
    // MARK: - Permission
    
    func requestPermission() async -> Bool {
        state = .requesting
        
        // Speech recognition permission
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        guard speechAuthorized else {
            state = .error(String(localized: "Speech recognition not authorized. Enable in Settings."))
            return false
        }
        
        // Microphone permission
        let micAuthorized = await AVAudioApplication.requestRecordPermission()
        
        guard micAuthorized else {
            state = .error(String(localized: "Microphone access required. Enable in Settings."))
            return false
        }
        
        state = .idle
        return true
    }
    
    // MARK: - Start Recording
    
    func startRecording() throws {
        // Cancel any previous task
        stopRecording()
        
        // Check speech recognizer availability
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            state = .error(String(localized: "Speech recognition is not available for your language. Try changing your device language in Settings."))
            return
        }
        
        // Stop any TTS playback to avoid audio session conflict
        NudgyVoiceOutput.shared.stop()
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            state = .error(String(localized: "Unable to create recognition request"))
            return
        }
        
        // On-device only (no network, works offline)
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Guard against invalid audio format (0 channels / 0 sample rate)
        guard recordingFormat.channelCount > 0, recordingFormat.sampleRate > 0 else {
            state = .error(String(localized: "Microphone not available. Check your audio settings."))
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // Extract audio level for waveform visualization
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += abs(channelData[i])
            }
            let average = sum / Float(max(frameLength, 1))
            // Normalize to 0-1 range (typical speech is 0.01-0.1 RMS)
            let normalized = min(average * 10, 1.0)
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.audioLevel = normalized
                // Shift samples left and append new
                self.waveformSamples.removeFirst()
                self.waveformSamples.append(normalized)
            }
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                if let result {
                    self.liveTranscript = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self.state = .finished(self.liveTranscript)
                    }
                }
                
                if let error {
                    // Don't overwrite a finished state with an error from cancellation
                    if case .finished = self.state { return }
                    self.state = .error(error.localizedDescription)
                    self.stopRecording()
                }
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        state = .recording
        elapsedTime = 0
        liveTranscript = ""
        audioLevel = 0
        waveformSamples = Array(repeating: 0, count: 20)
        
        // Start countdown timer
        startTimer()
    }
    
    // MARK: - Stop Recording
    
    func stopRecording() {
        timer?.invalidate()
        timer = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Use finish() instead of cancel() to get the final transcript
        recognitionTask?.finish()
        recognitionTask = nil
        
        if case .recording = state {
            if liveTranscript.isEmpty {
                state = .idle
            } else {
                state = .finished(liveTranscript)
            }
        }
        
        // Restore audio session for playback (TTS) — keep active so speech works
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    /// Reset to idle
    func reset() {
        stopRecording()
        state = .idle
        liveTranscript = ""
        elapsedTime = 0
        audioLevel = 0
        waveformSamples = Array(repeating: 0, count: 20)
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.elapsedTime += 1
                
                // Auto-stop at max duration
                if self.elapsedTime >= RecordingConfig.maxDuration {
                    self.stopRecording()
                }
            }
        }
    }
}
