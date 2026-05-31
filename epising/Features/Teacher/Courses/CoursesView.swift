//
//  CoursesView.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import SwiftUI

struct CoursesView: View {

    @Environment(AuthViewModel.self) private var auth
    @State private var vm = CoursesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Chargement...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.sessions.isEmpty {
                    ContentUnavailableView(
                        "Aucun cours",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Pas de séances cette semaine.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(
                            alignment: .leading,
                            spacing: 0,
                            pinnedViews: .sectionHeaders
                        ) {
                            if !vm.todaySessions.isEmpty {
                                Section {
                                    ForEach(vm.todaySessions) { session in
                                        TeacherSessionCard(
                                            session: session,
                                            enrollmentCount: vm.enrollmentCounts[session.courseId] ?? 0,
                                            onRefresh: {
                                                Task {
                                                    if let id = auth.profile?.id {
                                                        await vm.load(teacherId: id)
                                                    }
                                                }
                                            }
                                        )
                                        .padding(.horizontal)
                                        .padding(.bottom, 10)
                                    }
                                } header: {
                                    SectionHeader(title: "Aujourd'hui")
                                }
                            }

                            if !vm.upcomingSessions.isEmpty {
                                Section {
                                    ForEach(vm.upcomingSessions) { session in
                                        TeacherSessionCard(
                                            session: session,
                                            enrollmentCount: vm.enrollmentCounts[session.courseId] ?? 0,
                                            onRefresh: {}
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
            .navigationTitle("Mes cours")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Déconnexion") {
                        Task { await auth.signOut() }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .task {
                if let id = auth.profile?.id {
                    await vm.load(teacherId: id)
                }
            }
            .refreshable {
                if let id = auth.profile?.id {
                    await vm.load(teacherId: id)
                }
            }
        }
    }
}

// ── Composants ────────────────────────────────────────────────

struct TeacherSessionCard: View {
    let session: TeacherSession
    let enrollmentCount: Int
    let onRefresh: () -> Void

    @Environment(AuthViewModel.self) private var auth

    private var accentColor: Color {
        session.isSignWindowOpen ? .orange : .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Barre colorée (aujourd'hui) ────────────────────
            if session.isToday {
                HStack {
                    if session.isSignWindowOpen {
                        Label("Fenêtre ouverte — étudiants peuvent émarger",
                              systemImage: "lock.open.fill")
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

            // ── Contenu ────────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {

                if !session.isToday {
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

                Label("\(enrollmentCount) élèves inscrits",
                      systemImage: "person.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Boutons action (aujourd'hui uniquement)
                if session.isToday {
                    HStack(spacing: 10) {

                        // Ouvrir via scan carte prof
                        if !session.isSignWindowOpen {
                            NavigationLink {
                                TeacherNFCScanView(teacherProfile: auth.profile!) {
                                    onRefresh()
                                }
                            } label: {
                                Label("Scanner ma carte",
                                      systemImage: "wave.3.right")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        // Faire l'appel  ← CORRIGÉ
                        NavigationLink {
                            RollCallView(session: session)
                        } label: {
                            Label("Faire l'appel",
                                  systemImage: "checkmark.circle")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
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
                    session.isToday ? accentColor : Color(.systemGray5),
                    lineWidth: session.isToday ? 1.5 : 1
                )
        )
    }
}
