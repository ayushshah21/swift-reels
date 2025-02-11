import Foundation
import FirebaseFirestore

struct WorkoutQuiz: Identifiable, Codable {
    var id: String?
    let workoutId: String  // ID of the saved workout this quiz is for
    let questions: [QuizQuestion]
    let createdAt: Date
    
    // Firestore encoding
    func toFirestore() -> [String: Any] {
        return [
            "workoutId": workoutId,
            "questions": questions.map { $0.toFirestore() },
            "createdAt": Timestamp(date: createdAt)
        ]
    }
    
    // Firestore decoding
    static func fromFirestore(_ snapshot: DocumentSnapshot) -> WorkoutQuiz? {
        guard let data = snapshot.data() else { return nil }
        
        guard let workoutId = data["workoutId"] as? String,
              let questionsData = data["questions"] as? [[String: Any]],
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        let questions = questionsData.compactMap { QuizQuestion.fromFirestore($0) }
        
        return WorkoutQuiz(
            id: snapshot.documentID,
            workoutId: workoutId,
            questions: questions,
            createdAt: createdAt
        )
    }
}

struct QuizQuestion: Codable {
    let question: String
    let options: [String]
    let correctAnswer: Int  // Index of correct answer in options array
    
    // Firestore encoding
    func toFirestore() -> [String: Any] {
        return [
            "question": question,
            "options": options,
            "correctAnswer": correctAnswer
        ]
    }
    
    // Firestore decoding
    static func fromFirestore(_ data: [String: Any]) -> QuizQuestion? {
        guard let question = data["question"] as? String,
              let options = data["options"] as? [String],
              let correctAnswer = data["correctAnswer"] as? Int else {
            return nil
        }
        
        return QuizQuestion(
            question: question,
            options: options,
            correctAnswer: correctAnswer
        )
    }
}

// Helper struct for JSON decoding from OpenAI response
struct QuizResponse: Codable {
    let questions: [QuizQuestion]
} 