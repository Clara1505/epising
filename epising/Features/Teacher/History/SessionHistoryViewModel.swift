//
//  SessionHistoryViewModel.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation
import Supabase

struct SessionHistorySummary: Identifiable {
    let id: UUID
    let sessionDate: String
    let slot: TimeSlot
    let startTime: String
    let courseTitle: String
    let presentCount: Int
    let totalCount: Int

    var attendanceRate: Int {
        guard totalCount > 0 else { return 0 }
        return Int(Double(presentCount) / Double(totalCount) * 100)
    }

    var rateColor: String {
        attendanceRate >= 80 ? "green" : "orange"
    }

    private var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: sessionDate)
    }

    var formattedDate: String {
        guard let d = parsedDate else { return sessionDate }
        let f = DateFormatter()
        f.dateFormat = "EEE. d MMM"
        f.locale = Locale(identifier: "fr_FR")
        return f.string(from: d).capitalized
    }
}

@MainActor
@Observable
class SessionHistoryViewModel {

    var summaries: [SessionHistorySummary] = []
    var isLoading = false
    var errorMessage: String?

    var globalRate: Int {
        guard !summaries.isEmpty else { return 0 }
        let total   = summaries.reduce(0) { $0 + $1.totalCount }
        let present = summaries.reduce(0) { $0 + $1.presentCount }
        guard total > 0 else { return 0 }
        return Int(Double(present) / Double(total) * 100)
    }

    func load(teacherId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today = formatter.string(from: Date())

            // Sessions passées de cet enseignant
            let sessions: [TeacherSession] = try await supabase
                .from("sessions")
                .select("*, courses!inner(title, room, nfc_tag_id, teacher_id)")
                .eq("courses.teacher_id", value: teacherId.uuidString)
                .lt("session_date", value: today)
                .order("session_date", ascending: false)
                .execute()
                .value

            // Pour chaque session, charge les attendances
            var result: [SessionHistorySummary] = []

            for session in sessions {
                let attendances: [Attendance] = try await supabase
                    .from("attendances")
                    .select("id, session_id, student_id, status, signed_at, marked_by, device_id, left_at, teacher_note")
                    .eq("session_id", value: session.id.uuidString)
                    .execute()
                    .value

                let presentCount = attendances.filter {
                    $0.status == .present || $0.status == .earlyLeave
                }.count

                // Total = inscrits au cours
                let enrollments: [Enrollment] = try await supabase
                    .from("enrollments")
                    .select()
                    .eq("course_id", value: session.courseId.uuidString)
                    .execute()
                    .value

                result.append(SessionHistorySummary(
                    id: session.id,
                    sessionDate: session.sessionDate,
                    slot: session.slot,
                    startTime: session.startTime,
                    courseTitle: session.courses.title,
                    presentCount: presentCount,
                    totalCount: enrollments.count
                ))
            }

            summaries = result

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
