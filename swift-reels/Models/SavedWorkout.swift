import Foundation
import FirebaseFirestore

struct SavedWorkout: Identifiable, Codable {
    var id: String?
    let userId: String
    let title: String
    let workoutPlan: String
    let createdAt: Date
    let sourceSessionId: String?
    let type: WorkoutType
    let difficulty: String
    let equipment: [String]
    let estimatedDuration: Int // in minutes
    
    func toFirestore() -> [String: Any] {
        return [
            "userId": userId,
            "title": title,
            "workoutPlan": workoutPlan,
            "createdAt": Timestamp(date: createdAt),
            "sourceSessionId": sourceSessionId as Any,
            "type": type.rawValue,
            "difficulty": difficulty,
            "equipment": equipment,
            "estimatedDuration": estimatedDuration
        ]
    }
    
    static func fromFirestore(_ snapshot: DocumentSnapshot) -> SavedWorkout? {
        guard let data = snapshot.data() else { return nil }
        
        return SavedWorkout(
            id: snapshot.documentID,
            userId: data["userId"] as? String ?? "",
            title: data["title"] as? String ?? "",
            workoutPlan: data["workoutPlan"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            sourceSessionId: data["sourceSessionId"] as? String,
            type: WorkoutType(rawValue: data["type"] as? String ?? "") ?? .other,
            difficulty: data["difficulty"] as? String ?? "Beginner",
            equipment: data["equipment"] as? [String] ?? [],
            estimatedDuration: data["estimatedDuration"] as? Int ?? 30
        )
    }
} 