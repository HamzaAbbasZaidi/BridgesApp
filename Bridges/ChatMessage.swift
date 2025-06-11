//
//  ChatMessage.swift
//  Bridges
//
//  Created by Hamza Zaidi on 19/05/2025.
//


import Foundation
import FirebaseFirestore

struct ChatMessage: Identifiable, Codable {
    @DocumentID var id: String?
    var text: String
    var senderId: String
    var senderName: String
    var timestamp: Date
}
