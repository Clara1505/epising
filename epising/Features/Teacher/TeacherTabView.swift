//
//  TeacherTabView.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import SwiftUI

struct TeacherTabView: View {
    var body: some View {
        TabView {
            CoursesView()
                .tabItem {
                    Label("Mes cours", systemImage: "calendar")
                }

            Text("Historique — à venir")
                .tabItem {
                    Label("Historique", systemImage: "clock.arrow.circlepath")
                }
        }
    }
}
