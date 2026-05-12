//
//  RootView.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import SwiftUI

struct RootView: View {

    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        Group {
            if auth.isLoading {
                ProgressView("Chargement...")
            } else if let profile = auth.profile {
                switch profile.role {
                case .student: StudentTabView()
                case .teacher: Text("Vue enseignant — \(profile.fullName)")
                }
            } else {
                LoginView()
            }
        }
        .task {
            await auth.checkSession()
        }
    }
}
