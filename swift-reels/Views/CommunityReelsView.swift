import SwiftUI
import AVKit
import FirebaseAuth
import FirebaseFirestore

struct CommunityReelsView: View {
    @StateObject private var firestoreManager = FirestoreManager.shared
    @StateObject private var playerManager = VideoPlayerManager.shared
    @State private var reels: [CommunityReel] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var currentIndex = 0
    @AppStorage("uid") private var uid: String = ""
    
    var body: some View {
        NavigationStack {
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
                } else if reels.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No community reels yet")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                } else {
                    GeometryReader { geometry in
                        TabView(selection: $currentIndex) {
                            ForEach(Array(reels.enumerated()), id: \.element.id) { index, reel in
                                CommunityReelView(reel: reel, onDelete: {
                                    deleteReel(reel)
                                })
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .tag(index)
                                .rotationEffect(.degrees(-90))
                            }
                        }
                        .frame(
                            width: geometry.size.height,
                            height: geometry.size.width
                        )
                        .rotationEffect(.degrees(90), anchor: .topLeading)
                        .offset(x: geometry.size.width)
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .ignoresSafeArea()
                    }
                    .ignoresSafeArea()
                }
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadReels()
        }
        .refreshable {
            await loadReels()
        }
        .onDisappear {
            playerManager.cleanupCache()
        }
    }
    
    private func loadReels() async {
        isLoading = true
        do {
            reels = try await firestoreManager.getCommunityReels()
            error = nil
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    private func deleteReel(_ reel: CommunityReel) {
        guard reel.participants.contains(where: { $0 == uid }) else { return }
        
        Task {
            do {
                guard let reelId = reel.id else {
                    print("❌ Cannot delete reel: missing ID")
                    return
                }
                
                // First remove from local array for immediate feedback
                await MainActor.run {
                    withAnimation {
                        if let index = reels.firstIndex(where: { r in r.id == reel.id }) {
                            reels.remove(at: index)
                            // If we're at the last reel, move to previous
                            if currentIndex >= reels.count {
                                currentIndex = max(reels.count - 1, 0)
                            }
                        }
                    }
                }
                
                // Then delete from backend
                try await firestoreManager.deleteCommunityReel(reelId)
            } catch {
                print("Error deleting reel: \(error)")
                // If deletion failed, reload reels
                await loadReels()
            }
        }
    }
}

struct CommunityReelView: View {
    let reel: CommunityReel
    let onDelete: () -> Void
    @StateObject private var firestoreManager = FirestoreManager.shared
    @StateObject private var playerManager = VideoPlayerManager.shared
    @State private var participants: [User] = []
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var isLoading = true
    @State private var showDeleteAlert = false
    @State private var isOwner = false
    @State private var showDeleteButton = false
    
    private var safeAreaBottom: CGFloat {
        UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let player = player {
                    CustomVideoPlayer(player: player)
                        .aspectRatio(9/16, contentMode: .fit)
                        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                        .onTapGesture {
                            if isPlaying {
                                player.pause()
                            } else {
                                player.play()
                            }
                            isPlaying.toggle()
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            if isOwner {
                                withAnimation(.spring()) {
                                    showDeleteButton.toggle()
                                }
                            }
                        }
                }
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.5)
                }
                
                // Overlay Controls
                VStack {
                    Spacer()
                    
                    // Delete button overlay (centered)
                    if showDeleteButton && isOwner {
                        Button(action: { showDeleteAlert = true }) {
                            VStack(spacing: 12) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 50))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .red)
                                Text("Delete Reel")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .padding(20)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(15)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Spacer()
                    
                    // Video Info
                    HStack(alignment: .bottom, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            // Participants
                            if !participants.isEmpty {
                                HStack {
                                    ForEach(participants) { user in
                                        Text(user.username)
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, safeAreaBottom + 20)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .alert("Delete Reel", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                withAnimation {
                    showDeleteButton = false
                }
                onDelete()
            }
            Button("Cancel", role: .cancel) {
                withAnimation {
                    showDeleteButton = false
                }
            }
        } message: {
            Text("Are you sure you want to delete this reel? This action cannot be undone.")
        }
        .task {
            isLoading = true
            
            // Check if current user is the owner
            if let currentUserId = Auth.auth().currentUser?.uid {
                isOwner = reel.participants.contains(currentUserId)
            }
            
            // Initialize player
            let player = await playerManager.player(for: reel.videoURL)
            player.actionAtItemEnd = .none
            player.isMuted = false
            
            // Remove any existing observers before adding new one
            NotificationCenter.default.removeObserver(self)
            
            // Add observer for video end
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                Task {
                    await player.seek(to: .zero)
                    player.play()
                }
            }
            
            self.player = player
            player.play()
            isPlaying = true
            isLoading = false
            
            // Load participants
            await loadParticipants()
        }
        .onDisappear {
            if let player = player {
                player.pause()
                Task {
                    await player.seek(to: .zero)
                    playerManager.stopAudio(for: reel.videoURL)
                }
            }
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    private func loadParticipants() async {
        for userId in reel.participants {
            if let user = try? await firestoreManager.getUser(id: userId) {
                participants.append(user)
            }
        }
    }
} 