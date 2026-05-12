//
//  ScheduleViewModel.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation
import Supabase

// Modèle de session enrichie avec les infos du cours (join Supabase)
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

    // Affichage : "09:00 – 12:00"
    var timeRange: String {
        "\(String(startTime.prefix(5))) – \(String(endTime.prefix(5)))"
    }

    // Fenêtre d'émargement ouverte ?
    var isSignWindowOpen: Bool {
        guard let open = signOpenAt, let close = signCloseAt else { return false }
        let now = Date()
        return now >= open && now <= close
    }

    // Date parsée pour comparaison
    var date: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: sessionDate)
    }

    // Aujourd'hui ?
    var isToday: Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date)
    }
}

@MainActor
@Observable
class ScheduleViewModel {

    var sessions: [SessionWithCourse] = []
    var isLoading = false
    var errorMessage: String?

    // Sessions du jour
    var todaySessions: [SessionWithCourse] {
        sessions.filter { $0.isToday }
            .sorted { $0.startTime < $1.startTime }
    }

    // Sessions à venir (pas aujourd'hui)
    var upcomingSessions: [SessionWithCourse] {
        sessions.filter { !$0.isToday }
            .sorted { ($0.sessionDate, $0.startTime) < ($1.sessionDate, $1.startTime) }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Plage : aujourd'hui + 7 jours
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today = formatter.string(from: Date())
            let nextWeek = formatter.string(
                from: Calendar.current.date(byAdding: .day, value: 7, to: Date())!
            )

            sessions = try await supabase
                .from("sessions")
                .select("*, courses(title, room, nfc_tag_id)")
                .gte("session_date", value: today)
                .lte("session_date", value: nextWeek)
                .order("session_date")
                .order("start_time")
                .execute()
                .value
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
