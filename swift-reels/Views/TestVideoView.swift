import SwiftUI
import FirebaseAuth

struct TestVideoView: View {
    @StateObject private var agoraManager = AgoraManager.shared
    @StateObject private var firestoreManager = FirestoreManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var currentSession: LiveSession?
    var joinSession: LiveSession?
    
    var body: some View {
        ZStack {
            AgoraVideoView()
                .ignoresSafeArea()
            
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
                                        
                                        // Set role and join channel
                                        agoraManager.setRole(.broadcaster)
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
                // Join existing session as audience
                currentSession = session
                agoraManager.setRole(.audience)
                Task {
                    await agoraManager.joinChannel(session.channelId)
                }
            } else {
                // Set up for broadcasting
                agoraManager.setRole(.broadcaster)
            }
        }
        .onDisappear {
            agoraManager.leaveChannel()
        }
    }
} 