import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var firestoreManager = FirestoreManager.shared
    @State private var currentUser: User?
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Header
            VStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.gray)
                
                Text(currentUser?.username ?? Auth.auth().currentUser?.email ?? "User")
                    .font(.title2)
                    .fontWeight(.medium)
            }
            .padding(.top, 32)
            
            // Stats
            HStack(spacing: 40) {
                VStack {
                    Text("\(currentUser?.postsCount ?? 0)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Posts")
                        .foregroundColor(.gray)
                }
                
                VStack {
                    Text("\(currentUser?.followersCount ?? 0)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Followers")
                        .foregroundColor(.gray)
                }
                
                VStack {
                    Text("\(currentUser?.followingCount ?? 0)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Following")
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical)
            
            Spacer()
            
            // Sign Out Button
            Button(action: {
                authViewModel.signOut()
            }) {
                Text("Sign Out")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .task {
            if let authUser = Auth.auth().currentUser {
                do {
                    currentUser = try await firestoreManager.getUser(id: authUser.uid)
                } catch {
                    print("❌ Error fetching user data: \(error.localizedDescription)")
                }
            }
        }
    }
} 