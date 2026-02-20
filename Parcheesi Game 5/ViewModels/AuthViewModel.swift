// AuthViewModel.swift
// Manages authentication state: email, Apple Sign In, sign out

import SwiftUI
import Combine
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Published

    @Published var currentUser: UserProfile?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    private let userService = UserProfileService.shared

    // MARK: - Init / Deinit

    init() {
        observeAuthState()
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Auth State Observation

    private func observeAuthState() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task {
                if let user {
                    await self.loadUserProfile(uid: user.uid)
                    self.isAuthenticated = true
                } else {
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
            }
        }
    }

    // MARK: - Email Auth

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await loadUserProfile(uid: result.user.uid)
        } catch {
            errorMessage = authErrorMessage(error)
        }
        isLoading = false
    }

    func signUp(displayName: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            try await result.user.sendEmailVerification()
            let profile = UserProfile(id: result.user.uid, displayName: displayName, email: email)
            try await userService.createProfile(profile)
            currentUser = profile
        } catch {
            errorMessage = authErrorMessage(error)
        }
        isLoading = false
    }

    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            errorMessage = authErrorMessage(error)
        }
        isLoading = false
    }

    // MARK: - Apple Sign In

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let tokenData = cred.identityToken,
                let tokenString = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "Apple Sign In failed. Please try again."
                return
            }
            let firebaseCred = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce: nonce,
                fullName: cred.fullName
            )
            Task {
                isLoading = true
                do {
                    let result = try await Auth.auth().signIn(with: firebaseCred)
                    let displayName = [cred.fullName?.givenName, cred.fullName?.familyName]
                        .compactMap { $0 }.joined(separator: " ")
                    if await userService.profileExists(uid: result.user.uid) {
                        await loadUserProfile(uid: result.user.uid)
                    } else {
                        let profile = UserProfile(
                            id: result.user.uid,
                            displayName: displayName.isEmpty ? "Player" : displayName,
                            email: result.user.email ?? ""
                        )
                        try await userService.createProfile(profile)
                        currentUser = profile
                    }
                } catch {
                    errorMessage = authErrorMessage(error)
                }
                isLoading = false
            }
        case .failure(let error):
            errorMessage = authErrorMessage(error)
        }
    }

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Profile

    private func loadUserProfile(uid: String) async {
        do {
            currentUser = try await userService.fetchProfile(uid: uid)
            DailyRewardManager.shared.checkDailyReward()
        } catch {
            print("[AuthViewModel] Profile load error: \(error)")
        }
    }

    func updateDisplayName(_ name: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await userService.updateField(uid: uid, key: "displayName", value: name)
            currentUser?.displayName = name
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Error Helpers

    private func authErrorMessage(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case AuthErrorCode.wrongPassword.rawValue:        return "Incorrect password."
        case AuthErrorCode.userNotFound.rawValue:         return "No account found with that email."
        case AuthErrorCode.emailAlreadyInUse.rawValue:   return "Email is already in use."
        case AuthErrorCode.weakPassword.rawValue:         return "Password must be at least 6 characters."
        case AuthErrorCode.invalidEmail.rawValue:         return "Please enter a valid email address."
        case AuthErrorCode.networkError.rawValue:         return "Network error. Check your connection."
        default:                                          return error.localizedDescription
        }
    }

    // MARK: - Cryptographic Helpers for Apple Sign In

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess { fatalError("SecRandomCopyBytes failed") }
                return random
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
