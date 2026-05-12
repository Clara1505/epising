//
//  SignatureValidator.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import UIKit
import PencilKit

struct SignatureValidator {

    static let minimumStrokeLength: CGFloat = 200

    // Calcule la longueur totale des traits
    static func totalStrokeLength(in drawing: PKDrawing) -> CGFloat {
        drawing.strokes.reduce(0) { total, stroke in
            total + strokeLength(stroke)
        }
    }

    // Longueur d'un trait individuel
    private static func strokeLength(_ stroke: PKStroke) -> CGFloat {
        let points = stroke.path
        guard points.count > 1 else { return 0 }

        var length: CGFloat = 0
        for i in 1..<points.count {
            let p1 = points[i - 1].location
            let p2 = points[i].location
            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            length += sqrt(dx * dx + dy * dy)
        }
        return length
    }

    // Vérifie si la signature est valide
    static func isValid(_ drawing: PKDrawing) -> Bool {
        !drawing.strokes.isEmpty &&
        totalStrokeLength(in: drawing) >= minimumStrokeLength
    }
}
