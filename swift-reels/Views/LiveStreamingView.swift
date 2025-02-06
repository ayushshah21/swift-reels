import SwiftUI
import FirebaseAuth

struct LiveStreamingView: View {
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var activeSessions: [LiveSession] = []
    @State private var isLoading = true
    @State private var showCreateStream = false
    @State private var error: Error?
    
    private let accentColor = Color(red: 0.35, green: 0.47, blue: 0.95) // Softer blue
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with Create Live button
                HStack {
                    Text("Live")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        showCreateStream = true
                    }) {
                        HStack {
                            Image(systemName: "video.fill")
                            Text("Go Live")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(accentColor)
                        .cornerRadius(20)
                    }
                }
                .padding()
                
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = error {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error.localizedDescription)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else if activeSessions.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Live Sessions")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("Be the first to go live!")
                            .foregroundColor(.gray)
                        Button(action: {
                            showCreateStream = true
                        }) {
                            Text("Start Streaming")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(accentColor)
                                .cornerRadius(8)
                        }
                    }
                    Spacer()
                } else {
                    // Live sessions list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(activeSessions) { session in
                                LiveSessionCard(session: session, accentColor: accentColor)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateStream) {
            TestVideoView()
        }
        .task {
            await loadLiveSessions()
        }
        .refreshable {
            await loadLiveSessions()
        }
    }
    
    private func loadLiveSessions() async {
        isLoading = true
        do {
            activeSessions = try await firestoreManager.getActiveLiveSessions()
            error = nil
        } catch {
            self.error = error
            print("❌ Error loading live sessions: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

struct LiveSessionCard: View {
    let session: LiveSession
    let accentColor: Color
    @State private var showJoinSheet = false
    
    var body: some View {
        Button(action: {
            showJoinSheet = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Host info
                    HStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading) {
                            Text(session.hostName)
                                .font(.headline)
                            Text("Live Now")
                                .font(.caption)
                                .foregroundColor(accentColor)
                        }
                    }
                    
                    Spacer()
                    
                    // Viewer count
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .imageScale(.small)
                        Text("\(session.viewerCount)")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                
                // Join button
                HStack {
                    Spacer()
                    Text("Join Stream")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(accentColor)
                        .cornerRadius(16)
                    Spacer()
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showJoinSheet) {
            TestVideoView(joinSession: session)
        }
    }
} 