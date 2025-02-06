import SwiftUI

struct LiveSessionsView: View {
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var liveSessions: [LiveSession] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var selectedSession: LiveSession?
    
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
            } else if liveSessions.isEmpty {
                VStack {
                    Image(systemName: "video.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No live sessions available")
                        .foregroundColor(.gray)
                }
            } else {
                List(liveSessions) { session in
                    Button(action: {
                        selectedSession = session
                    }) {
                        LiveSessionRow(session: session)
                    }
                }
            }
        }
        .navigationTitle("Live Sessions")
        .task {
            await loadLiveSessions()
        }
        .refreshable {
            await loadLiveSessions()
        }
        .sheet(item: $selectedSession) { session in
            TestVideoView(joinSession: session)
        }
        .onReceive(timer) { _ in
            Task {
                await loadLiveSessions()
            }
        }
    }
    
    private func loadLiveSessions() async {
        print("🔄 Loading live sessions...")
        isLoading = true
        do {
            liveSessions = try await firestoreManager.getActiveLiveSessions()
            print("✅ Found \(liveSessions.count) active sessions")
            error = nil
        } catch {
            self.error = error
            print("❌ Error loading live sessions: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

struct LiveSessionRow: View {
    let session: LiveSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                Text(session.hostName)
                    .font(.headline)
                Spacer()
                Text("LIVE")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            HStack {
                Image(systemName: "person.2")
                Text("\(session.viewerCount) watching")
                    .foregroundColor(.gray)
            }
            .font(.caption)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
} 