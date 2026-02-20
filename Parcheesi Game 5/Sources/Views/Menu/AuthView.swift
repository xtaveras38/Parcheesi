// AuthView.swift
// Sign in / Sign up / Apple Sign In screen

import SwiftUI
import AuthenticationServices

struct AuthView: View {

    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var confirmPassword = ""
    @State private var showForgotPassword = false
    @FocusState private var focusedField: AuthField?

    enum AuthMode { case signIn, signUp }
    enum AuthField { case name, email, password, confirmPassword }

    var body: some View {
        ZStack {
            AnimatedBackgroundView().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Logo
                    VStack(spacing: 8) {
                        Text("🎲")
                            .font(.system(size: 56))
                        Text("PARCHEESI QUEST")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(mode == .signIn ? "Welcome back!" : "Create your account")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 60)

                    // Form card
                    VStack(spacing: 16) {
                        // Mode toggle
                        Picker("Mode", selection: $mode) {
                            Text("Sign In").tag(AuthMode.signIn)
                            Text("Sign Up").tag(AuthMode.signUp)
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 4)

                        // Display name (sign up only)
                        if mode == .signUp {
                            AuthTextField(
                                icon: "person",
                                placeholder: "Display Name",
                                text: $displayName,
                                keyboardType: .default
                            )
                            .focused($focusedField, equals: .name)
                        }

                        AuthTextField(
                            icon: "envelope",
                            placeholder: "Email",
                            text: $email,
                            keyboardType: .emailAddress,
                            isAutocorrected: false
                        )
                        .focused($focusedField, equals: .email)

                        AuthTextField(
                            icon: "lock",
                            placeholder: "Password",
                            text: $password,
                            isSecure: true
                        )
                        .focused($focusedField, equals: .password)

                        if mode == .signUp {
                            AuthTextField(
                                icon: "lock.shield",
                                placeholder: "Confirm Password",
                                text: $confirmPassword,
                                isSecure: true
                            )
                            .focused($focusedField, equals: .confirmPassword)
                        }

                        // Error
                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Primary action
                        Button {
                            focusedField = nil
                            Task {
                                if mode == .signIn {
                                    await authViewModel.signIn(email: email, password: password)
                                } else {
                                    guard password == confirmPassword else {
                                        authViewModel.errorMessage = "Passwords do not match."
                                        return
                                    }
                                    await authViewModel.signUp(
                                        displayName: displayName,
                                        email: email,
                                        password: password
                                    )
                                }
                            }
                        } label: {
                            Group {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(mode == .signIn ? "Sign In" : "Create Account")
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Capsule().fill(Color.accentColor))
                            .foregroundStyle(.white)
                        }
                        .disabled(authViewModel.isLoading)

                        if mode == .signIn {
                            Button("Forgot Password?") {
                                showForgotPassword = true
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                        }

                        // Divider
                        HStack {
                            Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                            Text("or")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                        }

                        // Apple Sign In
                        SignInWithAppleButton(.signIn) { request in
                            let nonce = authViewModel.prepareAppleSignIn()
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = nonce
                        } onCompletion: { result in
                            authViewModel.handleAppleSignIn(result: result)
                        }
                        .signInWithAppleButtonStyle(.whiteOutline)
                        .frame(height: 50)
                        .clipShape(Capsule())
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.regularMaterial)
                    )
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(authViewModel: authViewModel)
                .presentationDetents([.medium])
        }
    }
}

// MARK: - Auth Text Field

struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var isAutocorrected: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled(!isAutocorrected)
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Forgot Password

struct ForgotPasswordView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var sent = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("We'll send a reset link to your email.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if sent {
                    Label("Reset link sent! Check your inbox.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .padding()
                } else {
                    AuthTextField(
                        icon: "envelope",
                        placeholder: "Email address",
                        text: $email,
                        keyboardType: .emailAddress
                    )
                    .padding(.horizontal)

                    Button {
                        Task {
                            await authViewModel.resetPassword(email: email)
                            sent = true
                        }
                    } label: {
                        Text("Send Reset Link")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Capsule().fill(Color.accentColor))
                            .foregroundStyle(.white)
                            .font(.headline)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
