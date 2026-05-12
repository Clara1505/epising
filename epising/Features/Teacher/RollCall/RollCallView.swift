//
//  RollCallView.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import SwiftUI

struct RollCallView: View {

    let session: TeacherSession
    @State private var vm = RollCallViewModel()

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Chargement...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {

                        // ── Stats ──────────────────────────────
                        HStack(spacing: 0) {
                            StatPill(
                                value: vm.presentCount,
                                label: "Présents",
                                color: .green
                            )
                            Divider().frame(height: 40)
                            StatPill(
                                value: vm.absentCount,
                                label: "Absents",
                                color: .red
                            )
                            Divider().frame(height: 40)
                            StatPill(
                                value: vm.pendingCount,
                                label: "En attente",
                                color: .gray
                            )
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                        // ── Liste étudiants ────────────────────
                        VStack(spacing: 0) {
                            ForEach(vm.students) { student in
                                StudentRollRow(
                                    student: student,
                                    onMarkPresent: {
                                        Task {
                                            await vm.markPresent(
                                                studentId: student.studentId,
                                                sessionId: session.id
                                            )
                                        }
                                    },
                                    onMarkEarlyLeave: {
                                        Task {
                                            await vm.markEarlyLeave(
                                                studentId: student.studentId,
                                                sessionId: session.id
                                            )
                                        }
                                    }
                                )
                                if student.id != vm.students.last?.id {
                                    Divider().padding(.leading, 60)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Appel — \(session.courses.title)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(session: session) }
        .refreshable { await vm.load(session: session) }
    }
}

// ── Composants ────────────────────────────────────────────────

struct StatPill: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

struct StudentRollRow: View {
    let student: StudentAttendance
    let onMarkPresent: () -> Void
    let onMarkEarlyLeave: () -> Void

    private var statusColor: Color {
        switch student.status {
        case .present:    return .green
        case .absent:     return .red
        case .earlyLeave: return .orange
        case .pending:    return .gray
        }
    }

    private var statusIcon: String {
        switch student.status {
        case .present:    return "checkmark.circle.fill"
        case .absent:     return "xmark.circle.fill"
        case .earlyLeave: return "clock.badge.exclamationmark.fill"
        case .pending:    return "circle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Initiales
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Text(initials)
                        .font(.subheadline.bold())
                        .foregroundStyle(statusColor)
                }

                // Nom + statut
                VStack(alignment: .leading, spacing: 2) {
                    Text(student.fullName)
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 4) {
                        Image(systemName: statusIcon)
                            .font(.caption)
                        Text(student.status.label)
                            .font(.caption)
                        if let signedAt = student.signedAt {
                            Text("· \(signedAt.formatted(.dateTime.hour().minute()))")
                                .font(.caption)
                        }
                        if let leftAt = student.leftAt {
                            Text("· parti à \(leftAt.formatted(.dateTime.hour().minute()))")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(statusColor)
                }

                Spacer()
            }

            // Boutons action — visibles pour présents et en attente
            if student.status == .pending || student.status == .absent {
                HStack(spacing: 8) {
                    Button {
                        onMarkPresent()
                    } label: {
                        Text("Marquer présent")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            if student.status == .present {
                Button {
                    onMarkEarlyLeave()
                } label: {
                    Text("Marquer parti tôt")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var initials: String {
        let parts = student.fullName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last  = parts.last?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }
}
