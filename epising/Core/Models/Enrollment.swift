//
//  Enrollment.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation

struct Enrollment: Codable, Identifiable {
    let id:        UUID
    let courseId:  UUID
    let studentId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case courseId  = "course_id"
        case studentId = "student_id"
    }
}
