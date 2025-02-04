import SwiftUI

struct CommentsView: View {
    let videoID: String
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @State private var comments = [
        Comment(id: "1", username: "fitness_lover", text: "Great form! 💪", likes: 24, timeAgo: "2h"),
        Comment(id: "2", username: "workout_pro", text: "Thanks for sharing these tips!", likes: 15, timeAgo: "1h"),
        Comment(id: "3", username: "beginner_here", text: "Is this suitable for beginners?", likes: 8, timeAgo: "30m")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Comments List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(comments) { comment in
                        CommentRow(comment: comment)
                    }
                }
                .padding()
            }
            
            // Comment Input
            HStack(spacing: 12) {
                TextField("Add a comment...", text: $commentText)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button(action: {
                    submitComment()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(commentText.isEmpty ? .gray : Theme.primary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.systemGray5)),
                alignment: .top
            )
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }
    
    private func submitComment() {
        guard !commentText.isEmpty else { return }
        
        let newComment = Comment(
            id: UUID().uuidString,
            username: "me",
            text: commentText,
            likes: 0,
            timeAgo: "now"
        )
        
        withAnimation {
            comments.insert(newComment, at: 0)
            commentText = ""
        }
    }
}

struct Comment: Identifiable {
    let id: String
    let username: String
    let text: String
    let likes: Int
    let timeAgo: String
}

struct CommentRow: View {
    let comment: Comment
    @State private var isLiked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(comment.username)
                    .fontWeight(.semibold)
                Text("•")
                    .foregroundColor(.gray)
                Text(comment.timeAgo)
                    .foregroundColor(.gray)
            }
            .font(.subheadline)
            
            Text(comment.text)
            
            HStack(spacing: 16) {
                Button(action: {
                    withAnimation {
                        isLiked.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .gray)
                        Text("\(comment.likes + (isLiked ? 1 : 0))")
                            .foregroundColor(.gray)
                    }
                }
                
                Button(action: {
                    // Reply action
                }) {
                    Text("Reply")
                        .foregroundColor(.gray)
                }
            }
            .font(.caption)
        }
    }
} 