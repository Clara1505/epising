//
//  APIError.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation

enum APIError: LocalizedError {
    case notAuthenticated
    case notEnrolled
    case windowClosed
    case deviceMismatch
    case noActiveSession
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:  return "Tu n'es pas connecté."
        case .notEnrolled:       return "Tu n'es pas inscrit à ce cours."
        case .windowClosed:      return "La fenêtre d'émargement est fermée."
        case .deviceMismatch:    return "Cet iPhone n'est pas associé à ton compte."
        case .noActiveSession:   return "Aucune séance active trouvée pour cette salle."
        case .unknown(let msg):  return msg
        }
    }

    static func from(_ reason: String) -> APIError {
        switch reason {
        case "not_enrolled":      return .notEnrolled
        case "window_closed":     return .windowClosed
        case "device_mismatch":   return .deviceMismatch
        case "no_active_session": return .noActiveSession
        default:                  return .unknown(reason)
        }
    }
}
