//
//  AuthViewModel.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation
import Supabase

@MainActor
@Observable
class AuthViewModel {

    var profile: Profile?
    var isLoading = false
    var errorMessage: String?

    // Vérifie si une session existe déjà au lancement
    func checkSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await supabase.auth.session
            try await loadProfile(userId: session.user.id)
        } catch {
            profile = nil
        }
    }

    // Connexion email + password
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            try await loadProfile(userId: session.user.id)
        } catch {
            errorMessage = "Email ou mot de passe incorrect."
        }
    }

    // Déconnexion
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            profile = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Charge le profil depuis la table profiles
    private func loadProfile(userId: UUID) async throws {
        profile = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }
}
