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

            AttendanceHistoryView()
                .tabItem {
                    Label("Présences", systemImage: "list.clipboard")
                }
        }
    }
}
