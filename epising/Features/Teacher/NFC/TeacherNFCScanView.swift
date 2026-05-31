//
//  TeacherNFCScanView.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import SwiftUI

struct TeacherNFCScanView: View {

    let teacherProfile: Profile
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss  // ← AJOUT

    @State private var nfcManager = NFCManager()
    @State private var isScanning = false
    @State private var message:   String?
    @State private var isSuccess  = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icône animée
            ZStack {
                Circle()
                    .fill(isSuccess
                          ? Color.green.opacity(0.15)
                          : Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: isSuccess
                      ? "checkmark.circle.fill"
                      : "wave.3.right.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(isSuccess ? .green : .blue)
                    .animation(.easeInOut, value: isSuccess)
            }

            // Texte central
            VStack(spacing: 8) {
                Text(isSuccess ? "Séance ouverte !" : "Scanner votre carte")
                    .font(.title2.bold())

                if let msg = message {
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(isSuccess ? .green : .red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("Les étudiants pourront émarger\nen scannant votre carte pendant 60 min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            Spacer()

            VStack(spacing: 12) {

                if !isSuccess {
                    // Bouton NFC réel
                    Button {
                        Task { await scanTeacherCard() }
                    } label: {
                        Group {
                            if isScanning {
                                ProgressView().tint(.white)
                            } else {
                                Label("Scanner ma carte NFC", systemImage: "wave.3.right")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isScanning)

                    // Mode DEBUG simulateur
                    #if DEBUG
                    Button {
                        Task { await openWithDebug() }
                    } label: {
                        Label("Simuler scan carte (DEBUG)", systemImage: "ant.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    #endif

                } else {
                    Button {
                        onSuccess()
                        dismiss()  // ← AJOUT
                    } label: {
                        Text("Retour à mes cours")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationTitle("Ouvrir l'émargement")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scanTeacherCard() async {
        isScanning = true
        message = nil
        do {
            let cardId = try await nfcManager.scan()
            await openSession(cardId: cardId)
        } catch {
            message = "NFC non disponible sur ce device.\nUtilise le bouton DEBUG."
        }
        isScanning = false
    }

    private func openWithDebug() async {
        message = nil
        let cardId = teacherProfile.nfcCardId ?? "EPITA-PROF-DEBUG"
        await openSession(cardId: cardId)
    }

    private func openSession(cardId: String) async {
        let result = await nfcManager.openTeacherSession(nfcCardId: cardId)
        withAnimation {
            isSuccess = result.success
            message   = result.message
        }
        if result.success {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            onSuccess()
            // dismiss() géré par le bouton "Retour à mes cours"
        }
    }
}
