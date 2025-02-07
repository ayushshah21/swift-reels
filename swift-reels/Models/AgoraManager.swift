import Foundation
import AgoraRtcKit
import SwiftUI

@MainActor
class AgoraManager: NSObject, ObservableObject {
    static let shared = AgoraManager()
    
    internal var engine: AgoraRtcEngineKit?
    private let appId = APIConfig.agoraAppId
    
    @Published var isInitialized = false
    @Published var error: String?
    @Published var isFrontCamera = true
    @Published var isInChannel = false
    @Published var currentChannelName: String?
    @Published var currentRole: AgoraClientRole = .broadcaster
    @Published var isLocalAudioEnabled = true
    @Published var isRemoteAudioEnabled = true
    
    private var localVideoCanvas: AgoraRtcVideoCanvas?
    private var remoteVideoCanvas: AgoraRtcVideoCanvas?
    private var remoteView: UIView?
    private var remoteUid: UInt?
    
    private override init() {
        super.init()
        setupEngine()
    }
    
    private func setupEngine() {
        print("🎥 Setting up Agora engine...")
        
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        config.areaCode = .global
        
        // Initialize the Agora engine
        engine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        
        // Enable video module
        engine?.enableVideo()
        // Set channel profile to live broadcasting
        engine?.setChannelProfile(.liveBroadcasting)
        
        isInitialized = true
        print("✅ Agora engine initialized successfully")
    }
    
    func setRole(_ role: AgoraClientRole) {
        guard let engine = engine else {
            print("❌ setRole: Engine not initialized")
            return
        }
        
        print("🔄 Setting role to \(role == .broadcaster ? "broadcaster" : "audience")")
        currentRole = role
        engine.setClientRole(role)
        
        if role == .broadcaster {
            print("📹 Configuring broadcaster settings...")
            // Configure video encoding parameters for broadcasting
            let videoConfig = AgoraVideoEncoderConfiguration(
                size: CGSize(width: 720, height: 1280), // Portrait mode dimensions for reels
                frameRate: .fps30,
                bitrate: AgoraVideoBitrateStandard,
                orientationMode: .fixedPortrait, // Force portrait mode
                mirrorMode: .disabled // Disable mirroring
            )
            engine.setVideoEncoderConfiguration(videoConfig)
            
            // Start camera preview for broadcaster
            engine.startPreview()
            print("✅ Broadcaster setup complete: preview started")
        } else {
            print("👥 Configuring audience settings...")
            // For audience, stop preview and local video
            engine.stopPreview()
            if let localCanvas = localVideoCanvas {
                print("🧹 Cleaning up local video for audience")
                engine.setupLocalVideo(nil)  // Clear local video
                localCanvas.view = nil
                self.localVideoCanvas = nil
            }
            print("✅ Audience setup complete")
        }
    }
    
    func setupLocalVideo(view: UIView) {
        guard let engine = engine else {
            print("❌ Agora engine not initialized")
            return
        }
        
        // Only set up local video for broadcasters
        guard currentRole == .broadcaster else {
            print("⚠️ Skipping local video setup for audience")
            return
        }
        
        // Set up the local video canvas
        let canvas = AgoraRtcVideoCanvas()
        canvas.view = view
        canvas.renderMode = .hidden
        canvas.uid = 0  // Use 0 for local user
        canvas.mirrorMode = .disabled  // Disable mirroring to fix orientation
        engine.setupLocalVideo(canvas)
        
        // Start preview if broadcaster
        engine.startPreview()
        
        self.localVideoCanvas = canvas
        print("✅ Local video preview started")
    }
    
    func setupRemoteVideo(view: UIView, uid: UInt) {
        guard let engine = engine else {
            print("❌ setupRemoteVideo: Engine not initialized")
            return
        }
        
        print("\n🔄 Setting up remote video for uid: \(uid)")
        print("   View frame: \(view.frame)")
        print("   View in hierarchy: \(view.superview != nil)")
        print("   Current role: \(currentRole == .broadcaster ? "broadcaster" : "audience")")
        print("   Is in channel: \(isInChannel)")
        print("   Channel name: \(currentChannelName ?? "none")")
        
        // Clean up existing canvas if any
        if let existingCanvas = remoteVideoCanvas {
            print("🧹 Cleaning up existing remote canvas")
            print("   Existing canvas UID: \(existingCanvas.uid)")
            engine.setupRemoteVideo(AgoraRtcVideoCanvas())
            existingCanvas.view = nil
            remoteVideoCanvas = nil
        }
        
        // Create and setup new canvas
        let canvas = AgoraRtcVideoCanvas()
        canvas.uid = uid
        canvas.view = view
        canvas.renderMode = .hidden
        canvas.mirrorMode = .disabled  // Disable mirroring for remote view
        
        print("   Setting up new remote canvas...")
        engine.setupRemoteVideo(canvas)
        remoteVideoCanvas = canvas
        print("✅ Remote video setup complete for uid: \(uid)")
    }
    
