import SwiftUI
import FirebaseAuth

struct LeaderboardView: View {
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var scores: [UserQuizScore] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var currentUserScore: UserQuizScore?
    
    private let accentColor = Color(red: 0.35, green: 0.47, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let error = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if scores.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Quiz Scores Yet")
                            .font(.title3)
                            .fontWeight(.medium)
                        Text("Complete quizzes to appear on the leaderboard!")
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Current user's score card (if available)
                            if let currentUserScore = currentUserScore {
                                VStack(spacing: 16) {
                                    Text("Your Stats")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    UserScoreCard(
                                        score: currentUserScore,
                                        rank: scores.firstIndex { $0.userId == currentUserScore.userId }
                                            .map { $0 + 1 } ?? 0,
                                        showDivider: false
                                    )
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)
                                .padding(.horizontal)
                            }
                            
                            // Global leaderboard
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Global Leaderboard")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 0) {
                                    ForEach(Array(scores.enumerated()), id: \.element.id) { index, score in
                                        UserScoreCard(
                                            score: score,
                                            rank: index + 1,
                                            showDivider: index < scores.count - 1
                                        )
                                    }
                                }
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await loadLeaderboard()
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .task {
                await loadLeaderboard()
            }
        }
    }
    
    private func loadLeaderboard() async {
        isLoading = true
        error = nil
        
        do {
            // Load global leaderboard
            scores = try await firestoreManager.getLeaderboard()
            
            // Load current user's score if logged in
            if let userId = Auth.auth().currentUser?.uid {
                currentUserScore = try await firestoreManager.getUserQuizScore(userId: userId)
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct UserScoreCard: View {
    let score: UserQuizScore
    let rank: Int
    let showDivider: Bool
    
    private let accentColor = Color(red: 0.35, green: 0.47, blue: 0.95)
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Rank
                Text("\(rank)")
                    .font(.headline)
                    .foregroundColor(rank <= 3 ? .white : .primary)
                    .frame(width: 30, height: 30)
                    .background(rankBackground)
                    .clipShape(Circle())
                
                // Profile image or placeholder
                AsyncImage(url: score.profileImageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(score.username)
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Label("\(score.totalQuizzesTaken)", systemImage: "checkmark.circle.fill")
                        Label("\(Int(score.averageScore * 100))%", systemImage: "percent")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding()
            
            if showDivider {
                Divider()
                    .padding(.leading, 70)
            }
        }
    }
    
    private var rankBackground: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .brown
        default: return Color(.tertiarySystemBackground)
        }
    }
} 