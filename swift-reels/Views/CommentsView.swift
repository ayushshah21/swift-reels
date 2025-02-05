import SwiftUI
import FirebaseAuth

struct CommentsView: View {
    let videoID: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var comments: [Comment] = []
    @State private var newCommentText = ""
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Comments")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                }
            }
            .padding()
            
            Divider()
            
            // Comments List
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if comments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No comments yet")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(comments) { comment in
                            CommentRow(comment: comment, onDelete: {
                                deleteComment(comment)
                            })
                        }
                    }
                    .padding()
                }
            }
            
            // Comment Input
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    TextField("Add a comment...", text: $newCommentText)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: submitComment) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(newCommentText.isEmpty ? .gray : Theme.primary)
                    }
                    .disabled(newCommentText.isEmpty)
                }
                .padding()
            }
        }
        .task {
            setupCommentsListener()
        }
    }
    
    private func setupCommentsListener() {
        _ = firestoreManager.addCommentsListener(videoId: videoID) { fetchedComments in
            withAnimation {
                comments = fetchedComments
                isLoading = false
            }
        }
    }
    
    private func submitComment() {
        let commentText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commentText.isEmpty else { return }
        
        Task {
            do {
                try await firestoreManager.addComment(to: videoID, text: commentText)
                await MainActor.run {
                    newCommentText = ""
                }
            } catch {
                print("❌ Error adding comment: \(error.localizedDescription)")
                self.error = error
            }
        }
    }
    
    private func deleteComment(_ comment: Comment) {
        Task {
            do {
                try await firestoreManager.deleteComment(comment.id, from: videoID)
            } catch {
                print("❌ Error deleting comment: \(error.localizedDescription)")
                self.error = error
            }
        }
    }
}

struct CommentRow: View {
    let comment: Comment
    let onDelete: () -> Void
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.username)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if comment.userId == Auth.auth().currentUser?.uid {
                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            
            Text(comment.text)
                .font(.body)
            
            Text(comment.createdAt.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundColor(.gray)
        }
        .alert("Delete Comment", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this comment?")
        }
    }
} 