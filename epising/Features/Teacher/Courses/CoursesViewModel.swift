//
//  CoursesViewModel.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation
import Supabase

struct TeacherSession: Codable, Identifiable {
    let id: UUID
    let courseId: UUID
    let sessionDate: String
    let slot: TimeSlot
    let startTime: String
    let endTime: String
    let signOpenAt: Date?
    let signCloseAt: Date?
    let courses: CourseInfo

    struct CourseInfo: Codable {
        let title: String
        let room: String
        let nfcTagId: String

        enum CodingKeys: String, CodingKey {
            case title, room
            case nfcTagId = "nfc_tag_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, slot
        case courseId    = "course_id"
        case sessionDate = "session_date"
        case startTime   = "start_time"
        case endTime     = "end_time"
        case signOpenAt  = "sign_open_at"
        case signCloseAt = "sign_close_at"
        case courses
    }

    var timeRange: String {
        "\(String(startTime.prefix(5))) – \(String(endTime.prefix(5)))"
    }

    var isSignWindowOpen: Bool {
        guard let open = signOpenAt, let close = signCloseAt else { return false }
        return Date() >= open && Date() <= close
    }

    private var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: sessionDate)
    }

    var isToday: Bool {
        guard let d = parsedDate else { return false }
        return Calendar.current.isDateInToday(d)
    }

    var formattedDate: String {
        guard let d = parsedDate else { return sessionDate }
        let f = DateFormatter()
        f.dateFormat = "EEE. d MMM"
        f.locale = Locale(identifier: "fr_FR")
        return f.string(from: d).capitalized
    }

    // Nombre d'inscrits (chargé séparément)
    var enrollmentCount: Int = 0

    enum AttendanceSummary {
        case open, closed, signed
    }
}

@MainActor
@Observable
class CoursesViewModel {

    var sessions: [TeacherSession] = []
    var enrollmentCounts: [UUID: Int] = [:]
    var isLoading = false
    var errorMessage: String?

    var todaySessions: [TeacherSession] {
        sessions.filter { $0.isToday }
            .sorted { $0.startTime < $1.startTime }
    }

    var upcomingSessions: [TeacherSession] {
        sessions.filter { !$0.isToday }
            .sorted { ($0.sessionDate, $0.startTime) < ($1.sessionDate, $1.startTime) }
    }

    func load(teacherId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today    = formatter.string(from: Date())
            let nextWeek = formatter.string(
                from: Calendar.current.date(byAdding: .day, value: 7, to: Date())!
            )

            // Sessions des cours de CET enseignant
            sessions = try await supabase
                .from("sessions")
                .select("*, courses!inner(title, room, nfc_tag_id, teacher_id)")
                .eq("courses.teacher_id", value: teacherId.uuidString)
                .gte("session_date", value: today)
                .lte("session_date", value: nextWeek)
                .order("session_date")
                .order("start_time")
                .execute()
                .value

            // Compte les inscrits par cours
            let courseIds = Array(Set(sessions.map { $0.courseId.uuidString }))
            if !courseIds.isEmpty {
                let enrollments: [Enrollment] = try await supabase
                    .from("enrollments")
                    .select()
                    .in("course_id", values: courseIds)
                    .execute()
                    .value

                // Groupe par course_id
                var counts: [UUID: Int] = [:]
                for e in enrollments {
                    counts[e.courseId, default: 0] += 1
                }
                enrollmentCounts = counts
            }

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Ouvre la fenêtre d'émargement pour une session
    func openSignWindow(sessionId: UUID) async {
        do {
            try await supabase
                .rpc("open_sign_window", params: [
                    "p_session_id": sessionId.uuidString,
                    "p_duration_minutes": "60"
                ])
                .execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
