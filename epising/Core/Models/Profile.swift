//
//  Profile.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation

enum UserRole: String, Codable {
    case student = "student"
    case teacher = "teacher"
}

struct Profile: Codable, Identifiable {
    let id:        UUID
    let email:     String
    let fullName:  String
    let role:      UserRole
    let deviceId:  String?
    let nfcCardId: String?

    enum CodingKeys: String, CodingKey {
        case id, email, role
        case fullName  = "full_name"
        case deviceId  = "device_id"
        case nfcCardId = "nfc_card_id"
    }
}
