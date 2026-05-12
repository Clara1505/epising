//
//  SessionHistoryView.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import SwiftUI

struct SessionHistoryView: View {

    @Environment(AuthViewModel.self) private var auth
    @State private var vm = SessionHistoryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Chargement...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.summaries.isEmpty {
                    ContentUnavailableView(
                        "Aucun historique",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Les séances passées apparaîtront ici.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {

                            // ── Taux global ────────────────────
                            VStack(spacing: 8) {
                                Text("\(vm.globalRate)%")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundStyle(
                                        vm.globalRate >= 80 ? Color.green : Color.orange
                                    )
                                    .contentTransition(.numericText())
                                Text("Taux de présence global")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(.systemGray5))
                                            .frame(height: 8)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(vm.globalRate >= 80
                                                  ? Color.green : Color.orange)
                                            .frame(
                                                width: geo.size.width
                                                    * CGFloat(vm.globalRate) / 100,
                                                height: 8
                                            )
                                            .animation(.easeInOut, value: vm.globalRate)
                                    }
                                }
                                .frame(height: 8)
                                .padding(.horizontal, 24)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)

                            // ── Liste séances ──────────────────
                            VStack(spacing: 0) {
                                ForEach(vm.summaries) { summary in
                                    NavigationLink {
                                        SessionDetailView(session: summary)
                                    } label: {
                                        HistoryRow(summary: summary)
                                    }
                                    .buttonStyle(.plain)

                                    if summary.id != vm.summaries.last?.id {
                                        Divider().padding(.leading, 16)
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
            .navigationTitle("Historique")
            .task {
                if let id = auth.profile?.id {
                    await vm.load(teacherId: id)
                    vm.subscribeRealtime(teacherId: id)
                }
            }
            .onDisappear {
                vm.unsubscribe()
            }
            .refreshable {
                if let id = auth.profile?.id {
                    await vm.load(teacherId: id)
                }
            }
        }
    }
}

struct HistoryRow: View {
    let summary: SessionHistorySummary

    private var rateColor: Color {
        summary.attendanceRate >= 80 ? .green : .orange
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(rateColor)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.courseTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Text(summary.formattedDate)
                    Text("·")
                    Text(summary.slot.label)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(summary.attendanceRate)%")
                    .font(.subheadline.bold())
                    .foregroundStyle(rateColor)
                Text("\(summary.presentCount)/\(summary.totalCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
