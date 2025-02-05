import SwiftUI

struct AuthView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isSignUp ? "Create Account" : "Welcome Back")
                .font(.title)
                .fontWeight(.bold)
            
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(viewModel.isLoading)
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(viewModel.isLoading)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button {
                print("🔵 Auth button tapped. isSignUp: \(isSignUp)")
                print("🔵 Email: \(email), Password length: \(password.count)")
                
                Task {
                    if isSignUp {
                        print("🔵 Starting sign up...")
                        await viewModel.signUp(email: email, password: password)
                    } else {
                        print("🔵 Starting sign in...")
                        await viewModel.signIn(email: email, password: password)
                    }
                }
            } label: {
                ZStack {
                    Rectangle()
                        .fill(Color.blue)
                        .cornerRadius(10)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .disabled(viewModel.isLoading)
            
            Button(action: {
                isSignUp.toggle()
                print("🔄 Toggled auth mode. isSignUp: \(isSignUp)")
            }) {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .foregroundColor(.blue)
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
        .onAppear {
            print("👋 AuthView appeared")
        }
    }
} 