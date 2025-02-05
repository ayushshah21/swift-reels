import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var currentUser: User?
    @State private var savedVideos: [VideoModel] = []
    @State private var isLoadingSaved = true
    @State private var showingSavedVideos = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Header
            VStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.gray)
                
                Text(currentUser?.username ?? Auth.auth().currentUser?.email ?? "User")
                    .font(.title2)
                    .fontWeight(.medium)
            }
            .padding(.top, 32)
            
            // Stats
            HStack(spacing: 40) {
                VStack {
                    Text("\(currentUser?.postsCount ?? 0)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Posts")
                        .foregroundColor(.gray)
                }
                
                VStack {
                    Text("\(currentUser?.followersCount ?? 0)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Followers")
                        .foregroundColor(.gray)
                }
                
                VStack {
                    Text("\(savedVideos.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Saved")
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical)
            
            // Saved Videos Button
            Button(action: { showingSavedVideos = true }) {
                HStack {
                    Image(systemName: "bookmark.fill")
                    Text("Saved Workouts")
                    Spacer()
                    Text("\(savedVideos.count)")
                        .foregroundColor(.gray)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Theme.card)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Sign Out Button
            Button(action: {
                authViewModel.signOut()
            }) {
                Text("Sign Out")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .task {
            if let authUser = Auth.auth().currentUser {
                do {
                    currentUser = try await firestoreManager.getUser(id: authUser.uid)
                    savedVideos = try await firestoreManager.getSavedVideos()
                    isLoadingSaved = false
                } catch {
                    print("❌ Error fetching user data: \(error.localizedDescription)")
                    isLoadingSaved = false
                }
            }
        }
        .sheet(isPresented: $showingSavedVideos) {
            SavedVideosView(videos: savedVideos)
        }
    }
}

struct SavedVideosView: View {
    let videos: [VideoModel]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if videos.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No saved workouts yet")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(videos) { video in
                                NavigationLink(destination: ReelPlayerView(video: video)) {
                                    VideoCardView(video: video)
                                        .padding(.horizontal)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical)
                        .onAppear {
                            print("📱 Displaying \(videos.count) saved videos:")
                            videos.forEach { video in
                                print("   - \(video.title) (\(video.id))")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Saved Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(Color(.systemBackground))
        }
    }
} 