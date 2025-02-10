import Foundation
import FirebaseFirestore

struct LiveSession: Identifiable, Codable {
    var id: String?
    let hostId: String
    let hostName: String
    let channelId: String
    var isActive: Bool
    let createdAt: Date
    var viewerCount: Int
    var viewers: [String]
    var workoutTranscript: String?
    var generatedWorkout: String?
    
    // Firestore encoding
    func toFirestore() -> [String: Any] {
        return [
            "hostId": hostId,
            "hostName": hostName,
            "channelId": channelId,
            "isActive": isActive,
            "createdAt": Timestamp(date: createdAt),
            "viewerCount": viewerCount,
            "viewers": viewers,
            "workoutTranscript": workoutTranscript as Any,
            "generatedWorkout": generatedWorkout as Any
        ]
    }
    
    // Firestore decoding
    static func fromFirestore(_ snapshot: DocumentSnapshot) -> LiveSession? {
        guard let data = snapshot.data() else { 
            print("❌ No data in document: \(snapshot.documentID)")
            return nil 
        }
        
        print("🔄 Parsing LiveSession from data:")
        print("   hostId: \(data["hostId"] as? String ?? "nil")")
        print("   hostName: \(data["hostName"] as? String ?? "nil")")
        print("   channelId: \(data["channelId"] as? String ?? "nil")")
        print("   isActive: \(data["isActive"] as? Bool ?? false)")
        
        return LiveSession(
            id: snapshot.documentID,
            hostId: data["hostId"] as? String ?? "",
            hostName: data["hostName"] as? String ?? "",
            channelId: data["channelId"] as? String ?? "",
            isActive: data["isActive"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            viewerCount: data["viewerCount"] as? Int ?? 0,
            viewers: data["viewers"] as? [String] ?? [],
            workoutTranscript: data["workoutTranscript"] as? String,
            generatedWorkout: data["generatedWorkout"] as? String
        )
    }
}

struct PartnerSession: Codable, Identifiable {
    var id: String?
    let hostId: String
    let partnerId: String?
    let channelId: String
    var isActive: Bool
    var createdAt: Date
    var status: SessionStatus
    var workoutType: WorkoutType
    var durationMinutes: Int
    
    enum SessionStatus: String, Codable {
        case waiting     // Host waiting for partner
        case inProgress // Both users connected
        case ended      // Session ended
    }
    
    func toFirestore() -> [String: Any] {
        return [
            "hostId": hostId,
            "partnerId": partnerId as Any,
            "channelId": channelId,
            "isActive": isActive,
            "createdAt": createdAt,
            "status": status.rawValue,
            "workoutType": workoutType.rawValue,
            "durationMinutes": durationMinutes
        ]
    }
    
    static func fromFirestore(_ document: DocumentSnapshot) -> PartnerSession? {
        guard let data = document.data() else { return nil }
        
        return PartnerSession(
            id: document.documentID,
            hostId: data["hostId"] as? String ?? "",
            partnerId: data["partnerId"] as? String,
            channelId: data["channelId"] as? String ?? "",
            isActive: data["isActive"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            status: SessionStatus(rawValue: data["status"] as? String ?? "waiting") ?? .waiting,
            workoutType: WorkoutType(rawValue: data["workoutType"] as? String ?? "") ?? .other,
            durationMinutes: data["durationMinutes"] as? Int ?? 30
        )
    }
} 