//
//  ScheduleView.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import SwiftUI

struct ScheduleView: View {

    @Environment(AuthViewModel.self) private var auth
    @State private var vm = ScheduleViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Chargement...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.sessions.isEmpty {
                    ContentUnavailableView(
                        "Aucune séance",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Pas de cours cette semaine.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {

                            // ── Aujourd'hui ──────────────────────────
                            if !vm.todaySessions.isEmpty {
                                Section {
                                    ForEach(vm.todaySessions) { session in
                                        SessionCard(session: session, isToday: true)
                                            .padding(.horizontal)
                                            .padding(.bottom, 10)
                                    }
                                } header: {
                                    SectionHeader(title: "Aujourd'hui")
                                }
                            }

                            // ── À venir ──────────────────────────────
                            if !vm.upcomingSessions.isEmpty {
                                Section {
                                    ForEach(vm.upcomingSessions) { session in
                                        SessionCard(session: session, isToday: false)
                                            .padding(.horizontal)
                                            .padding(.bottom, 10)
                                    }
                                } header: {
                                    SectionHeader(title: "À venir")
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Emploi du temps")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Déconnexion") {
                        Task { await auth.signOut() }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }
}

// ── Composants ────────────────────────────────────────────────

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.footnote.uppercaseSmallCaps())
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGroupedBackground))
    }
}

struct SessionCard: View {
    let session: SessionWithCourse
    let isToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Barre colorée si aujourd'hui
            if isToday {
                Rectangle()
                    .fill(session.isSignWindowOpen ? Color.green : Color.blue)
                    .frame(height: 4)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Titre + badge
                HStack {
                    Text(session.courses.title)
                        .font(.headline)
                    Spacer()
                    if session.isSignWindowOpen {
                        Text("OUVERT")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    } else if isToday {
                        Text(session.slot.label.uppercased())
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }

                // Infos
                Label(session.timeRange, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label(session.courses.room, systemImage: "door.left.hand.open")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Bouton émarger si aujourd'hui
                if isToday {
                    NavigationLink {
                        NFCScanView(session: session)
                    } label: {
                        Label("Émarger maintenant", systemImage: "wave.3.right")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: isToday ? 0 : 12))
        .overlay(
            RoundedRectangle(cornerRadius: isToday ? 0 : 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}