    func switchCamera() {
        guard let engine = engine, currentRole == .broadcaster else { return }
        
        engine.switchCamera()
        isFrontCamera.toggle()
        print("🎥 Switched to \(isFrontCamera ? "front" : "back") camera")
    }
    
    func joinChannel(_ channelName: String) async {
        guard let engine = engine else {
            print("❌ joinChannel: Engine not initialized")
            return
        }
        
        print("\n🔄 Joining channel: \(channelName)")
        print("   Current role: \(currentRole == .broadcaster ? "broadcaster" : "audience")")
        print("   Is already in channel: \(isInChannel)")
        print("   Current channel name: \(currentChannelName ?? "none")")
        print("   Has remote view: \(remoteView != nil)")
        print("   Has remote canvas: \(remoteVideoCanvas != nil)")
        print("   Remote UID: \(remoteUid?.description ?? "none")")
        
        // Configure media options based on role
        let option = AgoraRtcChannelMediaOptions()
        if currentRole == .broadcaster {
            option.publishCameraTrack = true
            option.publishMicrophoneTrack = true
            option.clientRoleType = .broadcaster
            print("📹 Broadcaster media options configured")
        } else {
            option.publishCameraTrack = false
            option.publishMicrophoneTrack = false
            option.clientRoleType = .audience
            option.autoSubscribeAudio = true
            option.autoSubscribeVideo = true
            print("👥 Audience media options configured")
        }
        
        // Join the channel
        let result = engine.joinChannel(
            byToken: nil,
            channelId: channelName,
            uid: 0,
            mediaOptions: option
        )
        
        if result == 0 {
            print("✅ Join channel request sent successfully")
            isInChannel = true
            currentChannelName = channelName
        } else {
            print("❌ Failed to send join channel request: \(result)")
            error = "Failed to join channel"
        }
    }
    
    func leaveChannel() {
        guard let engine = engine else { return }
        
        engine.leaveChannel(nil)
        isInChannel = false
        currentChannelName = nil
        
        // Clean up video views
        if let localView = localVideoCanvas?.view {
            localView.removeFromSuperview()
        }
        if let remoteView = remoteVideoCanvas?.view {
            remoteView.removeFromSuperview()
        }
        
        // Clear all references
        localVideoCanvas = nil
        remoteVideoCanvas = nil
        remoteView = nil
        remoteUid = nil
        
        print("👋 Left channel")
    }
    
    func setupInitialRemoteVideo(view: UIView) {
        print("\n🎥 Setting up initial remote video container...")
        print("   View frame: \(view.frame)")
        print("   View in hierarchy: \(view.superview != nil)")
        print("   Current role: \(currentRole == .broadcaster ? "broadcaster" : "audience")")
        print("   Is in channel: \(isInChannel)")
        print("   Channel name: \(currentChannelName ?? "none")")
        print("   Existing remote UID: \(remoteUid?.description ?? "none")")
        print("   Has existing remote canvas: \(remoteVideoCanvas != nil)")
        
        // Store the remote view reference
        remoteView = view
        
        // If we already have a remote user, set up their video immediately
        if let uid = remoteUid {
            print("🔄 Remote user (\(uid)) already exists, setting up video immediately")
            setupRemoteVideo(view: view, uid: uid)
        } else {
            print("⏳ No remote user yet, waiting for remote user to join")
            // Start a retry timer to handle race conditions
            startRetryTimer()
        }
    }
    
    private func startRetryTimer() {
        // Try to set up remote video every 0.5 seconds for up to 5 seconds
        var attempts = 0
        let maxAttempts = 10
        
        func attemptSetup() {
            guard attempts < maxAttempts else {
                print("⚠️ Max retry attempts reached for remote video setup")
                return
            }
            
            if let view = remoteView, let uid = remoteUid {
                print("🔄 Retry attempt \(attempts + 1): Setting up remote video for uid: \(uid)")
                setupRemoteVideo(view: view, uid: uid)
                return
            }
            
            attempts += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                attemptSetup()
            }
        }
        
        attemptSetup()
    }
    
    func toggleLocalAudio() {
        guard let engine = engine else { return }
        isLocalAudioEnabled.toggle()
        engine.muteLocalAudioStream(!isLocalAudioEnabled)
        print("🎤 Local audio \(isLocalAudioEnabled ? "enabled" : "disabled")")
    }
    
    func toggleRemoteAudio() {
        guard let engine = engine else { return }
        isRemoteAudioEnabled.toggle()
        engine.muteAllRemoteAudioStreams(!isRemoteAudioEnabled)
        print("🔊 Remote audio \(isRemoteAudioEnabled ? "enabled" : "disabled")")
    }
}

