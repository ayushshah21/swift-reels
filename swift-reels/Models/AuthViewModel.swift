import Foundation
import FirebaseAuth

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    private let firestoreManager = FirestoreManager.shared
    
    init() {
        // Set up auth state listener
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            
            Task {
                await MainActor.run {
                    self.isAuthenticated = user != nil
                }
                
                if let user = user {
                    print("👤 User is signed in with ID: \(user.uid)")
                    
                    // Check if user document exists, create if it doesn't
                    do {
                        if try await self.firestoreManager.getUser(id: user.uid) == nil {
                            print("📝 Creating missing user document for existing user")
                            let newUser = User(
                                id: user.uid,
                                email: user.email ?? "unknown@email.com"
                            )
                            try await self.firestoreManager.createUser(newUser)
                        }
                    } catch {
                        print("❌ Error handling user document: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Check if user is already signed in
        if let currentUser = Auth.auth().currentUser {
            isAuthenticated = true
            print("👤 User already signed in: \(currentUser.uid)")
        }
    }
    
    func signIn(email: String, password: String) async {
        print("📝 Starting sign in process...")
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            
            // Check if user document exists, create if it doesn't
            if try await firestoreManager.getUser(id: result.user.uid) == nil {
                print("📝 Creating missing user document for existing user")
                let user = User(
                    id: result.user.uid,
                    email: result.user.email ?? email
                )
                try await firestoreManager.createUser(user)
            }
            
            isAuthenticated = true
            print("✅ User signed in successfully: \(result.user.uid)")
        } catch {
            errorMessage = handleAuthError(error)
            print("❌ Sign in error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String) async {
        print("📝 Starting sign up process...")
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Create user document in Firestore
            let user = User(
                id: result.user.uid,
                email: result.user.email ?? email
            )
            try await firestoreManager.createUser(user)
            
            isAuthenticated = true
            print("✅ User created successfully: \(result.user.uid)")
        } catch {
            errorMessage = handleAuthError(error)
            print("❌ Sign up error: \(error.localizedDescription)")
        }
        
        isLoading = false
        print("📝 Sign up process completed. isAuthenticated: \(isAuthenticated), errorMessage: \(errorMessage ?? "none")")
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            print("👋 User signed out successfully")
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
        }
    }
    
    private func handleAuthError(_ error: Error) -> String {
        let err = error as NSError
        print("🔍 Handling auth error: \(err.localizedDescription)")
        if let authError = AuthErrorCode(_bridgedNSError: err) {
            switch authError.code {
            case .wrongPassword:
                return "Invalid password. Please try again."
            case .invalidEmail:
                return "Invalid email format."
            case .emailAlreadyInUse:
                return "This email is already registered."
            case .userNotFound:
                return "Account not found. Please sign up."
            case .networkError:
                return "Network error. Please try again."
            default:
                return "An error occurred. Please try again."
            }
        } else {
            return "An unexpected error occurred. Please try again."
        }
    }
} 