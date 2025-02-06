import SwiftUI
import AgoraRtcKit
import FirebaseAuth

struct PartnerWorkoutView: View {
    let session: PartnerSession
    let isHost: Bool
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var agoraManager = AgoraManager.shared
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var showEndConfirmation = false
    @State private var sessionHasEnded = false
    @State private var error: String?
    @State private var isInitialized = false
    @State private var showRating = false
    @State private var selectedRating = 0
    @State private var hasSubmittedRating = false
    @State private var currentSession: PartnerSession
    
    init(session: PartnerSession, isHost: Bool) {
        self.session = session
        self.isHost = isHost
        self._currentSession = State(initialValue: session)
    }
    
    private var safeAreaBottom: CGFloat {
        UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
    }
    
    private var partnerUserId: String {
        // If we're the host, rate the partner, if we're the partner, rate the host
        let userId = if isHost {
            currentSession.partnerId ?? ""
        } else {
            currentSession.hostId
        }
        print("🔄 Getting partner userId:")
        print("   Is Host: \(isHost)")
        print("   Session Host ID: \(currentSession.hostId)")
        print("   Session Partner ID: \(currentSession.partnerId ?? "nil")")
        print("   Selected User to Rate: \(userId)")
        return userId
    }
    
    private var canSubmitRating: Bool {
        // Only allow rating if we have a valid partner to rate
        let canSubmit = if isHost {
            currentSession.partnerId != nil && !currentSession.partnerId!.isEmpty
        } else {
            !currentSession.hostId.isEmpty
        }
        print("🔄 Checking if can submit rating:")
        print("   Is Host: \(isHost)")
        print("   Session Host ID: \(currentSession.hostId)")
        print("   Session Partner ID: \(currentSession.partnerId ?? "nil")")
        print("   Can Submit: \(canSubmit)")
        return canSubmit
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            if isInitialized {
                // Split screen layout
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Top half - Host video
                        ZStack {
                            if isHost {
                                AgoraVideoView()
                            } else {
                                RemoteVideoContainer()
                            }
                        }
                        .frame(height: geometry.size.height / 2)
                        
                        // Bottom half - Partner video
                        ZStack {
                            if isHost {
                                RemoteVideoContainer()
                            } else {
                                AgoraVideoView()
                            }
                        }
                        .frame(height: geometry.size.height / 2)
                    }
                }
                
                // Overlay controls
                VStack {
                    Spacer()
                    
                    // Session info
                    VStack(spacing: 8) {
                        Text(session.workoutType.rawValue.capitalized)
                            .font(.headline)
                        Text("\(session.durationMinutes) minutes")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    // Controls
                    VStack(spacing: 20) {
                        // Audio Controls
                        AudioControlsView(isBroadcaster: true)
                        
                        HStack(spacing: 30) {
                            // Camera Flip Button
                            Button(action: {
                                agoraManager.switchCamera()
                            }) {
                                Image(systemName: "camera.rotate")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            
                            // End Session Button
                            Button(action: {
                                showEndConfirmation = true
                            }) {
                                Text("End Workout")
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.red)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.bottom, safeAreaBottom + 20)
                }
            } else {
                // Loading state
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
            
            // Session ended overlay with rating
            if sessionHasEnded {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Workout Complete!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    if canSubmitRating {
                        if !hasSubmittedRating {
                            Text("Rate your workout partner")
                                .foregroundColor(.white)
                                .padding(.top)
                            
                            // Star Rating
                            HStack(spacing: 12) {
                                ForEach(1...5, id: \.self) { rating in
                                    Image(systemName: rating <= selectedRating ? "star.fill" : "star")
                                        .font(.title)
                                        .foregroundColor(rating <= selectedRating ? .yellow : .gray)
                                        .onTapGesture {
                                            selectedRating = rating
                                        }
                                }
                            }
                            .padding(.vertical)
                            
                            // Submit Rating Button
                            Button(action: submitRating) {
                                Text("Submit Rating")
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 12)
                                    .background(selectedRating > 0 ? Color.blue : Color.gray)
                                    .cornerRadius(8)
                            }
                            .disabled(selectedRating == 0)
                        } else {
                            Text("Thanks for your feedback!")
                                .foregroundColor(.white)
                                .padding(.vertical)
                        }
                    }
                    
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
        }
        .alert("End Workout", isPresented: $showEndConfirmation) {
            Button("End", role: .destructive) {
                endSession()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to end this workout session?")
        }
        .alert("Error", isPresented: .constant(error != nil), actions: {
            Button("OK") {
                error = nil
            }
        }, message: {
            if let error = error {
                Text(error)
            }
        })
        .task {
            // Ensure proper initialization sequence
            await setupSession()
        }
        .onDisappear {
            cleanupSession()
        }
    }
    
    private func setupSession() async {
        print("🔄 Setting up partner workout session")
        print("   Channel ID: \(session.channelId)")
        print("   Is Host: \(isHost)")
        
        // Reset Agora state
        agoraManager.leaveChannel()
        
        // Both users are broadcasters in partner mode
        agoraManager.setRole(.broadcaster)
        
        // Small delay to ensure proper initialization
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // Join the channel
        await agoraManager.joinChannel(session.channelId)
        
        // Start listening for session updates
        listenToSessionStatus()
        
        // Mark as initialized
        withAnimation {
            isInitialized = true
        }
        
        print("✅ Partner workout session setup complete")
    }
    
    private func cleanupSession() {
        print("🧹 Cleaning up partner workout session")
        agoraManager.leaveChannel()
        isInitialized = false
    }
    
    private func listenToSessionStatus() {
        Task {
            for try await updatedSession in firestoreManager.partnerSessionUpdates(sessionId: session.id ?? "") {
                await MainActor.run {
                    // Update our current session state
                    currentSession = updatedSession
                    
                    if updatedSession.status == .ended {
                        sessionHasEnded = true
                        cleanupSession()
                    }
                }
            }
        }
    }
    
    private func endSession() {
        Task {
            do {
                if let sessionId = session.id {
                    try await firestoreManager.endPartnerSession(sessionId)
                }
                cleanupSession()
                sessionHasEnded = true
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
    
    private func submitRating() {
        print("🌟 Attempting to submit rating:")
        print("   Selected Rating: \(selectedRating)")
        print("   Partner User ID: \(partnerUserId)")
        print("   Can Submit Rating: \(canSubmitRating)")
        
        guard selectedRating > 0 else { 
            print("❌ Rating submission failed: No rating selected")
            return 
        }
        guard canSubmitRating else {
            print("❌ Rating submission failed: No valid partner to rate")
            self.error = "Cannot submit rating: No valid partner to rate"
            return
        }
        
        Task {
            do {
                print("✅ Submitting rating \(selectedRating) for user \(partnerUserId)")
                try await firestoreManager.submitUserRating(userId: partnerUserId, rating: selectedRating)
                await MainActor.run {
                    hasSubmittedRating = true
                }
                print("✅ Rating submitted successfully")
            } catch {
                print("❌ Rating submission failed with error: \(error.localizedDescription)")
                self.error = error.localizedDescription
            }
        }
    }
} 