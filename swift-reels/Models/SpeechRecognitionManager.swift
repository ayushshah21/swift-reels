import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechRecognitionManager: NSObject, ObservableObject {
    static let shared = SpeechRecognitionManager()
    private let firestoreManager = FirestoreManager.shared  // Add firestoreManager property
    
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
    
    // MARK: - Init
    
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
    
    // MARK: - Permission
    
    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                print("🎤 Speech recognition authorization status: \(status.rawValue)")
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    // MARK: - Live Recording
    
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
                try audioSession.setCategory(
                    .playAndRecord,
                                          mode: .default,
                    options: [.mixWithOthers]
                )
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
    
    // MARK: - Subtitle Processing
    
    func processVideoSubtitles(videoId: String, videoURL: URL) {
        // Start processing in background
        Task.detached(priority: .background) {
            do {
                print("🎤 Starting subtitle processing for video: \(videoId)")
                print("   Video URL: \(videoURL)")
                
                // First check authorization
                let authorized = await self.requestAuthorization()
                print("   Speech recognition authorization: \(authorized ? "✅" : "❌")")
                
                guard authorized else {
                    print("❌ Speech recognition not authorized")
                    // Create empty subtitles but mark as complete since we can't process
                    let emptySubtitles = VideoSubtitles(
                        id: videoId,
                        segments: [],
                        isComplete: true,
                        lastUpdated: Date()
                    )
                    try await self.firestoreManager.updateSubtitles(emptySubtitles)
                    return
                }
                
                // Create empty subtitles document to start
                let emptySubtitles = VideoSubtitles.empty(for: videoId)
                try await self.firestoreManager.updateSubtitles(emptySubtitles)
                print("✅ Created initial empty subtitles document")
                
                // IMPORTANT: Download video if needed and extract audio to a local .m4a
                print("📥 Downloading video if needed...")
                let localVideoURL = try await self.downloadVideoIfNeeded(remoteURL: videoURL)
                print("✅ Video available at local path: \(localVideoURL.path)")
                
                print("🎵 Extracting audio track...")
                let localAudioURL = try await self.extractAudioTrack(from: localVideoURL)
                print("✅ Audio extracted to: \(localAudioURL.path)")
                
                // Now do speech recognition on the local .m4a file
                print("🎤 Starting speech recognition on audio file...")
                try await self.recognizeSpeechFromAudioFile(audioURL: localAudioURL, videoId: videoId)
                
                print("✅ Subtitle processing completed for video: \(videoId)")
            } catch {
                print("❌ Error processing subtitles: \(error.localizedDescription)")
                print("   Error details: \(error)")
                // Create empty subtitles but mark as complete since processing failed
                do {
                    let emptySubtitles = VideoSubtitles(
                        id: videoId,
                        segments: [],
                        isComplete: true,
                        lastUpdated: Date()
                    )
                    try await self.firestoreManager.updateSubtitles(emptySubtitles)
                    print("✅ Saved empty subtitles due to processing error")
                } catch {
                    print("❌ Error saving empty subtitles: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Downloads the video to a local temporary file if `remoteURL` is not a `file://` URL already.
    /// Returns the local file URL.
    private func downloadVideoIfNeeded(remoteURL: URL) async throws -> URL {
        // If it's already a file URL, no need to download.
        if remoteURL.isFileURL {
            return remoteURL
        }
        
        // Otherwise, download to a temporary location
        let fileName = remoteURL.lastPathComponent
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent(fileName)
        
        // If we already downloaded it, return immediately (to avoid redownloading)
        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }
        
        print("⬇️ Downloading video from remote URL: \(remoteURL)")
        let (data, response) = try await URLSession.shared.data(from: remoteURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "SpeechRecognitionManager",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to download video; invalid response"])
        }
        
        try data.write(to: localURL, options: .atomic)
        print("✅ Video downloaded to: \(localURL.path)")
        return localURL
    }
    
    /// Exports the audio track from a local video file into a .m4a file in the temp directory.
    /// Returns the local .m4a file URL.
    private func extractAudioTrack(from localVideoURL: URL) async throws -> URL {
        let asset = AVAsset(url: localVideoURL)
        
        // Ensure there's an audio track
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else {
            print("⚠️ No audio track found in video")
            throw NSError(
                domain: "SpeechRecognitionManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No audio track found"]
            )
        }
        
        // Create an export session for audio
        let fileName = UUID().uuidString + ".m4a"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // If a file with that name already exists, remove it
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(
                domain: "SpeechRecognitionManager",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Could not create export session"]
            )
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        print("🎧 Exporting audio track to:", outputURL.path)
        
        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    print("✅ Audio export completed:", outputURL.lastPathComponent)
                    continuation.resume(returning: outputURL)
                case .failed, .cancelled:
                    let errorText = exportSession.error?.localizedDescription ?? "Unknown export error"
                    print("❌ Audio export failed:", errorText)
                    continuation.resume(throwing: NSError(
                        domain: "SpeechRecognitionManager",
                        code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "Audio export failed: \(errorText)"]
                    ))
                default:
                    continuation.resume(throwing: NSError(
                        domain: "SpeechRecognitionManager",
                        code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "Audio export ended with unexpected status"]
                    ))
                }
            }
        }
    }
    
    /// Actually perform speech recognition on the local audio file,
    /// updating Firestore with partial/final segments of the transcript.
    private func recognizeSpeechFromAudioFile(audioURL: URL, videoId: String) async throws {
        print("🎤 Processing audio for subtitles from local file: \(audioURL.lastPathComponent)")
        
        do {
            print("🎤 Starting Whisper transcription...")
            let segments = try await OpenAIManager.shared.transcribeAudio(fileURL: audioURL)
            print("✅ Received \(segments.count) segments from Whisper")
            
            // Create initial empty subtitles
            let initialSubtitles = VideoSubtitles(
                id: videoId,
                segments: segments,
                isComplete: true,
                lastUpdated: Date()
            )
            
            // Save to Firestore
            try await self.firestoreManager.updateSubtitles(initialSubtitles)
            print("✅ Saved subtitles to Firestore")
            
        } catch {
            print("❌ Error during Whisper transcription: \(error.localizedDescription)")
            print("   Error details: \(error)")
            
            // Create empty subtitles but mark as complete since processing failed
            let emptySubtitles = VideoSubtitles(
                id: videoId,
                segments: [],
                isComplete: true,
                lastUpdated: Date()
            )
            try await self.firestoreManager.updateSubtitles(emptySubtitles)
            print("✅ Saved empty subtitles due to processing error")
            
            throw error
        }
    }
}