// MARK: - AgoraRtcEngineDelegate
extension AgoraManager: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        print("\n🎉 Local user joined channel: \(channel)")
        print("   Local UID: \(uid)")
        print("   Role: \(currentRole == .broadcaster ? "broadcaster" : "audience")")
        print("   Time elapsed: \(elapsed)ms")
        print("   Has remote view: \(remoteView != nil)")
        print("   Has remote canvas: \(remoteVideoCanvas != nil)")
        print("   Remote UID: \(remoteUid?.description ?? "none")")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraChannelStats) {
        print("👋 Left channel")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("❌ Error occurred: \(errorCode.rawValue)")
        
        // Provide descriptive error messages based on error code
        let errorDescription: String
        switch errorCode {
        case .joinChannelRejected:
            errorDescription = "Join channel request was rejected"
        case .leaveChannelRejected:
            errorDescription = "Leave channel request was rejected"
        case .invalidChannelId:
            errorDescription = "Invalid channel ID"
        case .invalidAppId:
            errorDescription = "Invalid App ID"
        case .invalidToken:
            errorDescription = "Invalid token"
        case .tokenExpired:
            errorDescription = "Token has expired"
        case .notInChannel:
            errorDescription = "Not in channel"
        case .noServerResources:
            errorDescription = "No server resources available"
        default:
            // For any other error, include both code and a generic message
            let genericMessage: String
            if errorCode.rawValue >= 1001 && errorCode.rawValue <= 1009 {
                genericMessage = "Channel join error"
            } else if errorCode.rawValue >= 1010 && errorCode.rawValue <= 1019 {
                genericMessage = "Channel connection error"
            } else if errorCode.rawValue >= 1020 && errorCode.rawValue <= 1029 {
                genericMessage = "Video error"
            } else if errorCode.rawValue >= 1030 && errorCode.rawValue <= 1039 {
                genericMessage = "Audio error"
            } else {
                genericMessage = "General error"
            }
            errorDescription = "\(genericMessage) (Code: \(errorCode.rawValue))"
        }
        
        print("   Description: \(errorDescription)")
        error = errorDescription
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("\n👥 Remote user joined")
        print("   Remote UID: \(uid)")
        print("   Time elapsed: \(elapsed)ms")
        print("   Current role: \(currentRole == .broadcaster ? "broadcaster" : "audience")")
        print("   Is in channel: \(isInChannel)")
        print("   Channel name: \(currentChannelName ?? "none")")
        print("   Remote view ready: \(remoteView != nil)")
        print("   Has existing remote canvas: \(remoteVideoCanvas != nil)")
        
        // Store the UID first
        remoteUid = uid
        
        // If we have a view ready, set up remote video
        if let view = remoteView {
            print("🔄 Remote view available, setting up video")
            setupRemoteVideo(view: view, uid: uid)
        } else {
            print("⏳ Remote view not ready, storing UID \(uid) for later")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        print("👤 Remote user offline")
        print("   Remote UID: \(uid)")
        print("   Reason: \(reason)")
        
        // Only clear if this was our remote user
        if uid == remoteUid {
            print("🧹 Cleaning up remote video for uid: \(uid)")
            if let canvas = remoteVideoCanvas {
                engine.setupRemoteVideo(AgoraRtcVideoCanvas())
                canvas.view = nil
            }
            remoteVideoCanvas = nil
            remoteUid = nil
            print("✅ Remote video cleanup complete")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        print("\n🌐 Connection state changed")
        print("   State: \(connectionStateToString(state))")
        print("   Reason: \(connectionReasonToString(reason))")
        print("   Current role: \(currentRole == .broadcaster ? "broadcaster" : "audience")")
        print("   Is in channel: \(isInChannel)")
        print("   Channel name: \(currentChannelName ?? "none")")
        print("   Has remote view: \(remoteView != nil)")
        print("   Has remote canvas: \(remoteVideoCanvas != nil)")
        print("   Remote UID: \(remoteUid?.description ?? "none")")
    }
    
    private func connectionStateToString(_ state: AgoraConnectionState) -> String {
        switch state {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .reconnecting: return "Reconnecting"
        case .failed: return "Failed"
        @unknown default: return "Unknown (\(state.rawValue))"
        }
    }
    
    private func connectionReasonToString(_ reason: AgoraConnectionChangedReason) -> String {
        switch reason {
        case .reasonConnecting: return "Connecting"
        case .reasonJoinSuccess: return "Join Success"
        case .reasonInterrupted: return "Interrupted"
        case .reasonBannedByServer: return "Banned by Server"
        case .reasonJoinFailed: return "Join Failed"
        case .reasonLeaveChannel: return "Leave Channel"
        case .reasonInvalidAppId: return "Invalid App ID"
        case .reasonInvalidToken: return "Invalid Token"
        case .reasonTokenExpired: return "Token Expired"
        case .reasonRejectedByServer: return "Rejected by Server"
        case .reasonSettingProxyServer: return "Setting Proxy Server"
        case .reasonRenewToken: return "Renew Token"
        case .reasonClientIpAddressChanged: return "Client IP Changed"
        case .reasonKeepAliveTimeout: return "Keep Alive Timeout"
        @unknown default: 
            print("⚠️ Unhandled connection reason: \(reason.rawValue)")
            return "Unknown (\(reason.rawValue))"
        }
    }
} 