//
//  SessionDetailView.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import SwiftUI
import Supabase

@MainActor
@Observable
class SessionDetailViewModel {

    var presentStudents:    [StudentAttendance] = []
    var earlyLeaveStudents: [StudentAttendance] = []
    var absentStudents:     [StudentAttendance] = []
    var pendingStudents:    [StudentAttendance] = []
    var isLoading = false

    private var realtimeTask: Task<Void, Never>?

    func load(session: SessionHistorySummary) async {
        isLoading = true
        defer { isLoading = false }
        await fetchData(sessionId: session.id)
    }

    func subscribeRealtime(session: SessionHistorySummary) {
        realtimeTask = Task {
            let channel = supabase.realtimeV2.channel("detail-\(session.id)")

            let changes = await channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "attendances",
                filter: "session_id=eq.\(session.id.uuidString)"
            )

            await channel.subscribe()

            for await _ in changes {
                guard !Task.isCancelled else { break }
                await self.fetchData(sessionId: session.id)
            }
        }
    }

    func unsubscribe() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    func markAbsent(studentId: UUID, sessionId: UUID) async {
        do {
            struct UpsertBody: Encodable {
                let session_id: String
                let student_id: String
                let status: String
                let marked_by: String
            }

            try await supabase
                .from("attendances")
                .upsert(UpsertBody(
                    session_id: sessionId.uuidString,
                    student_id: studentId.uuidString,
                    status: "absent",
                    marked_by: "teacher_manual"
                ), onConflict: "session_id,student_id")
                .execute()

            await fetchData(sessionId: sessionId)
        } catch {
            print("markAbsent error:", error)
        }
    }

    func fetchData(sessionId: UUID) async {
        do {
            struct EnrollmentWithProfile: Codable {
                let studentId: UUID
                let profiles: ProfileInfo

                struct ProfileInfo: Codable {
                    let fullName: String
                    let email: String
                    enum CodingKeys: String, CodingKey {
                        case email
                        case fullName = "full_name"
                    }
                }

                enum CodingKeys: String, CodingKey {
                    case studentId = "student_id"
                    case profiles
                }
            }

            struct AttendanceInfo: Codable {
                let id: UUID
                let studentId: UUID
                let status: AttendanceStatus
                let signedAt: Date?
                let leftAt: Date?
                enum CodingKeys: String, CodingKey {
                    case id, status
                    case studentId = "student_id"
                    case signedAt  = "signed_at"
                    case leftAt    = "left_at"
                }
            }

            let session: CourseSession = try await supabase
                .from("sessions")
                .select("id, course_id, session_date, slot, start_time, end_time, sign_open_at, sign_close_at")
                .eq("id", value: sessionId.uuidString)
                .single()
                .execute()
                .value

            let enrollments: [EnrollmentWithProfile] = try await supabase
                .from("enrollments")
                .select("student_id, profiles(full_name, email)")
                .eq("course_id", value: session.courseId.uuidString)
                .execute()
                .value

            let attendances: [AttendanceInfo] = try await supabase
                .from("attendances")
                .select("id, student_id, status, signed_at, left_at")
                .eq("session_id", value: sessionId.uuidString)
                .execute()
                .value

            let attMap = Dictionary(uniqueKeysWithValues: attendances.map { ($0.studentId, $0) })

            let all: [StudentAttendance] = enrollments.map { e in
                let att = attMap[e.studentId]
                return StudentAttendance(
                    id: att?.id ?? UUID(),
                    studentId: e.studentId,
                    fullName: e.profiles.fullName,
                    email: e.profiles.email,
                    status: att?.status ?? .pending,
                    signedAt: att?.signedAt,
                    leftAt: att?.leftAt
                )
            }.sorted { $0.fullName < $1.fullName }

            presentStudents    = all.filter { $0.status == .present }
            earlyLeaveStudents = all.filter { $0.status == .earlyLeave }
            absentStudents     = all.filter { $0.status == .absent }
            pendingStudents    = all.filter { $0.status == .pending }

        } catch {
            print("SessionDetail error:", error)
        }
    }
}

