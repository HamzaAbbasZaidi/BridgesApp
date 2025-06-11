//
//  Issue.swift
//  Bridges
//
//  Created by Hamza Zaidi on 15/05/2025.
//


import Foundation

struct Issue: Identifiable, Hashable, Encodable {
    var id: String
    var title: String
    var description: String
    var activityScore: Int
    var category: String?
}
