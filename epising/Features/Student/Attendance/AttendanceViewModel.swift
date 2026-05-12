//
//  AttendanceViewModel.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation
import Supabase

struct AttendanceWithSession: Codable, Identifiable {
    let id: UUID
    let status: AttendanceStatus
    let signedAt: Date?
    let markedBy: MarkedBy?
    let leftAt: Date?
    let sessions: SessionInfo

    struct SessionInfo: Codable {
        let sessionDate: String
        let slot: TimeSlot
        let startTime: String
        let courses: CourseInfo

        struct CourseInfo: Codable {
            let title: String
            let room: String

            enum CodingKeys: String, CodingKey {
                case title, room
            }
        }

        enum CodingKeys: String, CodingKey {
            case slot
            case sessionDate = "session_date"
            case startTime   = "start_time"
            case courses
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, status
        case signedAt  = "signed_at"
        case markedBy  = "marked_by"
        case leftAt    = "left_at"
        case sessions
    }

    // "Lun. 12 mai"
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "fr_FR")
        guard let date = formatter.date(from: sessions.sessionDate) else {
            return sessions.sessionDate
        }
        let display = DateFormatter()
        display.dateFormat = "EEE. d MMM"
        display.locale = Locale(identifier: "fr_FR")
        return display.string(from: date).capitalized
    }
}

@MainActor
@Observable
class AttendanceViewModel {

    var attendances: [AttendanceWithSession] = []
    var isLoading = false
    var errorMessage: String?

    // Taux de présence en %
    var attendanceRate: Int {
        guard !attendances.isEmpty else { return 0 }
        let present = attendances.filter {
            $0.status == .present || $0.status == .earlyLeave
        }.count
        return Int(Double(present) / Double(attendances.count) * 100)
    }

    var presentCount: Int {
        attendances.filter { $0.status == .present || $0.status == .earlyLeave }.count
    }

    var absentCount: Int {
        attendances.filter { $0.status == .absent }.count
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            attendances = try await supabase
                .from("attendances")
                .select("*, sessions(session_date, slot, start_time, courses(title, room))")
                .neq("status", value: "pending")
                .order("sessions(session_date)", ascending: false)
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
