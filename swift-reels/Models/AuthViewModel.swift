import Foundation
import FirebaseAuth

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    init() {
        // Set up auth state listener
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isAuthenticated = user != nil
                if let user = user {
                    print("👤 User is signed in with ID: \(user.uid)")
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