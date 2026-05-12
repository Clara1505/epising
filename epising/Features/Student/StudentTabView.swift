//
//  StudentTabView.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import SwiftUI

struct StudentTabView: View {

    var body: some View {
        TabView {
            ScheduleView()
                .tabItem {
                    Label("Emploi du temps", systemImage: "calendar")
                }

            Text("Présences — à venir")
                .tabItem {
                    Label("Présences", systemImage: "list.clipboard")
                }
        }
    }
}
