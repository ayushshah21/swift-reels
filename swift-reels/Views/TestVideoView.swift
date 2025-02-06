import SwiftUI
import FirebaseAuth
import UIKit

struct TestVideoView: View {
    @StateObject private var agoraManager = AgoraManager.shared
    @StateObject private var firestoreManager = FirestoreManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var currentSession: LiveSession?
    @State private var streamHasEnded = false
    var joinSession: LiveSession?
    
    var body: some View {
        ZStack {
            if joinSession != nil {
                // For audience, create the remote view container first
                RemoteVideoContainer()
                    .ignoresSafeArea()
            } else {
                // For broadcaster, use regular AgoraVideoView
                AgoraVideoView()
                    .ignoresSafeArea()
            }
            
            // Stream ended overlay
            if streamHasEnded {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "tv.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    
                    Text("Live Stream Has Ended")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Return to Feed")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
            
            // Regular controls overlay
            if !streamHasEnded {
                VStack {
                    HStack {
                        Button(action: {
                            Task {
                                if let session = currentSession {
                                    try? await firestoreManager.endLiveSession(session.id ?? "")
                                }
                                agoraManager.leaveChannel()
                                if joinSession != nil {
                                    // We're an audience member, just dismiss
                                    dismiss()
                                } else {
                                    // We're the broadcaster, mark stream as ended
                                    streamHasEnded = true
                                }
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        .padding()
                        
                        Spacer()
                        
                        if joinSession == nil {
                            Button(action: {
                                agoraManager.switchCamera()
                            }) {
                                Image(systemName: "camera.rotate")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                            .padding()
                        }
                    }
                    
                    Spacer()
                    
                    // Audio Controls
                    AudioControlsView(isBroadcaster: joinSession == nil)
                        .padding(.bottom, 30)
                    
                    if joinSession == nil {
                        Button(action: {
                            Task {
                                if currentSession == nil {
                                    // Start new live session
                                    if let userId = Auth.auth().currentUser?.uid,
                                       let userEmail = Auth.auth().currentUser?.email {
                                        let channelName = "test_channel_\(Int(Date().timeIntervalSince1970))"
                                        print("🎥 Creating live session for host: \(userEmail)")
                                        
                                        do {
                                            let session = try await firestoreManager.createLiveSession(
                                                hostId: userId,
                                                hostName: userEmail,
                                                channelId: channelName
                                            )
                                            currentSession = session
                                            print("✅ Created live session: \(session.id ?? "")")
                                            
                                            // Small delay to ensure view is ready
                                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                                            print("Joining channel as broadcaster")
                                            await agoraManager.joinChannel(channelName)
                                        } catch {
                                            print("❌ Error creating live session: \(error.localizedDescription)")
                                        }
                                    }
                                } else {
                                    // End live session
                                    if let session = currentSession {
                                        try? await firestoreManager.endLiveSession(session.id ?? "")
                                    }
                                    agoraManager.leaveChannel()
                                    streamHasEnded = true
                                }
                            }
                        }) {
                            Text(currentSession == nil ? "Go Live" : "End Stream")
                                .foregroundColor(.white)
                                .padding()
                                .background(currentSession == nil ? Color.blue : Color.red)
                                .cornerRadius(8)
                        }
                        .padding(.bottom, 50)
                    }
                }
            }
        }
        .onAppear {
            if let session = joinSession {
                Task {
                    print("Setting up for joining session")
                    agoraManager.setRole(.audience)
                    currentSession = session
                    
                    // Start listening for session status
                    listenToSessionStatus(session)
                    
                    // Small delay to ensure view is ready
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                    print("Joining channel as audience")
                    await agoraManager.joinChannel(session.channelId)
                }
            } else {
                print("Setting initial broadcaster role")
                agoraManager.setRole(.broadcaster)
            }
        }
        .onDisappear {
            agoraManager.leaveChannel()
        }
    }
    
    private func listenToSessionStatus(_ session: LiveSession) {
        // Add a listener for the session's active status
        Task {
            for try await updatedSession in firestoreManager.liveSessionUpdates(sessionId: session.id ?? "") {
                if !updatedSession.isActive {
                    // Stream has ended
                    streamHasEnded = true
                    agoraManager.leaveChannel()
                }
            }
        }
    }
}

struct AudioControlsView: View {
    @StateObject private var agoraManager = AgoraManager.shared
    let isBroadcaster: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            if isBroadcaster {
                // Microphone control for broadcaster
                Button(action: {
                    agoraManager.toggleLocalAudio()
                }) {
                    Image(systemName: agoraManager.isLocalAudioEnabled ? "mic.fill" : "mic.slash.fill")
                        .font(.title2)
                        .foregroundColor(agoraManager.isLocalAudioEnabled ? .white : .red)
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            
            // Speaker control for everyone
            Button(action: {
                agoraManager.toggleRemoteAudio()
            }) {
                Image(systemName: agoraManager.isRemoteAudioEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.title2)
                    .foregroundColor(agoraManager.isRemoteAudioEnabled ? .white : .red)
                    .padding(12)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
        }
    }
}

// Remote video container with coordinator
struct RemoteVideoContainer: UIViewRepresentable {
    class Coordinator: NSObject {
        var containerView: UIView?
        var remoteView: UIView?
        
        func setupRemoteView() {
            guard let containerView = containerView else { return }
            
            // Create remote view
            let remote = UIView(frame: containerView.bounds)
            remote.backgroundColor = .clear
            remote.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.addSubview(remote)
            
            // Store reference
            self.remoteView = remote
            
            // Set up in Agora manager
            print("📱 Setting up remote view in coordinator")
            print("   Container frame: \(containerView.frame)")
            print("   Remote frame: \(remote.frame)")
            
            DispatchQueue.main.async {
                AgoraManager.shared.setupInitialRemoteVideo(view: remote)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        view.backgroundColor = .black
        
        // Store container view reference
        context.coordinator.containerView = view
        
        // Set up remote view after a brief delay to ensure proper frame
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            context.coordinator.setupRemoteView()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update frames if needed
        if let remoteView = context.coordinator.remoteView {
            remoteView.frame = uiView.bounds
        }
    }
} 