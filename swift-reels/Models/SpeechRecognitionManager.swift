import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechRecognitionManager: NSObject, ObservableObject {
    static let shared = SpeechRecognitionManager()
    
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var error: Error?
    @Published var recordingStatus: RecordingStatus = .idle
    
    enum RecordingStatus: Equatable {
        case idle
        case listening
        case recording
        case noSpeechDetected
        case error(String)
        
        var description: String {
            switch self {
            case .idle: return "Ready to record"
            case .listening: return "Listening..."
            case .recording: return "Recording..."
            case .noSpeechDetected: return "No speech detected. Try again?"
            case .error(let message): return "Error: \(message)"
            }
        }
        
        static func == (lhs: RecordingStatus, rhs: RecordingStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.listening, .listening),
                 (.recording, .recording),
                 (.noSpeechDetected, .noSpeechDetected):
                return true
            case (.error(let lhsMsg), .error(let rhsMsg)):
                return lhsMsg == rhsMsg
            default:
                return false
            }
        }
    }
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 2.0 // Seconds of silence before showing no speech detected
    private var isInLiveStream = false // Track if we're in a live stream
    private var initialSilenceDelay: TimeInterval = 3.0 // Initial grace period before showing no speech detected
    private var hasStartedSpeaking = false // Track if user has started speaking
    
    private override init() {
        // Initialize with en-US locale for better compatibility
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        
        // Ensure speech recognizer is available
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            error = NSError(
                domain: "SpeechRecognitionManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognition is not available for en-US locale"]
            )
            return
        }
        
        print("✅ Speech recognizer initialized")
        print("   Is available: \(recognizer.isAvailable)")
        print("   Supports on-device: \(recognizer.supportsOnDeviceRecognition)")
    }
    
    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                print("🎤 Speech recognition authorization status: \(status.rawValue)")
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    func startRecording(inLiveStream: Bool = false) async throws {
        // Store live stream state
        isInLiveStream = inLiveStream
        hasStartedSpeaking = false // Reset speaking state
        
        // First ensure we're not already recording
        if isRecording {
            stopRecording()
        }
        
        // Reset state
        transcript = ""
        error = nil
        recordingStatus = .listening
        
        print("🎤 Starting speech recognition (in live stream: \(inLiveStream))...")
        
        // 1. Check authorization status
        let authorized = await requestAuthorization()
        guard authorized else {
            throw NSError(
                domain: "SpeechRecognitionManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"]
            )
        }
        
        // 2. Configure audio session only if NOT in live stream
        if !inLiveStream {
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.playAndRecord, 
                                          mode: .default,
                                          options: [.mixWithOthers])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                print("✅ Audio session configured (not in live stream)")
            } catch {
                print("❌ Failed to configure audio session:", error.localizedDescription)
                throw NSError(
                    domain: "SpeechRecognitionManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to configure audio session: \(error.localizedDescription)"]
                )
            }
        } else {
            print("ℹ️ Skipping audio session config because we are in a live stream")
        }
        
        // 3. Create and configure recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(
                domain: "SpeechRecognitionManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"]
            )
        }
        
        // Force server-based recognition and configure for best results
        recognitionRequest.requiresOnDeviceRecognition = false
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        print("✅ Recognition request configured")
        
        // 4. Start recognition task
        guard let speechRecognizer = speechRecognizer else {
            throw NSError(
                domain: "SpeechRecognitionManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not initialized"]
            )
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Recognition error:", error.localizedDescription)
                Task { @MainActor in
                    self.error = error
                    if !self.transcript.isEmpty {
                        // If we have some transcript, don't stop recording on error
                        print("ℹ️ Continuing recording despite error due to existing transcript")
                        return
                    }
                    self.stopRecording()
                }
                return
            }
            
            if let result = result {
                Task { @MainActor in
                    let newTranscript = result.bestTranscription.formattedString
                    if newTranscript != self.transcript {
                        self.transcript = newTranscript
                        print("🎤 Transcript updated:", self.transcript)
                        // Reset silence timer since we got new speech
                        self.resetSilenceTimer()
                        // Update recording status and mark that speaking has started
                        self.hasStartedSpeaking = true
                        self.recordingStatus = .recording
                    }
                }
            }
        }
        
        // 5. Configure audio engine and input node
        let inputNode = audioEngine.inputNode
        
        // Remove any existing tap first
        if inputNode.numberOfInputs > 0 {
            inputNode.removeTap(onBus: 0)
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start initial silence timer with longer delay
        DispatchQueue.main.async {
            self.startInitialSilenceTimer()
        }
        
        // 6. Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            recordingStatus = .listening
            print("✅ Audio engine started (in live stream: \(inLiveStream))")
        } catch {
            print("❌ Failed to start audio engine:", error.localizedDescription)
            stopRecording()
            throw NSError(
                domain: "SpeechRecognitionManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to start audio engine: \(error.localizedDescription)"]
            )
        }
    }
    
    private func startInitialSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: initialSilenceDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if !self.hasStartedSpeaking {
                // Only show no speech detected if user hasn't started speaking yet
                self.recordingStatus = .noSpeechDetected
            }
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        if hasStartedSpeaking {
            // Use shorter threshold once speech has started
            silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                if self.transcript.isEmpty {
                    self.recordingStatus = .noSpeechDetected
                }
            }
        }
    }
    
    func stopRecording() {
        print("🎤 Stopping speech recognition...")
        
        // Clear silence timer
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        // Stop audio engine and remove tap
        audioEngine.stop()
        let inputNode = audioEngine.inputNode
        if inputNode.numberOfInputs > 0 {
            inputNode.removeTap(onBus: 0)
        }
        
        // End recognition request and task
        if let request = recognitionRequest {
            request.endAudio()
            recognitionRequest = nil
        }
        
        if let task = recognitionTask {
            task.finish()
            recognitionTask = nil
        }
        
        // Update state
        isRecording = false
        recordingStatus = transcript.isEmpty ? .noSpeechDetected : .idle
        error = nil
        
        // Only deactivate audio session if NOT in live stream
        if !isInLiveStream {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                print("✅ Audio session deactivated (not in live stream)")
            } catch {
                print("❌ Error deactivating audio session:", error.localizedDescription)
            }
        } else {
            print("ℹ️ Skipping audio session deactivation because we are in a live stream")
        }
        
        print("✅ Speech recognition stopped successfully")
    }
}