//
//  LoginView.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import SwiftUI

struct LoginView: View {

    @Environment(AuthViewModel.self) private var auth

    @State private var email    = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ──────────────────────────────────────
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                Text("epising")
                    .font(.largeTitle.bold())
                Text("Signature de présence EPITA")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 80)
            .padding(.bottom, 48)

            // ── Formulaire ───────────────────────────────────
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textContentType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SecureField("Mot de passe", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task { await auth.signIn(email: email, password: password) }
                } label: {
                    Group {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Se connecter")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(email.isEmpty || password.isEmpty || auth.isLoading)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color(.systemBackground))
    }
}
