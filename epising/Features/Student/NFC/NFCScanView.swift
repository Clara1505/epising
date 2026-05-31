//
//  NFCScanView.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import SwiftUI
import PencilKit

enum SigningStep {
    case idle
    case signing
    case loading
    case success
    case error(String)
}

struct NFCScanView: View {

    let session: SessionWithCourse

    @State private var step: SigningStep = .idle
    @State private var nfcManager = NFCManager()
    @State private var drawing = PKDrawing()
    @State private var scannedTagId: String = ""

    var body: some View {
        VStack(spacing: 24) {
            switch step {

            case .idle:
                VStack(spacing: 32) {
                    Spacer()
                    Image(systemName: "wave.3.right.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.blue)
                    Text("Prêt à émarger")
                        .font(.title2.bold())
                    VStack(spacing: 4) {
                        Text(session.courses.title)
                            .font(.headline).foregroundStyle(.secondary)
                        Label(session.timeRange, systemImage: "clock")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Label(session.courses.room, systemImage: "door.left.hand.open")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(spacing: 12) {
                        Button {
                            Task { await startNFCScan() }
                        } label: {
                            Label("Scanner le tag NFC", systemImage: "wave.3.right")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        #if DEBUG
                        Button {
                            scannedTagId = session.courses.teacherNfcCardId ?? session.courses.nfcTagId
                            withAnimation { step = .signing }
                        } label: {
                            Label("Simuler NFC (DEBUG)", systemImage: "ant.fill")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                        #endif
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }

            case .signing:
                VStack(spacing: 16) {
                    Text("Signez pour confirmer")
                        .font(.headline).foregroundStyle(.secondary)

                    let isValid = SignatureValidator.isValid(drawing)
                    let length  = SignatureValidator.totalStrokeLength(in: drawing)
                    let progress = min(length / SignatureValidator.minimumStrokeLength, 1.0)

                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isValid ? Color.green : Color(.systemGray4), lineWidth: 2)
                        SignatureView(drawing: $drawing)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        if drawing.strokes.isEmpty {
                            Text("Signez ici")
                                .foregroundStyle(.tertiary)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal)

                    ProgressView(value: progress)
                        .tint(progress >= 1 ? .green : .blue)
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        Button("Effacer") { drawing = PKDrawing() }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            Task { await submitSignature() }
                        } label: {
                            Text("Confirmer")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isValid ? Color.blue : Color(.systemGray4))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!isValid)
                    }
                    .padding(.horizontal)
                }

            case .loading:
                ProgressView("Enregistrement...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .success:
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.green)
                    Text("Présence enregistrée !")
                        .font(.title.bold())
                    Text(session.courses.title)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

            case .error(let msg):
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.red)
                    Text("Échec de l'émargement")
                        .font(.title2.bold())
                    Text(msg)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    Button("Réessayer") { step = .idle }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
            }
        }
        .navigationTitle(session.courses.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // ── Actions ───────────────────────────────────────────────

    private func startNFCScan() async {
        do {
            let tagId = try await nfcManager.scan()
            scannedTagId = tagId
            withAnimation { step = .signing }
        } catch {
            step = .error("Scan NFC annulé ou échoué. Réessaie.")
        }
    }

    private func submitSignature() async {
        guard SignatureValidator.isValid(drawing) else {
            step = .error("Signature trop courte. Signe complètement.")
            return
        }
        step = .loading
        let result = await nfcManager.validateWithBackend(nfcTagId: scannedTagId)
        switch result {
        case .success:
            withAnimation { step = .success }
        case .failure(let error):
            step = .error(error.errorDescription ?? "Erreur inconnue.")
        }
    }
}
