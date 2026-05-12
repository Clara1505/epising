//
//  NFC.swift
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

    // Lance le scan NFC et retourne le nfc_tag_id lu sur le tag
    func scan() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.session = NFCNDEFReaderSession(
                delegate: self,
                queue: nil,
                invalidateAfterFirstRead: true
            )
            self.session?.alertMessage = "Approche ton iPhone du lecteur NFC de la salle."
            self.session?.begin()
            self.isScanning = true
        }
    }

    // Appelle la Edge Function validate-nfc
    func validateWithBackend(nfcTagId: String) async -> NFCResult {
        let deviceId = KeychainHelper.getOrCreateDeviceId()

        do {
            let response: NFCValidationResponse = try await supabase.functions
                .invoke(
                    "validate-nfc",
                    options: .init(body: [
                        "nfc_tag_id": nfcTagId,
                        "device_id": deviceId
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
}

// Réponse de la Edge Function
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
            // L'utilisateur a annulé — pas une vraie erreur
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
