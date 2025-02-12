import Foundation

@MainActor
class ReelQuizManager: ObservableObject {
    static let shared = ReelQuizManager()
    
    @Published var shouldShowQuiz = false
    @Published var currentQuiz: WorkoutQuiz?
    @Published var recentTranscripts: [String] = []
    @Published var videosWatchedSinceLastQuiz = 0
    @Published private(set) var isReelsFeedActive = false
    
    private let videosBeforeQuiz = 3
    private let maxStoredTranscripts = 5
    private let minimumTranscriptLength = 50 // Minimum characters for a meaningful transcript
    private let maxRetries = 2
    
    private init() {}
    
    func setReelsFeedActive(_ active: Bool) {
        isReelsFeedActive = active
        if !active {
            // If leaving reels feed, hide any pending quiz
            shouldShowQuiz = false
            currentQuiz = nil
        }
    }
    
    func addTranscript(_ transcript: String) {
        // Only process transcripts if reels feed is active
        guard isReelsFeedActive else {
            print("⚠️ Skipping transcript processing - Reels feed not active")
            return
        }
        
        print("📊 ReelQuizManager - Adding transcript")
        print("   Current videos watched: \(videosWatchedSinceLastQuiz)")
        print("   Current transcripts count: \(recentTranscripts.count)")
        
        // Clean and validate transcript
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip if transcript is too short
        guard cleanTranscript.count >= minimumTranscriptLength else {
            print("⚠️ Skipping transcript - too short (\(cleanTranscript.count) chars)")
            return
        }
        
        // Add new transcript to the beginning
        recentTranscripts.insert(cleanTranscript, at: 0)
        
        // Keep only the most recent transcripts
        if recentTranscripts.count > maxStoredTranscripts {
            recentTranscripts = Array(recentTranscripts.prefix(maxStoredTranscripts))
        }
        
        // Only increment counter if we added a valid transcript
        videosWatchedSinceLastQuiz += 1
        
        print("📊 After adding transcript:")
        print("   Videos watched: \(videosWatchedSinceLastQuiz)")
        print("   Stored transcripts: \(recentTranscripts.count)")
        print("   Latest transcript length: \(cleanTranscript.count)")
        
        // Check if it's time for a quiz
        if videosWatchedSinceLastQuiz >= videosBeforeQuiz && recentTranscripts.count >= 2 {
            print("🎯 Time for a quiz! Generating...")
            print("   Total transcripts available: \(recentTranscripts.count)")
            for (index, transcript) in recentTranscripts.enumerated() {
                print("   Transcript \(index + 1) length: \(transcript.count) chars")
            }
            Task {
                await generateQuizWithRetry()
            }
        }
    }
    
    private func generateQuizWithRetry() async {
        // Double check reels feed is still active before starting quiz generation
        guard isReelsFeedActive else {
            print("⚠️ Cancelling quiz generation - Reels feed not active")
            return
        }
        
        var retryCount = 0
        var lastError: Error?
        
        while retryCount <= maxRetries {
            // Check reels feed is still active before each attempt
            guard isReelsFeedActive else {
                print("⚠️ Cancelling quiz generation - Reels feed not active")
                return
            }
            
            do {
                try await generateQuiz()
                return // Success, exit the retry loop
            } catch {
                lastError = error
                retryCount += 1
                print("❌ Quiz generation attempt \(retryCount) failed: \(error.localizedDescription)")
                
                if retryCount <= maxRetries {
                    print("🔄 Retrying quiz generation in 1 second...")
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second before retry
                }
            }
        }
        
        print("❌ Quiz generation failed after \(maxRetries) retries")
        print("   Last error: \(lastError?.localizedDescription ?? "Unknown error")")
        // Reset counter so we'll try again after watching more videos
        videosWatchedSinceLastQuiz = max(0, videosBeforeQuiz - 1)
    }
    
    private func generateQuiz() async throws {
        // Final check that reels feed is still active before showing quiz
        guard isReelsFeedActive else {
            print("⚠️ Cancelling quiz generation - Reels feed not active")
            throw QuizError.reelsFeedNotActive
        }
        
        // Ensure we have enough meaningful content
        let validTranscripts = recentTranscripts.filter { $0.count >= minimumTranscriptLength }
        
        guard !validTranscripts.isEmpty else {
            print("❌ No valid transcripts available for quiz generation")
            print("   Found \(recentTranscripts.count) total transcripts")
            print("   But 0 valid transcripts of sufficient length")
            throw QuizError.noValidTranscripts
        }
        
        print("🎲 Generating quiz from \(validTranscripts.count) valid transcripts")
        let quiz = try await OpenAIManager.shared.generateQuizFromTranscripts(validTranscripts)
        print("✅ Quiz generated successfully with \(quiz.questions.count) questions")
        
        await MainActor.run {
            // Final check before showing quiz
            guard isReelsFeedActive else {
                print("⚠️ Not showing quiz - Reels feed not active")
                return
            }
            self.currentQuiz = quiz
            self.shouldShowQuiz = true
            self.videosWatchedSinceLastQuiz = 0
            print("🎯 Quiz ready to show!")
        }
    }
    
    func dismissQuiz() {
        print("🎯 Dismissing quiz")
        shouldShowQuiz = false
        currentQuiz = nil
        // Clear transcripts after quiz is dismissed
        recentTranscripts.removeAll()
        // Reset counter
        videosWatchedSinceLastQuiz = 0
    }
}

enum QuizError: Error {
    case noValidTranscripts
    case reelsFeedNotActive
} 