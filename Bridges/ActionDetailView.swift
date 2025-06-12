import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

struct ActionDetailView: View {
    let action: SuggestedAction

    @State private var hasConfirmed = false
    @State private var isComplete = false
    @State private var message = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var navigateToLeaderboard = false
    @State private var issueTitle: String = "Action"
    @State private var chatPrompt: String = ""
    
    let promptOptions = [
        "What's your favorite celebrity and why?",
        "If you could visit any country right now, where would you go?",
        "What's the weirdest food you've ever tried?",
        "If you had a superpower for one day, what would it be?",
        "What's a movie you could watch a hundred times?",
        "Which song always puts you in a good mood?",
        "What's something small that always makes you smile?",
        "If you were an animal, what would you be?",
        "What’s the best gift you’ve ever received?",
        "What's something people always misunderstand about you?"
    ]

    let uid = Auth.auth().currentUser?.uid

    var body: some View {
        VStack(spacing: 24) {
            Text("Action Details")
                .font(.largeTitle.bold())

            Text(action.text)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()

            if let points = action.points {
                Text("\(points) point\(points == 1 ? "" : "s") for completing this action")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "person.3.fill")
                Text("Participants: \(action.participants.count)/\(action.threshold)")
            }
            .font(.subheadline)
            .foregroundColor(.gray)

            let confirmationsCount = action.confirmedBy?.count ?? 0
            let participantsCount = action.participants.count
            let threshold = action.threshold

            if participantsCount < threshold {
                Text("Waiting for more participants to join before confirming.")
                    .foregroundColor(.gray)

            } else if isComplete || (confirmationsCount == participantsCount) {
                Text("✅ This action has been completed!")
                    .foregroundColor(.green)
                    .bold()

                NavigationLink(destination: LeaderboardView(issueId: action.issueId ?? "", category: action.category ?? "", issueTitle: issueTitle), isActive: $navigateToLeaderboard) {
                    Button("View Leaderboard") {
                        navigateToLeaderboard = true
                    }
                    .padding()
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

            } else if hasConfirmed {
                Text("Waiting for others to confirm...")
                    .foregroundColor(.orange)

            } else {
                Button("Confirm Completion") {
                    confirmCompletion()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            if !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Conversation Starter")
                    .font(.headline)
                Text(chatPrompt)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top)


            Spacer()

            Text("Chat with other participants")
                .font(.headline)
                .padding(.top)

            ChatView(
                category: action.category?.lowercased() ?? "",
                issueId: action.issueId ?? "",
                actionId: action.id ?? ""
            )
            .frame(height: 300)
        }
        .padding()
        .navigationTitle(issueTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            
            let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
            chatPrompt = promptOptions[dayIndex % promptOptions.count]

            
            if let uid = uid {
                hasConfirmed = action.confirmedBy?.contains(uid) ?? false
                isComplete = action.status == "completed"
            }
            
            
            if let category = action.category?.lowercased(), let issueId = action.issueId {
                let db = Firestore.firestore()
                let issueRef = db.collection("categories").document(category)
                    .collection("issues").document(issueId)
                
                issueRef.getDocument { document, error in
                    if let data = document?.data(), let title = data["title"] as? String {
                        issueTitle = title
                    }
                }
            }

            
        }
    }

    func confirmCompletion() {
        guard let uid = uid,
              let category = action.category?.lowercased(),
              let issueId = action.issueId,
              let actionId = action.id else {
            message = "Missing info"
            return
        }

        let db = Firestore.firestore()
        let actionRef = db.collection("categories").document(category)
            .collection("issues").document(issueId)
            .collection("action").document(actionId)

        actionRef.updateData([
            "confirmedBy": FieldValue.arrayUnion([uid])
        ]) { error in
            if let error = error {
                message = "Error confirming: \(error.localizedDescription)"
            } else {
                hasConfirmed = true
                message = "Confirmation submitted"

                db.runTransaction({ (transaction, errorPointer) -> Any? in
                    let snapshot: DocumentSnapshot
                    do {
                        snapshot = try transaction.getDocument(actionRef)
                    } catch {
                        return nil
                    }

                    guard let confirmedBy = snapshot.get("confirmedBy") as? [String],
                          let participants = snapshot.get("participants") as? [String],
                          let points = snapshot.get("points") as? Int else {
                        return nil
                    }

                    let notConfirmed = participants.filter { !confirmedBy.contains($0) }

                    if notConfirmed.isEmpty {
                        transaction.updateData([
                            "status": "completed"
                        ], forDocument: actionRef)

                        for uid in participants {
                            let userRef = db.collection("users").document(uid)
                            transaction.updateData([
                                "points": FieldValue.increment(Int64(points))
                            ], forDocument: userRef)
                        }
                    }

                    return nil
                }) { _, error in
                    if let error = error {
                        print("Transaction failed: \(error)")
                    } else {
                        isComplete = true
                    }
                }
            }
        }
    }
}
