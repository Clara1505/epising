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
                        LazyVStack(
                            alignment: .leading,
                            spacing: 0,
                            pinnedViews: .sectionHeaders
                        ) {
                            // ── Aujourd'hui ──────────────────────
                            if !vm.todaySessions.isEmpty {
                                Section {
                                    ForEach(vm.todaySessions) { session in
                                        SessionCard(
                                            session: session,
                                            isToday: true,
                                            attendanceStatus: vm.attendanceBySession[session.id]
                                        )
                                        .padding(.horizontal)
                                        .padding(.bottom, 10)
                                    }
                                } header: {
                                    SectionHeader(title: "Aujourd'hui")
                                }
                            }

                            // ── À venir ──────────────────────────
                            if !vm.upcomingSessions.isEmpty {
                                Section {
                                    ForEach(vm.upcomingSessions) { session in
                                        SessionCard(
                                            session: session,
                                            isToday: false,
                                            attendanceStatus: nil
                                        )
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
    let attendanceStatus: AttendanceStatus?

    private var isSigned: Bool {
        attendanceStatus == .present || attendanceStatus == .earlyLeave
    }

    private var accentColor: Color {
        if isSigned                 { return .green }
        if session.isSignWindowOpen { return .orange }
        return .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Barre colorée (aujourd'hui uniquement) ────────
            if isToday {
                HStack {
                    if isSigned {
                        Label("Présent", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    } else if session.isSignWindowOpen {
                        Label("Fenêtre ouverte", systemImage: "clock.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    } else {
                        Text(session.slot.label.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(accentColor)
            }

            // ── Contenu ───────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {

                // Date visible uniquement dans "À venir"
                if !isToday {
                    Text(session.formattedDate)
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }

                Text(session.courses.title)
                    .font(.headline)

                Label(session.timeRange, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label(session.courses.room, systemImage: "door.left.hand.open")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Bouton émarger : fenêtre ouverte ET pas encore signé
                if isToday && session.isSignWindowOpen && !isSigned {
                    NavigationLink {
                        NFCScanView(session: session)
                    } label: {
                        Label("Émarger maintenant", systemImage: "wave.3.right")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isToday ? accentColor : Color(.systemGray5),
                    lineWidth: isToday ? 1.5 : 1
                )
        )
    }
}
