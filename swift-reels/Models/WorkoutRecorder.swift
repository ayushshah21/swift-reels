import Foundation
import AVFoundation
import UIKit
import ReplayKit

@MainActor
class WorkoutRecorder: NSObject, AVCaptureFileOutputRecordingDelegate, RPScreenRecorderDelegate {
    static let shared = WorkoutRecorder()
    
    private var captureSession: AVCaptureSession?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var isRecording = false
    private var currentRecordingURL: URL?
    private let screenRecorder = RPScreenRecorder.shared()
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    
    private override init() {
        super.init()
        setupCaptureSession()
        screenRecorder.delegate = self
    }
    
    private func setupCaptureSession() {
        print("🎥 Setting up capture session...")
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        // Add audio input
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else {
            print("❌ Failed to create audio input")
            return
        }
        
        if session.canAddInput(audioInput) {
            session.addInput(audioInput)
            print("✅ Added audio input")
        } else {
            print("❌ Could not add audio input")
        }
        
        session.commitConfiguration()
        self.captureSession = session
        print("✅ Capture session setup complete")
    }
    
    func startRecording() {
        guard !isRecording else {
            print("⚠️ Already recording")
            return
        }
        
        // Create a unique file URL in the temporary directory
        let filename = "workout_\(UUID().uuidString).mp4"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        // Remove any existing file
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        currentRecordingURL = fileURL
        
        // Set up asset writer
        do {
            assetWriter = try AVAssetWriter(url: fileURL, fileType: .mp4)
            
            // Video input
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1280,
                AVVideoHeightKey: 720,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 2000000, // 2 Mbps
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true
            
            // Audio input
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000
            ]
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true
            
            if let videoInput = videoInput, assetWriter?.canAdd(videoInput) == true {
                assetWriter?.add(videoInput)
            }
            if let audioInput = audioInput, assetWriter?.canAdd(audioInput) == true {
                assetWriter?.add(audioInput)
            }
            
            // Start screen recording
            screenRecorder.startCapture { [weak self] buffer, type, error in
                guard let self = self else { return }
                if let error = error {
                    print("❌ Screen recording error: \(error.localizedDescription)")
                    return
                }
                
                self.processBuffer(buffer, type: type)
            } completionHandler: { [weak self] error in
                if let error = error {
                    print("❌ Failed to start screen recording: \(error.localizedDescription)")
                    return
                }
                print("✅ Screen recording started")
                self?.isRecording = true
            }
            
            print("🎥 Starting recording to: \(fileURL.path)")
        } catch {
            print("❌ Failed to create asset writer: \(error.localizedDescription)")
        }
    }
    
    private func processBuffer(_ buffer: CMSampleBuffer, type: RPSampleBufferType) {
        guard let writer = assetWriter else { return }
        
        switch type {
        case .video:
            if writer.status == .unknown {
                writer.startWriting()
                writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(buffer))
            }
            
            if writer.status == .writing {
                if let input = videoInput, input.isReadyForMoreMediaData {
                    input.append(buffer)
                }
            }
            
        case .audioMic:
            if writer.status == .writing {
                if let input = audioInput, input.isReadyForMoreMediaData {
                    input.append(buffer)
                }
            }
            
        default:
            break
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording else {
            print("❌ Cannot stop recording: not currently recording")
            completion(nil)
            return
        }
        
        print("⏹️ Stopping recording")
        screenRecorder.stopCapture { [weak self] error in
            if let error = error {
                print("❌ Failed to stop screen recording: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let self = self,
                  let writer = self.assetWriter,
                  let videoInput = self.videoInput,
                  let audioInput = self.audioInput else {
                completion(nil)
                return
            }
            
            // Finish writing
            videoInput.markAsFinished()
            audioInput.markAsFinished()
            
            writer.finishWriting { [weak self] in
                guard let self = self else { return }
                
                if writer.status == .completed {
                    print("✅ Recording saved successfully")
                    completion(self.currentRecordingURL)
                } else {
                    print("❌ Failed to save recording: \(writer.error?.localizedDescription ?? "Unknown error")")
                    completion(nil)
                }
                
                // Clean up
                self.assetWriter = nil
                self.videoInput = nil
                self.audioInput = nil
                self.isRecording = false
                self.currentRecordingURL = nil
            }
        }
    }
    
    // MARK: - RPScreenRecorderDelegate
    
    func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWith error: Error, previewViewController: RPPreviewViewController?) {
        print("❌ Screen recording stopped with error: \(error.localizedDescription)")
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("🎥 Audio recording started")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("📼 Audio recording finished")
        if let error = error {
            print("❌ Audio recording error: \(error.localizedDescription)")
        }
    }
} 