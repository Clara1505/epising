//
//  LoginView.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import SwiftUI
import Observation

struct LoginView: View {

    @Environment(AuthViewModel.self) private var auth

    @State private var email    = ""
    @State private var password = ""
    @State private var isPasswordVisible = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // ── Header ───────────────────────────────
                    VStack(spacing: 16) {
                        Spacer().frame(height: 60)

                        // Logo
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.blue)
                                .frame(width: 88, height: 88)
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .blue.opacity(0.3), radius: 12, y: 6)

                        VStack(spacing: 6) {
                            Text("epising")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("Signature de présence EPITA")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer().frame(height: 32)
                    }

                    // ── Formulaire ───────────────────────────
                    VStack(spacing: 16) {

                        // Email
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                TextField("prenom.nom@epita.fr", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .textContentType(.emailAddress)
                                    .autocorrectionDisabled()
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }

                        // Mot de passe
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mot de passe")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                            HStack {
                                Image(systemName: "lock")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                if isPasswordVisible {
                                    TextField("••••••••", text: $password)
                                        .textContentType(.password)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("••••••••", text: $password)
                                        .textContentType(.password)
                                }
                                Button {
                                    isPasswordVisible.toggle()
                                } label: {
                                    Image(systemName: isPasswordVisible
                                          ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }

                        // Message d'erreur
                        if let error = auth.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Bouton connexion
                        Button {
                            Task { await auth.signIn(email: email, password: password) }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(canSubmit ? Color.blue : Color(.systemGray4))
                                if auth.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Se connecter")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(height: 52)
                        }
                        .disabled(!canSubmit || auth.isLoading)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 40)

                    // ── Footer ───────────────────────────────
                    Text("EPITA · Master 1 · Développement iOS")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 32)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty
    }
}
