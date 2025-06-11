//
//  LeaderboardView.swift
//  Bridges
//
//  Created by Hamza Zaidi on 21/05/2025.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct LeaderboardEntry: Identifiable {
    var id: String
    var displayName: String
    var points: Int
}

struct LeaderboardView: View {
    let issueId: String
    let category: String
    let issueTitle: String
    
    @State private var leaderboard: [LeaderboardEntry] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 16) {
            Text("Leaderboard for \(issueTitle)")
                .font(.largeTitle.bold())
                .padding(.top)

            if isLoading {
                ProgressView()
            } else {
                List(leaderboard.sorted(by: { $0.points > $1.points })) { entry in
                    HStack {
                        Text(entry.displayName)
                        Spacer()
                        Text("\(entry.points) pts")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            fetchLeaderboard()
        }
    }

    func fetchLeaderboard() {
        let db = Firestore.firestore()
        let issueRef = db.collection("categories").document(category.lowercased())
            .collection("issues").document(issueId)

        issueRef.collection("action").getDocuments { snapshot, error in
            guard let docs = snapshot?.documents else {
                self.isLoading = false
                return
            }

            var userPoints = [String: Int]()
            for doc in docs {
                let data = doc.data()
                let participants = data["participants"] as? [String] ?? []
                let status = data["status"] as? String ?? ""
                let points = data["points"] as? Int ?? 0

                if status == "completed" {
                    for uid in participants {
                        userPoints[uid, default: 0] += points
                    }
                }
            }

            let group = DispatchGroup()
            var entries: [LeaderboardEntry] = []

            for (uid, totalPoints) in userPoints {
                group.enter()
                db.collection("users").document(uid).getDocument { userDoc, _ in
                    let name = (userDoc?.data()?["profile"] as? [String: Any])?["firstName"] as? String ?? "Anonymous"
                    entries.append(LeaderboardEntry(id: uid, displayName: name, points: totalPoints))
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.leaderboard = entries
                self.isLoading = false
            }
        }
    }
}