struct SessionDetailView: View {

    let session: SessionHistorySummary
    @State private var vm = SessionDetailViewModel()

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
                            StatPill(value: vm.presentStudents.count,
                                     label: "Présents", color: .green)
                            Divider().frame(height: 40)
                            StatPill(value: vm.earlyLeaveStudents.count,
                                     label: "Parti tôt", color: .orange)
                            Divider().frame(height: 40)
                            StatPill(value: vm.absentStudents.count,
                                     label: "Absents", color: .red)
                            if !vm.pendingStudents.isEmpty {
                                Divider().frame(height: 40)
                                StatPill(value: vm.pendingStudents.count,
                                         label: "Attente", color: .gray)
                            }
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                        // ── Présents ───────────────────────────
                        if !vm.presentStudents.isEmpty {
                            DetailSection(
                                title: "Présents",
                                color: .green,
                                students: vm.presentStudents,
                                sessionId: session.id,
                                canMarkAbsent: true,
                                onMarkAbsent: { studentId in
                                    Task { await vm.markAbsent(studentId: studentId, sessionId: session.id) }
                                }
                            )
                        }

                        // ── Partis tôt ─────────────────────────
                        if !vm.earlyLeaveStudents.isEmpty {
                            DetailSection(
                                title: "Partis tôt",
                                color: .orange,
                                students: vm.earlyLeaveStudents,
                                sessionId: session.id,
                                canMarkAbsent: true,
                                onMarkAbsent: { studentId in
                                    Task { await vm.markAbsent(studentId: studentId, sessionId: session.id) }
                                }
                            )
                        }

                        // ── Absents ────────────────────────────
                        if !vm.absentStudents.isEmpty {
                            DetailSection(
                                title: "Absents",
                                color: .red,
                                students: vm.absentStudents,
                                sessionId: session.id,
                                canMarkAbsent: false,
                                onMarkAbsent: { _ in }
                            )
                        }

                        // ── En attente ─────────────────────────
                        if !vm.pendingStudents.isEmpty {
                            DetailSection(
                                title: "En attente",
                                color: .gray,
                                students: vm.pendingStudents,
                                sessionId: session.id,
                                canMarkAbsent: true,
                                onMarkAbsent: { studentId in
                                    Task { await vm.markAbsent(studentId: studentId, sessionId: session.id) }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle(session.courseTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.load(session: session)
            vm.subscribeRealtime(session: session)
        }
        .onDisappear {
            vm.unsubscribe()
        }
        .refreshable {
            await vm.load(session: session)
        }
    }
}

// ── Composants ────────────────────────────────────────────────

struct DetailSection: View {
    let title: String
    let color: Color
    let students: [StudentAttendance]
    let sessionId: UUID
    let canMarkAbsent: Bool
    let onMarkAbsent: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text("\(title) (\(students.count))")
                    .font(.footnote.uppercaseSmallCaps())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            VStack(spacing: 0) {
                ForEach(students) { student in
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Text(initials(for: student.fullName))
                                    .font(.caption.bold())
                                    .foregroundStyle(color)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(student.fullName)
                                    .font(.subheadline.weight(.medium))
                                HStack(spacing: 4) {
                                    if let signedAt = student.signedAt {
                                        Text("Arrivée \(signedAt.formatted(.dateTime.hour().minute()))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let leftAt = student.leftAt {
                                        Text("· Parti \(leftAt.formatted(.dateTime.hour().minute()))")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                            Spacer()
                        }

                        if canMarkAbsent {
                            Button {
                                onMarkAbsent(student.studentId)
                            } label: {
                                Text("Marquer absent")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)

                    if student.id != students.last?.id {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        return "\(parts.first?.prefix(1) ?? "")\(parts.last?.prefix(1) ?? "")".uppercased()
    }
}
