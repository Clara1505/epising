//
//  Attendance.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation

enum AttendanceStatus: String, Codable {
    case pending    = "pending"
    case present    = "present"
    case absent     = "absent"
    case earlyLeave = "early_leave"

    var label: String {
        switch self {
        case .pending:    return "En attente"
        case .present:    return "Présent"
        case .absent:     return "Absent"
        case .earlyLeave: return "Parti tôt"
        }
    }

    var color: String {
        switch self {
        case .pending:    return "gray"
        case .present:    return "green"
        case .absent:     return "red"
        case .earlyLeave: return "orange"
        }
    }
}

enum MarkedBy: String, Codable {
    case studentNfc    = "student_nfc"
    case teacherManual = "teacher_manual"
}

struct Attendance: Codable, Identifiable {
    let id:          UUID
    let sessionId:   UUID
    let studentId:   UUID
    var status:      AttendanceStatus
    let markedBy:    MarkedBy?
    let signedAt:    Date?
    let deviceId:    String?
    let leftAt:      Date?
    let teacherNote: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case sessionId   = "session_id"
        case studentId   = "student_id"
        case markedBy    = "marked_by"
        case signedAt    = "signed_at"
        case deviceId    = "device_id"
        case leftAt      = "left_at"
        case teacherNote = "teacher_note"
    }
}
