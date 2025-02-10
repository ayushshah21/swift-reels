import SwiftUI
import FirebaseAuth

struct SavedWorkoutDetailView: View {
    let workout: SavedWorkout
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Workout Metadata
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(workout.type.rawValue, systemImage: "figure.run")
                        Spacer()
                        Label("\(workout.estimatedDuration)m", systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    
                    if !workout.equipment.isEmpty {
                        Text("Equipment Needed:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(workout.equipment.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Text("Difficulty: \(workout.difficulty)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Workout Plan
                Text("Workout Plan")
                    .font(.headline)
                    .padding(.top)
                
                Text(workout.workoutPlan)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SavedWorkoutsView: View {
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var workouts: [SavedWorkout] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var deleteError: String?
    @State private var showDeleteError = false
    @State private var isDeleting = false
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if workouts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Saved Workouts")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("Workouts you save from live streams will appear here")
                        .foregroundColor(.gray)
                }
            } else {
                List {
                    ForEach(workouts) { workout in
                        NavigationLink(destination: SavedWorkoutDetailView(workout: workout)) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(workout.title)
                                    .font(.headline)
                                
                                HStack {
                                    Label(workout.type.rawValue, systemImage: "figure.run")
                                    Spacer()
                                    Label("\(workout.estimatedDuration)m", systemImage: "clock")
                                }
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                
                                Text(workout.difficulty)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: deleteWorkouts)
                }
                .overlay(
                    Group {
                        if isDeleting {
                            ProgressView("Deleting...")
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(radius: 2)
                        }
                    }
                )
            }
        }
        .navigationTitle("Saved Workouts")
        .task {
            await loadWorkouts()
        }
        .alert("Error Deleting Workout", isPresented: $showDeleteError) {
            Button("OK") {
                deleteError = nil
            }
        } message: {
            if let error = deleteError {
                Text(error)
            }
        }
    }
    
    private func loadWorkouts() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            error = "Please sign in to view saved workouts"
            isLoading = false
            return
        }
        
        do {
            let savedWorkouts = try await firestoreManager.getSavedWorkouts(userId: userId)
            await MainActor.run {
                workouts = savedWorkouts
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func deleteWorkouts(at offsets: IndexSet) {
        Task {
            await MainActor.run {
                isDeleting = true
            }
            
            do {
                // Get the workouts to delete
                let workoutsToDelete = offsets.map { workouts[$0] }
                
                // Delete each workout
                for workout in workoutsToDelete {
                    guard let workoutId = workout.id else { continue }
                    print("🗑️ Deleting workout: \(workoutId)")
                    try await firestoreManager.deleteSavedWorkout(workoutId)
                }
                
                // Reload workouts to ensure UI is in sync
                await loadWorkouts()
                
            } catch {
                print("❌ Error deleting workout:", error.localizedDescription)
                await MainActor.run {
                    deleteError = error.localizedDescription
                    showDeleteError = true
                }
            }
            
            await MainActor.run {
                isDeleting = false
            }
        }
    }
} 