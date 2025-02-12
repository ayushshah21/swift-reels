import SwiftUI
import FirebaseAuth

struct ReelQuizView: View {
    let quiz: WorkoutQuiz
    @State private var selectedAnswers: [Int?]
    @State private var hasSubmitted = false
    @State private var correctAnswers = 0
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firestoreManager = FirestoreManager.shared
    
    init(quiz: WorkoutQuiz) {
        self.quiz = quiz
        _selectedAnswers = State(initialValue: Array(repeating: nil, count: quiz.questions.count))
    }
    
    private var allQuestionsAnswered: Bool {
        !selectedAnswers.contains(nil)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Quick Knowledge Check!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top)
            
            Text("Test what you've learned from the last few workouts!")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Questions
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(Array(quiz.questions.enumerated()), id: \.offset) { index, question in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(question.question)
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            ForEach(Array(question.options.enumerated()), id: \.offset) { optionIndex, option in
                                Button(action: {
                                    if !hasSubmitted {
                                        selectedAnswers[index] = optionIndex
                                    }
                                }) {
                                    HStack {
                                        Text(option)
                                            .foregroundColor(.white)
                                        Spacer()
                                        if hasSubmitted {
                                            if optionIndex == question.correctAnswer {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            } else if optionIndex == selectedAnswers[index] {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                        } else if optionIndex == selectedAnswers[index] {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(optionBackgroundColor(optionIndex: optionIndex, questionIndex: index))
                                    )
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            
            // Submit Button
            Button(action: {
                if hasSubmitted {
                    dismiss()
                } else {
                    submitQuiz()
                }
            }) {
                Text(hasSubmitted ? "Continue Watching" : "Check Answers")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(allQuestionsAnswered ? Color.blue : Color.gray)
                    )
            }
            .disabled(!allQuestionsAnswered)
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .background(Color.black.opacity(0.9))
    }
    
    private func optionBackgroundColor(optionIndex: Int, questionIndex: Int) -> Color {
        if !hasSubmitted {
            return selectedAnswers[questionIndex] == optionIndex ? Color.blue.opacity(0.3) : Color.white.opacity(0.1)
        }
        
        if optionIndex == quiz.questions[questionIndex].correctAnswer {
            return Color.green.opacity(0.3)
        }
        if optionIndex == selectedAnswers[questionIndex] {
            return Color.red.opacity(0.3)
        }
        return Color.white.opacity(0.1)
    }
    
    private func submitQuiz() {
        hasSubmitted = true
        correctAnswers = zip(selectedAnswers, quiz.questions).reduce(0) { count, pair in
            guard let selected = pair.0 else { return count }
            return count + (selected == pair.1.correctAnswer ? 1 : 0)
        }
        
        if let userId = Auth.auth().currentUser?.uid {
            Task {
                try? await firestoreManager.updateUserQuizScore(
                    userId: userId,
                    quiz: quiz,
                    correctAnswers: correctAnswers
                )
            }
        }
    }
} 