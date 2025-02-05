
Authentication with Firebase & Swift
Building secure user authentication in an iOS app involves integrating Firebase Auth with Swift and handling multiple sign-in methods. Firebase Authentication provides SDKs for common auth options (email/password, Google, Apple, etc.) that can be easily used in Swift. Below we outline how to implement Google Sign-In and email/password auth, and discuss secure flows, error handling, and best practices.

Implementing Firebase Authentication (Google Sign-In & Email/Password)
Setup Firebase in iOS: Start by adding Firebase to your Xcode project (e.g. via Swift Package Manager or CocoaPods) and configuring it in your app’s startup (usually by calling FirebaseApp.configure() in the App Delegate or SwiftUI App initializer). Ensure you have enabled the desired sign-in methods in the Firebase console under Authentication -> Sign-in method (enable Google and Email/Password providers).

Google Sign-In Integration: For Google auth, you need to integrate the Google Sign-In SDK and link it with Firebase. In the Firebase console, enable the Google provider and download an updated GoogleService-Info.plist. In Xcode, add the REVERSED_CLIENT_ID from this plist as a URL scheme in your project settings (required for Google SDK to redirect back to your app).

Next, import the GoogleSignIn and FirebaseAuth frameworks in your code. You’ll create a sign-in flow that uses Google’s SDK to get an ID token, then pass that token to Firebase. For example, you can configure Google Sign-In and present the sign-in dialog like so:

swift
Copy
Edit
import FirebaseAuth
import GoogleSignIn

// ...

// 1. Check for existing sign-in
if GIDSignIn.sharedInstance.hasPreviousSignIn() {
    GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
        handleSignIn(user: user, error: error)
    }
} else {
    // 2. Prepare Google Sign-In configuration
    guard let clientID = FirebaseApp.app()?.options.clientID else { return }
    let config = GIDConfiguration(clientID: clientID)
    // 3. Present Google Sign-In flow
    GIDSignIn.sharedInstance.signIn(with: config, presenting: viewController) { user, error in
        handleSignIn(user: user, error: error)
    }
}

func handleSignIn(user: GIDGoogleUser?, error: Error?) {
    if let error = error {
        print("Google sign-in failed: \(error.localizedDescription)")
        return
    }
    // 4. Retrieve Google ID token and exchange for Firebase credential
    guard let auth = user?.authentication, let idToken = auth.idToken else { return }
    let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                  accessToken: auth.accessToken)
    Auth.auth().signIn(with: credential) { result, error in
        if let error = error {
            print("Firebase sign-in failed: \(error.localizedDescription)")
        } else {
            print("User signed in with Google, Firebase UID: \(result?.user.uid ?? "")")
        }
    }
}
In the above flow, once Google’s SDK returns a GIDGoogleUser with an ID token, we create a Firebase credential and sign in via Auth.auth().signIn(with: credential). This links the Google account to Firebase Authentication, yielding a Firebase user account​
BLOG.CODEMAGIC.IO
. Make sure to handle errors at each step (e.g., user cancellation or network issues). After a successful sign-in, Auth.auth().currentUser will be set and persisted.

Email/Password Authentication: Enabling Email/Password in Firebase allows users to register with an email address and password. In Swift, you can create a new user account with Auth.auth().createUser and sign in with Auth.auth().signIn. For example:

swift
Copy
Edit
Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
    if let error = error {
        // Handle account creation error (e.g., email already in use)
        print("Sign-up error: \(error.localizedDescription)")
        return
    }
    // Account created successfully
    let firebaseUser = authResult?.user
    // (Optionally, send email verification here)
}

Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
    if let error = error {
        print("Sign-in error: \(error.localizedDescription)")
        return
    }
    // Signed in successfully, user is now authenticated
    let firebaseUser = authResult?.user
}
Be sure to enable Email/Password in the console and possibly set up email verification. Firebase will automatically reject weak passwords or malformed email addresses and provide error codes we can handle (for example, AuthErrorCode.emailAlreadyInUse if an email is already registered)​
FIREBASE.GOOGLE.COM
. You should check error and present friendly messages (e.g. “This email is already in use” for emailAlreadyInUse, “Incorrect password” for .wrongPassword, etc.). The AuthErrorCode enum in FirebaseAuth can be used to identify specific errors in Swift.

Sign Out and Session Handling: Signing out is straightforward – call try Auth.auth().signOut(). This will clear the local user state. Firebase Auth by default keeps the user signed in between app launches by storing credentials securely. The user’s ID token is refreshed automatically by the SDK, so you typically don’t need to prompt for login every time the app opens – check Auth.auth().currentUser at launch to see if a user is already logged in. Provide a logout button in your UI that calls sign-out and update the app state accordingly. For instance, in the Google Sign-In flow above, we also call GIDSignIn.sharedInstance.signOut() to sign out of the Google session if needed​
BLOG.CODEMAGIC.IO
.

Secure Authentication Flows, Error Handling, and Best Practices
Secure Flows: Always use HTTPS (Firebase Auth calls are always over SSL) and let Firebase handle sensitive data like passwords – you never need to store passwords locally. For Google Sign-In, the sensitive OAuth tokens are handled by Google’s SDK. Use Firebase Security Rules in Firestore/Storage to restrict data access to authenticated users, ensuring that only logged-in users can read/write protected content. When using external auth providers like Google, Firebase Auth will handle verifying the provider’s token for you. You should also enable App Check in Firebase for additional security, which ensures only your app can access your Firebase backend.

Error Handling: Provide clear messages for common errors – e.g., “Invalid email address format,” “Incorrect password,” or “No internet connection.” The FirebaseAuth SDK returns specific error codes for issues like wrong password, user not found, email already in use, weak password, etc. Checking against AuthErrorCode allows tailoring messages. For example, if error._code == AuthErrorCode.emailAlreadyInUse.rawValue, you can prompt the user that the email is taken​
FIREBASE.GOOGLE.COM
. Always handle the error case in the completion closures of Auth calls – not doing so could leave users stuck with no feedback if something goes wrong. It’s also good to disable UI (e.g., show a loading spinner and block the sign-in button) while an auth request is in progress, to prevent duplicate submissions.

Account Verification & Recovery: For email sign-ups, consider sending verification emails (user.sendEmailVerification()) and requiring login only after verification, to ensure the email is real. Firebase can also help with password resets (sendPasswordReset(withEmail:)), so provide a “Forgot password?” option. These flows contribute to a secure, user-friendly auth system.

Sign in with Apple: Since our app offers third-party logins (Google), note that Apple’s App Store guidelines require offering Sign in with Apple for apps that use other social logins​
STACKOVERFLOW.COM
. This is a best practice (and often mandatory) on iOS to give users a privacy-centric login option. Firebase Auth supports Sign in with Apple as well – you can integrate it similarly (Apple’s AuthenticationServices framework to get a credential, then use OAuthProvider with Firebase).

Best Practices Summary: Use Firebase Auth SDK methods exclusively (avoid writing your own auth from scratch) to benefit from built-in security. Keep the authentication UI/UX simple and clear. Handle errors gracefully and log them for debugging. Do not expose sensitive info (like Firebase API keys or client secrets) in the app – fortunately, Firebase API keys are ok to include as they are not truly secret, but any custom server keys or secrets should remain on a secure server. Test the full auth flow thoroughly, including error cases (e.g., try logging in with wrong password to see the error). By following Firebase’s documentation and using the official SDKs, you get a robust auth system with relatively little code​
FIREBASE.GOOGLE.COM
.
