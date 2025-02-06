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
    
    // Firestore encoding
    func toFirestore() -> [String: Any] {
        return [
            "hostId": hostId,
            "hostName": hostName,
            "channelId": channelId,
            "isActive": isActive,
            "createdAt": Timestamp(date: createdAt),
            "viewerCount": viewerCount,
            "viewers": viewers
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
            viewers: data["viewers"] as? [String] ?? []
        )
    }
} 