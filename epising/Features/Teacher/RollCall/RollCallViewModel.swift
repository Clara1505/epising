//
//  RollCallViewModel.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation
import Supabase

struct StudentAttendance: Identifiable {
    let id: UUID          // attendance id (ou student id si pas encore créé)
    let studentId: UUID
    let fullName: String
    let email: String
    var status: AttendanceStatus
    let signedAt: Date?
    let leftAt: Date?
}

@MainActor
@Observable
class RollCallViewModel {

    var students: [StudentAttendance] = []
    var isLoading = false
    var errorMessage: String?

    var presentCount: Int {
        students.filter { $0.status == .present || $0.status == .earlyLeave }.count
    }
    var absentCount: Int {
        students.filter { $0.status == .absent }.count
    }
    var pendingCount: Int {
        students.filter { $0.status == .pending }.count
    }

    func load(session: TeacherSession) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // 1. Récupère les inscrits au cours
            struct EnrollmentWithProfile: Codable {
                let studentId: UUID
                let profiles: ProfileInfo

                struct ProfileInfo: Codable {
                    let fullName: String
                    let email: String

                    enum CodingKeys: String, CodingKey {
                        case email
                        case fullName = "full_name"
                    }
                }

                enum CodingKeys: String, CodingKey {
                    case studentId = "student_id"
                    case profiles
                }
            }

            let enrollments: [EnrollmentWithProfile] = try await supabase
                .from("enrollments")
                .select("student_id, profiles(full_name, email)")
                .eq("course_id", value: session.courseId.uuidString)
                .execute()
                .value

            // 2. Récupère les attendances existantes
            let attendances: [Attendance] = try await supabase
                .from("attendances")
                .select("id, session_id, student_id, status, signed_at, marked_by, device_id, left_at, teacher_note")
                .eq("session_id", value: session.id.uuidString)
                .execute()
                .value

            let attendanceMap = Dictionary(
                uniqueKeysWithValues: attendances.map { ($0.studentId, $0) }
            )

            // 3. Merge : pour chaque inscrit, récupère son statut
            students = enrollments.map { enrollment in
                let att = attendanceMap[enrollment.studentId]
                return StudentAttendance(
                    id: att?.id ?? UUID(),
                    studentId: enrollment.studentId,
                    fullName: enrollment.profiles.fullName,
                    email: enrollment.profiles.email,
                    status: att?.status ?? .pending,
                    signedAt: att?.signedAt,
                    leftAt: att?.leftAt
                )
            }
            .sorted { $0.fullName < $1.fullName }

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Marquer présent manuellement
    func markPresent(studentId: UUID, sessionId: UUID) async {
        await upsertAttendance(
            studentId: studentId,
            sessionId: sessionId,
            status: "present"
        )
    }
    
    func markAbsent(studentId: UUID, sessionId: UUID) async {
        await upsertAttendance(
            studentId: studentId,
            sessionId: sessionId,
            status: "absent"
        )
    }

    // Marquer parti tôt
    func markEarlyLeave(studentId: UUID, sessionId: UUID) async {
        await upsertAttendance(
            studentId: studentId,
            sessionId: sessionId,
            status: "early_leave",
            leftAt: Date()
        )
    }

    private func upsertAttendance(
        studentId: UUID,
        sessionId: UUID,
        status: String,
        leftAt: Date? = nil
    ) async {
        do {
            struct UpsertBody: Encodable {
                let session_id: String
                let student_id: String
                let status: String
                let marked_by: String
                let left_at: Date?
            }

            try await supabase
                .from("attendances")
                .upsert(UpsertBody(
                    session_id: sessionId.uuidString,
                    student_id: studentId.uuidString,
                    status: status,
                    marked_by: "teacher_manual",
                    left_at: leftAt
                ), onConflict: "session_id,student_id")
                .execute()

            // Met à jour localement sans recharger
            if let idx = students.firstIndex(where: { $0.studentId == studentId }) {
                students[idx] = StudentAttendance(
                    id: students[idx].id,
                    studentId: studentId,
                    fullName: students[idx].fullName,
                    email: students[idx].email,
                    status: status == "present" ? .present : .earlyLeave,
                    signedAt: students[idx].signedAt,
                    leftAt: leftAt
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
