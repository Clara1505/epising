//
//  NFCManager.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation
import CoreNFC

enum NFCResult {
    case success(tagId: String)
    case failure(APIError)
}

@MainActor
@Observable
class NFCManager: NSObject {

    var isScanning = false
    var result: NFCResult?
    var errorMessage: String?

    private var session: NFCNDEFReaderSession?
    private var continuation: CheckedContinuation<String, Error>?

    // Lance le scan NFC
    func scan() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.session = NFCNDEFReaderSession(
                delegate: self,
                queue: nil,
                invalidateAfterFirstRead: true
            )
            self.session?.alertMessage = "Approche ton iPhone de la carte NFC."
            self.session?.begin()
            self.isScanning = true
        }
    }

    // Étudiant : valide la présence via la carte du prof
    func validateWithBackend(nfcTagId: String) async -> NFCResult {
        let deviceId = KeychainHelper.getOrCreateDeviceId()

        do {
            let response: NFCValidationResponse = try await supabase.functions
                .invoke(
                    "validate-nfc",
                    options: .init(body: [
                        "nfc_tag_id": nfcTagId,
                        "device_id":  deviceId
                    ])
                )

            if response.success {
                return .success(tagId: nfcTagId)
            } else {
                return .failure(APIError.from(response.reason ?? "unknown"))
            }
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }

    // Enseignant : ouvre la fenêtre d'émargement via sa carte
    func openTeacherSession(nfcCardId: String) async -> (success: Bool, message: String) {
        do {
            struct OpenResponse: Codable {
                let success: Bool
                let reason: String?
                let sessionId: String?
                let durationMinutes: Int?
                enum CodingKeys: String, CodingKey {
                    case success, reason
                    case sessionId       = "session_id"
                    case durationMinutes = "duration_minutes"
                }
            }

            let response: OpenResponse = try await supabase
                .rpc("open_session_by_teacher_card", params: [
                    "p_nfc_card_id":      nfcCardId,
                    "p_duration_minutes": "60"
                ])
                .execute()
                .value

            if response.success {
                return (true, "Fenêtre ouverte — les étudiants peuvent émarger pendant 60 min")
            } else {
                switch response.reason {
                case "no_active_session": return (false, "Aucune séance en cours à cette heure")
                case "teacher_not_found": return (false, "Carte non reconnue")
                default: return (false, response.reason ?? "Erreur inconnue")
                }
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }
}

// MARK: - Response model
struct NFCValidationResponse: Codable {
    let success: Bool
    let reason: String?
    let courseTitle: String?
    let signedAt: String?

    enum CodingKeys: String, CodingKey {
        case success, reason
        case courseTitle = "course_title"
        case signedAt    = "signed_at"
    }
}

// MARK: - NFCNDEFReaderSessionDelegate
extension NFCManager: NFCNDEFReaderSessionDelegate {

    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didDetectNDEFs messages: [NFCNDEFMessage]
    ) {
        guard let message = messages.first,
              let record = message.records.first,
              let payload = String(data: record.payload, encoding: .utf8)?
                .trimmingCharacters(in: .controlCharacters)
        else {
            Task { @MainActor in
                self.continuation?.resume(throwing: APIError.noActiveSession)
                self.continuation = nil
                self.isScanning = false
            }
            return
        }

        Task { @MainActor in
            self.continuation?.resume(returning: payload)
            self.continuation = nil
            self.isScanning = false
        }
    }

    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didInvalidateWithError error: Error
    ) {
        Task { @MainActor in
            if (error as NSError).code != 200 {
                self.continuation?.resume(throwing: error)
            } else {
                self.continuation?.resume(throwing: APIError.noActiveSession)
            }
            self.continuation = nil
            self.isScanning = false
        }
    }
}
