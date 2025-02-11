import SwiftUI
import FirebaseAuth

struct QuizView: View {
    let workout: SavedWorkout
    @StateObject private var firestoreManager = FirestoreManager.shared
    @StateObject private var openAIManager = OpenAIManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var quiz: WorkoutQuiz?
    @State private var selectedAnswers: [Int?]
    @State private var showResults = false
    @State private var isLoading = true
    @State private var error: String?
    @State private var hasSubmitted = false
    @State private var correctAnswers = 0
    
    init(workout: SavedWorkout) {
        self.workout = workout
        // Initialize selectedAnswers with nil values
        _selectedAnswers = State(initialValue: Array(repeating: nil, count: 5))
    }
    
    private var allQuestionsAnswered: Bool {
        !selectedAnswers.contains(nil)
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Generating Quiz...")
                    .scaleEffect(1.5)
            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task {
                            await loadQuiz()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else if showResults {
                QuizResultsView(
                    correctAnswers: correctAnswers,
                    totalQuestions: quiz?.questions.count ?? 0,
                    onDismiss: { dismiss() }
                )
            } else if let quiz = quiz {
                ScrollView {
                    VStack(spacing: 32) {
                        Text("Test Your Knowledge")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.top)
                        
                        ForEach(Array(quiz.questions.enumerated()), id: \.offset) { index, question in
                            QuestionCard(
                                question: question,
                                selectedAnswer: $selectedAnswers[index],
                                showFeedback: hasSubmitted,
                                questionNumber: index + 1
                            )
                        }
                        
                        // Submit Button
                        Button(action: {
                            if hasSubmitted {
                                submitQuiz()
                            } else {
                                hasSubmitted = true
                                // Calculate correct answers
                                correctAnswers = zip(selectedAnswers, quiz.questions).reduce(0) { count, pair in
                                    guard let selected = pair.0 else { return count }
                                    return count + (selected == pair.1.correctAnswer ? 1 : 0)
                                }
                            }
                        }) {
                            Text(hasSubmitted ? "Continue" : "Check Answers")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(allQuestionsAnswered ? Color.blue : Color.gray)
                                .cornerRadius(10)
                        }
                        .disabled(!allQuestionsAnswered)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Workout Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadQuiz()
        }
    }
    
    private func loadQuiz() async {
        isLoading = true
        error = nil
        
        do {
            quiz = try await openAIManager.generateQuiz(from: workout)
            selectedAnswers = Array(repeating: nil, count: quiz?.questions.count ?? 5)
            hasSubmitted = false
            correctAnswers = 0
            showResults = false
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func submitQuiz() {
        guard let quiz = quiz,
              let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        Task {
            do {
                try await firestoreManager.updateUserQuizScore(
                    userId: userId,
                    quiz: quiz,
                    correctAnswers: correctAnswers
                )
                await MainActor.run {
                    showResults = true
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

struct QuestionCard: View {
    let question: QuizQuestion
    @Binding var selectedAnswer: Int?
    let showFeedback: Bool
    let questionNumber: Int
    
    private func getOptionColor(index: Int) -> Color {
        guard showFeedback else {
            return selectedAnswer == index ? .blue.opacity(0.1) : Color(.secondarySystemBackground)
        }
        
        if index == question.correctAnswer {
            return .green.opacity(0.2)
        } else if selectedAnswer == index {
            return .red.opacity(0.2)
        }
        return Color(.secondarySystemBackground)
    }
    
    private func getOptionBorder(index: Int) -> Color {
        guard showFeedback else {
            return selectedAnswer == index ? .blue : .clear
        }
        
        if index == question.correctAnswer {
            return .green
        } else if selectedAnswer == index {
            return .red
        }
        return .clear
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text("\(questionNumber).")
                    .font(.headline)
                    .foregroundColor(.gray)
                Text(question.question)
                    .font(.headline)
            }
            
            VStack(spacing: 12) {
                ForEach(question.options.indices, id: \.self) { index in
                    Button(action: {
                        if !showFeedback {
                            selectedAnswer = index
                        }
                    }) {
                        HStack {
                            Text(question.options[index])
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if showFeedback {
                                if index == question.correctAnswer {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else if selectedAnswer == index {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            } else if selectedAnswer == index {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(getOptionColor(index: index))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(getOptionBorder(index: index), lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            if showFeedback {
                HStack {
                    Image(systemName: selectedAnswer == question.correctAnswer ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(selectedAnswer == question.correctAnswer ? .green : .red)
                    Text(selectedAnswer == question.correctAnswer ? "Correct!" : "Incorrect")
                        .fontWeight(.medium)
                        .foregroundColor(selectedAnswer == question.correctAnswer ? .green : .red)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

struct QuizResultsView: View {
    let correctAnswers: Int
    let totalQuestions: Int
    let onDismiss: () -> Void
    
    private var percentage: Int {
        Int((Double(correctAnswers) / Double(totalQuestions)) * 100)
    }
    
    private var resultMessage: String {
        switch percentage {
        case 90...100: return "Excellent! You're a fitness expert! 🏆"
        case 70...89: return "Great job! Keep learning! 💪"
        case 50...69: return "Good effort! Room for improvement! 📚"
        default: return "Keep studying and try again! 💡"
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: percentage >= 70 ? "trophy.fill" : "book.fill")
                .font(.system(size: 60))
                .foregroundColor(percentage >= 70 ? .yellow : .blue)
            
            Text("Quiz Complete!")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                Text("\(correctAnswers) out of \(totalQuestions) correct")
                    .font(.headline)
                Text("\(percentage)%")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(percentage >= 70 ? .green : .orange)
            }
            
            Text(resultMessage)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: onDismiss) {
                Text("Done")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .padding()
    }
} 