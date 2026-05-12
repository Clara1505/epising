//
//  CourseSession.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation

enum TimeSlot: String, Codable {
    case morning   = "morning"
    case afternoon = "afternoon"

    var label: String {
        self == .morning ? "Matin" : "Après-midi"
    }
}

struct CourseSession: Codable, Identifiable {
    let id:           UUID
    let courseId:     UUID
    let sessionDate:  String   // "2026-04-24"
    let slot:         TimeSlot
    let startTime:    String   // "09:00:00"
    let endTime:      String   // "12:00:00"
    let signOpenAt:   Date?
    let signCloseAt:  Date?

    enum CodingKeys: String, CodingKey {
        case id, slot
        case courseId    = "course_id"
        case sessionDate = "session_date"
        case startTime   = "start_time"
        case endTime     = "end_time"
        case signOpenAt  = "sign_open_at"
        case signCloseAt = "sign_close_at"
    }

    // Fenêtre d'émargement ouverte ?
    var isSignWindowOpen: Bool {
        guard let open = signOpenAt, let close = signCloseAt else { return false }
        let now = Date()
        return now >= open && now <= close
    }

    // Affichage horaire : "09:00 – 12:00"
    var timeRange: String {
        let start = String(startTime.prefix(5))
        let end   = String(endTime.prefix(5))
        return "\(start) – \(end)"
    }
}
