// AuthService.swift
// Lightweight wrapper for current auth state access

import Foundation
import FirebaseAuth

/// Provides simple, synchronous access to the current authenticated user ID.
/// Use AuthViewModel for reactive auth state management.
final class AuthService {

    static let shared = AuthService()
    private init() {}

    var currentUserID: String? {
        Auth.auth().currentUser?.uid
    }

    var isAuthenticated: Bool {
        Auth.auth().currentUser != nil
    }

    var currentUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }
}
