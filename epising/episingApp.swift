//
//  episingApp.swift
//  epising
//
//  Created by Clara Sion Saunier on 24/04/2026.
//

import SwiftUI

@main
struct episingApp: App {

    @State private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
        }
    }
}
