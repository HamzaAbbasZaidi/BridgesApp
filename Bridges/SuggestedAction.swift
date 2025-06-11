//
//  SuggestedAction.swift
//  Bridges
//
//  Created by Hamza Zaidi on 19/05/2025.
//


import Foundation
import FirebaseFirestore

struct SuggestedAction: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var text: String
    var createdBy: String
    var difficulty: Int?
    var threshold: Int
    var participants: [String]
    var category: String?     // New
    var issueId: String?      // New
    var confirmedBy: [String]? // Optional: used during completion
    var status: String?        // e.g., "pending", "completed"
    var points: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, text, createdBy, difficulty, threshold, participants, category, issueId, confirmedBy, status, points
    }
}
