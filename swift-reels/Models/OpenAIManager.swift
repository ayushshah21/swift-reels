import Foundation

struct ParsedWorkout {
    let title: String
    let type: WorkoutType
    let difficulty: String
    let equipment: [String]
    let estimatedDuration: Int
    let workoutPlan: String
}

@MainActor
class OpenAIManager: ObservableObject {
    static let shared = OpenAIManager()
    
    @Published var isProcessing = false
    @Published var error: Error?
    
    private init() {}
    
    // Simple test function to verify OpenAI integration
    func testWorkoutGeneration() async {
        do {
            let testTranscript = """
            Today we're going to do a quick home workout. 
            We'll start with some jumping jacks for warmup, 
            then do 3 sets of pushups, 
            followed by bodyweight squats, 
            and finish with a plank hold.
            """
            
            isProcessing = true
            let result = try await generateWorkoutPlan(from: testTranscript)
            print("✅ Workout plan generated successfully:")
            print(result)
        } catch {
            print("❌ Error generating workout plan:", error.localizedDescription)
            self.error = error
        }
        isProcessing = false
    }
    
    func generateWorkoutPlan(from transcript: String) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        let systemPrompt = """
        You are a professional fitness trainer. Convert the given workout instructions into a clear, structured workout plan.
        Format the response in this exact structure:
        
        WORKOUT OVERVIEW
        Type: [Identify the type of workout]
        Duration: [Estimate the duration]
        Difficulty: [Beginner/Intermediate/Advanced]
        Equipment: [List any equipment mentioned or "No equipment needed"]
        
        WARMUP
        [List 2-3 warmup exercises with reps/duration]
        
        MAIN WORKOUT
        [Break down the workout into clear sets/exercises with specific reps/durations]
        
        COOLDOWN
        [List 2-3 cooldown/stretching exercises]
        
        FORM TIPS
        [List 2-3 key form tips for the main exercises]
        
        Keep it concise, practical, and safe for all fitness levels.
        If any exercise details are unclear, provide standard alternatives.
        """
        
        // OpenAI's chat-completions endpoint:
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "Here's the workout instruction: \(transcript)"]
        ]
        
        let parameters: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 1000
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw NSError(domain: "OpenAIManager",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response from OpenAI"])
        }
        
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw NSError(domain: "OpenAIManager",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not parse OpenAI response"])
        }
        
        return content
    }
    
    func generateStructuredWorkout(from transcript: String) async throws -> ParsedWorkout {
        isProcessing = true
        defer { isProcessing = false }
        
        let systemPrompt = """
        You are a professional fitness trainer. Analyze the given workout instructions and convert them into a structured workout plan.
        Also determine the following metadata:
        1. A concise title for the workout
        2. The primary type of workout (must be one of: strength, cardio, hiit, yoga, pilates, stretching, bodyweight, other)
        3. Difficulty level (Beginner, Intermediate, or Advanced)
        4. Required equipment (list all equipment mentioned)
        5. Estimated duration in minutes
        
        Format the response in this exact structure:
        ---METADATA---
        Title: [Concise descriptive title]
        Type: [Primary workout type]
        Difficulty: [Difficulty level]
        Equipment: [Comma-separated list of equipment]
        Duration: [Estimated minutes]
        
        ---WORKOUT PLAN---
        [Format the workout in a clear, structured way with sections for warmup, main workout, and cooldown]
        
        Keep it practical and safe for all fitness levels.
        If any exercise details are unclear, provide standard alternatives.
        """
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "Here's the workout instruction: \(transcript)"]
        ]
        
        let parameters: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 1000
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw NSError(domain: "OpenAIManager",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response from OpenAI"])
        }
        
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw NSError(domain: "OpenAIManager",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not parse OpenAI response"])
        }
        
        // Parse the structured response
        let parts = content.components(separatedBy: "---WORKOUT PLAN---")
        guard parts.count == 2 else {
            throw NSError(domain: "OpenAIManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        let metadata = parts[0].replacingOccurrences(of: "---METADATA---", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let workoutPlan = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse metadata
        var title = ""
        var type = WorkoutType.other
        var difficulty = "Intermediate"
        var equipment: [String] = []
        var duration = 30
        
        let metadataLines = metadata.components(separatedBy: "\n")
        for line in metadataLines {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            
            switch key {
            case "Title":
                title = value
            case "Type":
                type = WorkoutType(rawValue: value.lowercased()) ?? .other
            case "Difficulty":
                difficulty = value
            case "Equipment":
                equipment = value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            case "Duration":
                duration = Int(value.components(separatedBy: .whitespaces)[0]) ?? 30
            default:
                break
            }
        }
        
        return ParsedWorkout(
            title: title,
            type: type,
            difficulty: difficulty,
            equipment: equipment,
            estimatedDuration: duration,
            workoutPlan: workoutPlan
        )
    }
    
    func generateQuiz(from workout: SavedWorkout) async throws -> WorkoutQuiz {
        isProcessing = true
        defer { isProcessing = false }
        
        let systemPrompt = """
        You are a fitness expert. Generate a quiz about the given workout plan to test understanding of the exercises, form, and safety.
        Create 5 multiple-choice questions. Each question should have 4 options with exactly one correct answer.
        
        Format your response in this exact structure:
        {
          "questions": [
            {
              "question": "Question text here",
              "options": ["Option 1", "Option 2", "Option 3", "Option 4"],
              "correctAnswer": 0  // Index of correct answer (0-3)
            }
          ]
        }
        
        Focus on:
        1. Proper form and technique
        2. Safety considerations
        3. Understanding the workout structure
        4. Equipment usage (if any)
        5. Exercise benefits and muscle groups targeted
        
        Keep questions clear and unambiguous. Ensure all options are plausible but only one is correct.
        """
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "Generate a quiz for this workout:\n\(workout.workoutPlan)"]
        ]
        
        let parameters: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 1000
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw NSError(domain: "OpenAIManager",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response from OpenAI"])
        }
        
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any],
            let content = message["content"] as? String,
            let jsonData = content.data(using: .utf8),
            let quizResponse = try? JSONDecoder().decode(QuizResponse.self, from: jsonData)
        else {
            throw NSError(domain: "OpenAIManager",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not parse quiz response"])
        }
        
        return WorkoutQuiz(
            id: nil,
            workoutId: workout.id ?? "",
            questions: quizResponse.questions,
            createdAt: Date()
        )
    }
}
