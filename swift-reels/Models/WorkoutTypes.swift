import Foundation
import FirebaseFirestore

// Workout Type - Core types of workouts available
enum WorkoutType: String, Codable, CaseIterable {
    case all = "All"
    case strength = "Strength"
    case cardio = "Cardio"
    case yoga = "Yoga"
    case hiit = "HIIT"
    case pilates = "Pilates"
    case stretching = "Stretching"
    case bodyweight = "Bodyweight"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.circle.fill"
        case .yoga: return "figure.mind.and.body"
        case .hiit: return "bolt.fill"
        case .pilates: return "figure.flexibility"
        case .stretching: return "figure.mixed.cardio"
        case .bodyweight: return "figure.mind.and.body"
        case .other: return "figure.run"
        }
    }
    
    var color: String {
        switch self {
        case .all: return "gray"
        case .strength: return "red"
        case .cardio: return "green"
        case .yoga: return "purple"
        case .hiit: return "orange"
        case .pilates: return "blue"
        case .stretching: return "mint"
        case .bodyweight: return "purple"
        case .other: return "gray"
        }
    }
}

// Workout Level (renamed from WorkoutDifficulty to avoid conflicts)
enum WorkoutLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    
    var color: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "orange"
        case .advanced: return "red"
        }
    }
}

// Equipment needed for the workout
enum WorkoutEquipment: String, Codable, CaseIterable {
    case none = "No Equipment"
    case dumbbells = "Dumbbells"
    case resistanceBands = "Resistance Bands"
    case yogaMat = "Yoga Mat"
    case kettlebell = "Kettlebell"
    case pullupBar = "Pull-up Bar"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .none: return "figure.walk"
        case .dumbbells: return "dumbbell.fill"
        case .resistanceBands: return "figure.strengthtraining.traditional"
        case .yogaMat: return "figure.mind.and.body"
        case .kettlebell: return "figure.core.training"
        case .pullupBar: return "figure.pull.up"
        case .other: return "questionmark.circle"
        }
    }
}

// Workout Metadata - Complete information about a workout
struct WorkoutMetadata: Codable {
    let type: WorkoutType
    let level: WorkoutLevel // Changed from difficulty to level
    let equipment: [WorkoutEquipment]
    let durationSeconds: Int
    let estimatedCalories: Int?
    
    // Computed property for formatted duration
    var formattedDuration: String {
        let minutes = durationSeconds / 60
        return "\(minutes) min"
    }
    
    // MARK: - Firestore Conversion
    
    func toFirestore() -> [String: Any] {
        return [
            "type": type.rawValue,
            "level": level.rawValue,
            "equipment": equipment.map { $0.rawValue },
            "durationSeconds": durationSeconds,
            "estimatedCalories": estimatedCalories as Any
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) -> WorkoutMetadata? {
        guard let typeString = data["type"] as? String,
              let type = WorkoutType(rawValue: typeString),
              let levelString = data["level"] as? String,
              let level = WorkoutLevel(rawValue: levelString),
              let equipmentStrings = data["equipment"] as? [String],
              let durationSeconds = data["durationSeconds"] as? Int else {
            return nil
        }
        
        let equipment = equipmentStrings.compactMap { WorkoutEquipment(rawValue: $0) }
        let estimatedCalories = data["estimatedCalories"] as? Int
        
        return WorkoutMetadata(
            type: type,
            level: level,
            equipment: equipment,
            durationSeconds: durationSeconds,
            estimatedCalories: estimatedCalories
        )
    }
    
    // Preview data for development and testing
    static func preview() -> WorkoutMetadata {
        WorkoutMetadata(
            type: .strength,
            level: .intermediate,
            equipment: [.dumbbells, .yogaMat],
            durationSeconds: 300,  // 5 minutes
            estimatedCalories: 150
        )
    }
}