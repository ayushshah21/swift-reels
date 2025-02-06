import SwiftUI
import FirebaseAuth
import UIKit

struct TestVideoView: View {
    @StateObject private var agoraManager = AgoraManager.shared
    @StateObject private var firestoreManager = FirestoreManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var currentSession: LiveSession?
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
            
            VStack {
                HStack {
                    Button(action: {
                        Task {
                            if let session = currentSession {
                                try? await firestoreManager.endLiveSession(session.id ?? "")
                            }
                            agoraManager.leaveChannel()
                            dismiss()
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
                                currentSession = nil
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
        .onAppear {
            if let session = joinSession {
                Task {
                    print("Setting up for joining session")
                    agoraManager.setRole(.audience)
                    currentSession = session
                    
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