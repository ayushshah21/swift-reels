import SwiftUI
import FirebaseAuth
import UIKit

struct TestVideoView: View {
    @StateObject private var agoraManager = AgoraManager.shared
    @StateObject private var firestoreManager = FirestoreManager.shared
    @StateObject private var speechManager = SpeechRecognitionManager.shared
    @StateObject private var openAIManager = OpenAIManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var currentSession: LiveSession?
    @State private var streamHasEnded = false
    @State private var isRecordingWorkout = false
    @State private var generatedWorkout: String?
    @State private var isGeneratingWorkout = false
    @State private var error: String?
    @State private var showSpeechPermissionAlert = false
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
                
                ScrollView {
                    VStack(spacing: 20) {
                        Image(systemName: "tv.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                        
                        Text("Live Stream Has Ended")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        if isGeneratingWorkout {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.white)
                                Text("Generating your workout plan...")
                                    .foregroundColor(.white)
                                Text("This may take a few moments")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        } else if let workout = generatedWorkout {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Your Workout Plan")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 20) {
                                        Text("Generated from your instructions:")
                                            .foregroundColor(.gray)
                                            .padding(.bottom)
                                        
                                        Text(workout)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.black.opacity(0.6))
                                            .cornerRadius(12)
                                    }
                                }
                                .frame(maxHeight: 400)
                                .padding()
                            }
                            .padding()
                        } else {
                            // Debug information when no workout is shown
                            VStack(spacing: 12) {
                                Text("No workout generated")
                                    .foregroundColor(.white)
                                Text("Transcript available: \(!speechManager.transcript.isEmpty)")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                if !speechManager.transcript.isEmpty {
                                    Text("Transcript length: \(speechManager.transcript.count) characters")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                            }
                            .padding()
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
                    .padding()
                }
            }
            
            // Regular controls overlay
            if !streamHasEnded {
                VStack {
                    // Top controls (close, camera flip)
                    HStack {
                        Button(action: {
                            Task {
                                if joinSession != nil {
                                    if let session = currentSession {
                                        try? await firestoreManager.endLiveSession(session.id ?? "")
                                    }
                                    agoraManager.leaveChannel()
                                    dismiss()
                                } else {
                                    // For broadcaster, use endSession to properly handle workout generation
                                    Task {
                                        await endSession()
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        .padding()
                        
                        Spacer()
                        
                        // Record Workout Button (only for broadcaster when live)
                        if joinSession == nil && currentSession != nil {
                            Button(action: {
                                Task {
                                    if isRecordingWorkout {
                                        speechManager.stopRecording()
                                        isRecordingWorkout = false
                                    } else {
                                        do {
                                            try await speechManager.startRecording(inLiveStream: true)
                                            isRecordingWorkout = true
                                        } catch {
                                            print("❌ Failed to start recording:", error.localizedDescription)
                                        }
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: recordingIcon)
                                        .font(.title2)
                                    Text(recordingButtonText)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 8)
                                .background(recordingButtonColor)
                                .cornerRadius(20)
                            }
                            .padding(.horizontal)
                            
                            if speechManager.recordingStatus == .noSpeechDetected {
                                Text("Tap microphone to try again")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.top, 4)
                            }
                        }
                        
                        if joinSession == nil {
                            // Camera flip button
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
                    
                    // Transcript display with status
                    Group {
                        // Remove transcript display but keep recording status for debugging
                        if isRecordingWorkout && speechManager.recordingStatus == .noSpeechDetected {
                            Text("Tap microphone to try again")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.top, 4)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 20) {
                        // Audio Controls
                        AudioControlsView(isBroadcaster: joinSession == nil)
                        
                        // Speech Recognition Controls (only for broadcaster)
                        if joinSession == nil && currentSession != nil {
                            Button(action: {
                                Task {
                                    if isRecordingWorkout {
                                        speechManager.stopRecording()
                                        isRecordingWorkout = false
                                    } else {
                                        do {
                                            try await speechManager.startRecording(inLiveStream: true)
                                            isRecordingWorkout = true
                                        } catch {
                                            print("❌ Failed to start recording:", error.localizedDescription)
                                        }
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: isRecordingWorkout ? "mic.circle.fill" : "mic.slash.circle.fill")
                                        .foregroundColor(isRecordingWorkout ? .green : .white)
                                }
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                            }
                        }
                        
                        // Go Live / End Stream button
                        if joinSession == nil {
                            Button(action: {
                                Task {
                                    if currentSession == nil {
                                        // Start new live session with permission check
                                        if let userId = Auth.auth().currentUser?.uid,
                                           let userEmail = Auth.auth().currentUser?.email {
                                            
                                            // First check speech recognition permission
                                            let authorized = await speechManager.requestAuthorization()
                                            if !authorized {
                                                // Show settings alert if permission denied
                                                showSpeechPermissionAlert = true
                                                return
                                            }
                                            
                                            // Create channel and start session
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
                                                
                                                try? await Task.sleep(nanoseconds: 500_000_000)
                                                print("Joining channel as broadcaster")
                                                await agoraManager.joinChannel(channelName)
                                            } catch {
                                                print("❌ Error creating live session: \(error.localizedDescription)")
                                                self.error = "Failed to start live session: \(error.localizedDescription)"
                                            }
                                        }
                                    } else {
                                        // End live session using endSession function
                                        await endSession()
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
        .onChange(of: speechManager.transcript) { newTranscript in
            // Only update if we're the broadcaster and have an active session
            if joinSession == nil, let session = currentSession {
                Task {
                    do {
                        try await firestoreManager.updateLiveSessionTranscript(session.id ?? "", transcript: newTranscript)
                    } catch {
                        print("❌ Failed to update transcript:", error.localizedDescription)
                    }
                }
            }
        }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") {
                error = nil
            }
        } message: {
            if let error = error {
                Text(error)
            }
        }
        .alert("Speech Permission Required", isPresented: $showSpeechPermissionAlert) {
            Button("Enable in Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) {
                // User chose not to enable speech recognition
                self.error = "Speech recognition is required to record workout instructions during live streams. You can enable it in Settings later."
            }
        } message: {
            Text("To record your workout instructions during live streams, Swift Reels needs permission to access speech recognition. Your instructions will be used to generate structured workout plans for your viewers.")
        }
    }
    
    private func listenToSessionStatus(_ session: LiveSession) {
        // Add a listener for the session's active status
        Task {
            for try await updatedSession in firestoreManager.liveSessionUpdates(sessionId: session.id ?? "") {
                await MainActor.run {
                    if !updatedSession.isActive {
                        // Stream has ended
                        streamHasEnded = true
                        agoraManager.leaveChannel()
                        
                        // If we're a viewer and there's a transcript but no workout yet,
                        // show loading state
                        if joinSession != nil && 
                           updatedSession.workoutTranscript?.isEmpty == false && 
                           updatedSession.generatedWorkout == nil {
                            isGeneratingWorkout = true
                        }
                        
                        // Get the generated workout if available
                        if let workout = updatedSession.generatedWorkout {
                            generatedWorkout = workout
                            isGeneratingWorkout = false
                            print("✅ Retrieved workout from live session")
                        } else if updatedSession.workoutTranscript?.isEmpty != false {
                            // Only show no workout message if there was no transcript
                            isGeneratingWorkout = false
                            print("⚠️ No workout available in live session")
                        }
                    }
                }
            }
        }
    }
    
    private var recordingIcon: String {
        switch speechManager.recordingStatus {
        case .recording:
            return "stop.circle.fill"
        case .listening:
            return "waveform.circle.fill"
        case .noSpeechDetected:
            return "mic.slash.circle.fill"
        default:
            return "mic.circle.fill"
        }
    }
    
    private var recordingButtonText: String {
        switch speechManager.recordingStatus {
        case .recording:
            return "Stop"
        case .listening:
            return "Listening..."
        case .noSpeechDetected:
            return "Try Again"
        default:
            return "Record"
        }
    }
    
    private var recordingButtonColor: Color {
        switch speechManager.recordingStatus {
        case .recording:
            return .red
        case .listening:
            return .blue
        case .noSpeechDetected:
            return .orange
        default:
            return .green
        }
    }
    
    private func endSession() async {
        print("\n🔄 Starting end session process...")
        
        do {
            if let sessionId = currentSession?.id {
                // 1. First stop recording and save transcript
                let finalTranscript = speechManager.transcript
                if isRecordingWorkout {
                    print("🎤 Stopping workout recording")
                    speechManager.stopRecording()
                    isRecordingWorkout = false
                }
                
                // 2. End the live session and cleanup
                try await firestoreManager.endLiveSession(sessionId)
                print("\n✅ Live session ended successfully")
                cleanupSession()
                
                // 3. Show end screen
                await MainActor.run {
                    streamHasEnded = true
                }
                
                // 4. Generate workout if we have a transcript
                if !finalTranscript.isEmpty {
                    print("\n📝 Starting workout generation from transcript:")
                    print(finalTranscript)
                    
                    await MainActor.run {
                        isGeneratingWorkout = true
                    }
                    
                    do {
                        let parsedWorkout = try await openAIManager.generateStructuredWorkout(from: finalTranscript)
                        print("\n✅ Generated workout structure:")
                        print("   Title: \(parsedWorkout.title)")
                        print("   Type: \(parsedWorkout.type.rawValue)")
                        print("   Difficulty: \(parsedWorkout.difficulty)")
                        print("   Duration: \(parsedWorkout.estimatedDuration) minutes")
                        print("   Equipment: \(parsedWorkout.equipment.joined(separator: ", "))")
                        
                        // Create SavedWorkout instance
                        let savedWorkout = SavedWorkout(
                            id: nil,
                            userId: Auth.auth().currentUser?.uid ?? "",
                            title: parsedWorkout.title,
                            workoutPlan: parsedWorkout.workoutPlan,
                            createdAt: Date(),
                            sourceSessionId: sessionId,
                            type: parsedWorkout.type,
                            difficulty: parsedWorkout.difficulty,
                            equipment: parsedWorkout.equipment,
                            estimatedDuration: parsedWorkout.estimatedDuration
                        )
                        
                        // Save to Firestore
                        let workoutId = try await firestoreManager.saveWorkout(savedWorkout)
                        print("\n💾 Saved workout to Firestore with ID: \(workoutId)")
                        
                        // Update UI with generated workout
                        await MainActor.run {
                            generatedWorkout = parsedWorkout.workoutPlan
                            isGeneratingWorkout = false
                        }
                        
                        // Update live session with the generated workout
                        try await firestoreManager.updateLiveSessionWorkout(sessionId, workout: parsedWorkout.workoutPlan)
                        print("\n✅ Updated live session with generated workout")
                    } catch {
                        print("\n❌ Failed to generate workout:", error.localizedDescription)
                        await MainActor.run {
                            self.error = "Failed to generate workout: \(error.localizedDescription)"
                            isGeneratingWorkout = false
                        }
                    }
                } else {
                    print("\n⚠️ No transcript available for workout generation")
                }
            }
        } catch {
            print("\n❌ Error ending session:", error.localizedDescription)
            await MainActor.run {
                self.error = error.localizedDescription
                streamHasEnded = true
            }
        }
    }
    
    private func cleanupSession() {
        agoraManager.leaveChannel()
        if isRecordingWorkout {
            speechManager.stopRecording()
            isRecordingWorkout = false
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