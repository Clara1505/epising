//
//  ScheduleViewModel.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation
import Supabase

struct SessionWithCourse: Codable, Identifiable {
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
        let profiles: TeacherInfo?

        struct TeacherInfo: Codable {
            let nfcCardId: String?
            enum CodingKeys: String, CodingKey {
                case nfcCardId = "nfc_card_id"
            }
        }

        var teacherNfcCardId: String? { profiles?.nfcCardId }

        enum CodingKeys: String, CodingKey {
            case title, room, profiles
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
        f.locale = Locale(identifier: "fr_FR")
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
}

@MainActor
@Observable
class ScheduleViewModel {

    var sessions: [SessionWithCourse] = []
    var attendanceBySession: [UUID: AttendanceStatus] = [:]
    var isLoading = false
    var errorMessage: String?

    var todaySessions: [SessionWithCourse] {
        sessions.filter { $0.isToday }
            .sorted { $0.startTime < $1.startTime }
    }

    var upcomingSessions: [SessionWithCourse] {
        sessions.filter { !$0.isToday }
            .sorted { ($0.sessionDate, $0.startTime) < ($1.sessionDate, $1.startTime) }
    }

    func load() async {
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

            sessions = try await supabase
                .from("sessions")
                .select("*, courses(title, room, nfc_tag_id, profiles(nfc_card_id))")
                .gte("session_date", value: today)
                .lte("session_date", value: nextWeek)
                .order("session_date")
                .order("start_time")
                .execute()
                .value

            let sessionIds = sessions.map { $0.id.uuidString }
            if !sessionIds.isEmpty {
                let attendances: [Attendance] = try await supabase
                    .from("attendances")
                    .select("id, session_id, student_id, status, signed_at, marked_by, device_id, left_at, teacher_note")
                    .in("session_id", values: sessionIds)
                    .execute()
                    .value

                attendanceBySession = Dictionary(
                    uniqueKeysWithValues: attendances.map { ($0.sessionId, $0.status) }
                )
            }

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
