import SwiftUI
import FirebaseAuth

struct PartnerSessionsView: View {
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var availableSessions: [PartnerSession] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var selectedSession: PartnerSession?
    @State private var showCreateSheet = false
    @State private var showPartnerWorkout = false
    @State private var createdSession: PartnerSession?
    @State private var showCommunityReels = false
    
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else if availableSessions.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "figure.2.arms.open")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No partner sessions available")
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        showCreateSheet = true
                    }) {
                        Text("Create Session")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            // Community Reels Button
                            Button(action: {
                                showCommunityReels = true
                            }) {
                                Image(systemName: "video.bubble.left")
                                    .symbolRenderingMode(.hierarchical)
                                    .font(.system(size: 18))
                            }
                            
                            // Create Session Button
                            Button(action: {
                                showCreateSheet = true
                            }) {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            } else {
                List(availableSessions) { session in
                    Button(action: {
                        selectedSession = session
                    }) {
                        PartnerSessionRow(session: session)
                    }
                }
                .refreshable {
                    await loadSessions()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            // Community Reels Button
                            Button(action: {
                                showCommunityReels = true
                            }) {
                                Image(systemName: "video.bubble.left")
                                    .symbolRenderingMode(.hierarchical)
                                    .font(.system(size: 18))
                            }
                            
                            // Create Session Button
                            Button(action: {
                                showCreateSheet = true
                            }) {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Partner Workouts")
        .task {
            await loadSessions()
        }
        .onReceive(timer) { _ in
            Task {
                await loadSessions()
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreatePartnerSessionView { session in
                createdSession = session
                showPartnerWorkout = true
            }
        }
        .alert("Join Session", isPresented: .constant(selectedSession != nil)) {
            if let session = selectedSession {
                Button("Join") {
                    joinSession(session)
                }
                Button("Cancel", role: .cancel) {
                    selectedSession = nil
                }
            }
        } message: {
            if let session = selectedSession {
                Text("Would you like to join \(session.workoutType.rawValue) workout for \(session.durationMinutes) minutes?")
            }
        }
        .fullScreenCover(isPresented: $showPartnerWorkout) {
            if let session = createdSession {
                PartnerWorkoutView(session: session, isHost: true)
            }
        }
        .fullScreenCover(isPresented: $showCommunityReels) {
            NavigationStack {
                CommunityReelsView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                showCommunityReels = false
                            }
                        }
                    }
            }
        }
    }
    
    private func loadSessions() async {
        isLoading = true
        do {
            availableSessions = try await firestoreManager.getAvailablePartnerSessions()
            error = nil
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    private func joinSession(_ session: PartnerSession) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            do {
                try await firestoreManager.joinPartnerSession(session.id ?? "", partnerId: userId)
                selectedSession = nil
                createdSession = session
                showPartnerWorkout = true
            } catch {
                self.error = error
            }
        }
    }
}

struct PartnerSessionRow: View {
    let session: PartnerSession
    @State private var hostUser: User?
    @StateObject private var firestoreManager = FirestoreManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.2.arms.open")
                    .font(.title2)
                Text(session.workoutType.rawValue.capitalized)
                    .font(.headline)
                Spacer()
                Text("AVAILABLE")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            if let host = hostUser {
                HStack {
                    Text(host.username ?? host.email)
                        .font(.subheadline)
                    
                    if host.totalRatings > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", host.averageRating))
                            Text("(\(host.totalRatings))")
                                .foregroundColor(.gray)
                        }
                        .font(.caption)
                    }
                }
            }
            
            Text("\(session.durationMinutes) minute workout")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .task {
            // Load host user data
            if hostUser == nil {
                do {
                    hostUser = try await firestoreManager.getUser(id: session.hostId)
                } catch {
                    print("❌ Error loading host data: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct CreatePartnerSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var selectedType: WorkoutType = .hiit
    @State private var duration = 30
    @State private var isCreating = false
    @State private var error: Error?
    
    let onSessionCreated: (PartnerSession) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(WorkoutType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Duration") {
                    Picker("Minutes", selection: $duration) {
                        ForEach([15, 30, 45, 60], id: \.self) { mins in
                            Text("\(mins) minutes")
                                .tag(mins)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Create Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createSession()
                    }
                    .disabled(isCreating)
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    private func createSession() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isCreating = true
        Task {
            do {
                let session = try await firestoreManager.createPartnerSession(
                    hostId: userId,
                    workoutType: selectedType,
                    durationMinutes: duration
                )
                await MainActor.run {
                    dismiss()
                    onSessionCreated(session)
                }
            } catch {
                self.error = error
            }
            isCreating = false
        }
    }
} 