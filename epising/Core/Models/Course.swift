//
//  Course.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation

struct Course: Codable, Identifiable {
    let id:       UUID
    let title:    String
    let teacherId: UUID
    let room:     String
    let nfcTagId: String

    enum CodingKeys: String, CodingKey {
        case id, title, room
        case teacherId = "teacher_id"
        case nfcTagId  = "nfc_tag_id"
    }
}
