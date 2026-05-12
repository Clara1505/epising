//
//  AttendanceHistoryView.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import SwiftUI

struct AttendanceHistoryView: View {

    @State private var vm = AttendanceViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Chargement...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.attendances.isEmpty {
                    ContentUnavailableView(
                        "Aucune présence",
                        systemImage: "checkmark.seal",
                        description: Text("Ton historique apparaîtra ici.")
                    )
                } else {
                    ScrollView {
                        // ── Stats ──────────────────────────────────
                        VStack(spacing: 12) {
                            HStack(spacing: 16) {
                                StatCard(
                                    value: "\(vm.attendanceRate)%",
                                    label: "Présence",
                                    color: vm.attendanceRate >= 80 ? .green : .orange
                                )
                                StatCard(
                                    value: "\(vm.presentCount)",
                                    label: "Présences",
                                    color: .green
                                )
                                StatCard(
                                    value: "\(vm.absentCount)",
                                    label: "Absences",
                                    color: .red
                                )
                            }

                            // Barre de progression
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 8)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(vm.attendanceRate >= 80 ? Color.green : Color.orange)
                                        .frame(
                                            width: geo.size.width * CGFloat(vm.attendanceRate) / 100,
                                            height: 8
                                        )
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding()
                        .background(Color(.systemBackground))

                        // ── Liste ──────────────────────────────────
                        LazyVStack(spacing: 0) {
                            ForEach(vm.attendances) { attendance in
                                AttendanceRow(attendance: attendance)
                                Divider().padding(.leading, 56)
                            }
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Mes présences")
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }
}

// ── Composants ────────────────────────────────────────────────

struct StatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AttendanceRow: View {
    let attendance: AttendanceWithSession

    var statusColor: Color {
        switch attendance.status {
        case .present:    return .green
        case .absent:     return .red
        case .earlyLeave: return .orange
        case .pending:    return .gray
        }
    }

    var statusIcon: String {
        switch attendance.status {
        case .present:    return "checkmark.circle.fill"
        case .absent:     return "xmark.circle.fill"
        case .earlyLeave: return "clock.badge.exclamationmark.fill"
        case .pending:    return "circle"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(attendance.sessions.courses.title)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    Text(attendance.formattedDate)
                    Text("·")
                    Text(attendance.sessions.slot.label)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(attendance.status.label)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
