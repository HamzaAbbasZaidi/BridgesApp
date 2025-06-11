import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct IssueDetailView: View {
    let issue: Issue
    
    @State private var suggestedActions: [SuggestedAction] = []
    @State private var joinedActions: [SuggestedAction] = []
    @State private var userComfortLevel: Int = 1
    @State private var showActsOfKindness = false

    
    var uid: String? {
        Auth.auth().currentUser?.uid
    }

    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                GeometryReader { geometry in
                    let progress = CGFloat(min(issue.activityScore, 100)) / 100.0
                    let maskWidth = geometry.size.width * progress
                    
                    Image("bridge_full")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: 100)
                        .clipped()
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle()
                                    .frame(width: maskWidth)
                                Spacer(minLength: 0)
                            }
                        )
                }
                .frame(height: 100)
                
                Text(issue.title)
                    .font(.largeTitle.bold())
                
                Text(issue.description)
                    .font(.body)
                    .padding(.horizontal)
                
                Button("Acts of Kindness") {
                    showActsOfKindness = true
                }
                .font(.headline)
                .padding()
                .background(Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)

                
                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Suggested Collaborative Actions")
                        .font(.title2.bold())
                        .padding(.bottom, 4)
                    
                    if suggestedActions.isEmpty {
                        Text("No actions match your comfort level right now. Try increasing your engagement or check back later.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.top)
                    } else {
                        ForEach(suggestedActions) { action in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(action.text)
                                    .font(.headline)
                                
                                Text("\(action.points ?? 0) points")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 16) {
                                    VStack(spacing: 4) {
                                        Button(action: {
                                            acceptAction(action)
                                        }) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .imageScale(.large)
                                        }
                                        Text("Yes, I'd do this")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Button(action: {
                                            rejectAction(action)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .imageScale(.large)
                                        }
                                        Text("No, not right now")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                    
                                    Spacer()
                                    Text("\(action.participants.count) participant(s)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Agreed Actions")
                        .font(.title2.bold())
                        .padding(.bottom, 4)
                    
                    if joinedActions.isEmpty {
                        Text("You haven't agreed to any actions yet.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    } else {
                        ForEach(joinedActions) { action in
                            NavigationLink(destination: ActionDetailView(action: action)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(action.text)
                                        .font(.headline)
                                    
                                    Text("\(action.points ?? 0) points")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    Text("\(action.participants.count) participant(s)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }

                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .navigationTitle(issue.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showActsOfKindness) {
            ActsOfKindnessView(issue: issue)
        }

        .onAppear {
            fetchComfortLevel()
        }
    }
    
    func fetchComfortLevel() {
        guard let uid else { return }
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(uid).collection("stances").document(issue.id)
        
        docRef.getDocument { snapshot, error in
            if let data = snapshot?.data(), let level = data["comfortLevel"] as? Int {
                self.userComfortLevel = level
                fetchSuggestedActions()
            } else {
                self.userComfortLevel = 1
                fetchSuggestedActions()
            }
        }
    }
    
    func fetchSuggestedActions() {
        guard let category = issue.category?.lowercased(), let uid else { return }
        let db = Firestore.firestore()
        let actionRef = db.collection("categories").document(category)
            .collection("issues").document(issue.id)
            .collection("action")

        let rejectedRef = db.collection("users").document(uid)
            .collection("rejectedActions")

        // Step 1: Fetch rejected actions first
        rejectedRef.getDocuments { rejectionSnapshot, _ in
            let rejectedIds: Set<String> = Set(rejectionSnapshot?.documents.map { $0.documentID } ?? [])

            // Step 2: Now fetch all available actions
            actionRef.getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else { return }

                let allActions = docs.compactMap { try? $0.data(as: SuggestedAction.self) }
                self.joinedActions = allActions.filter { $0.participants.contains(uid) }

                // Step 3: Remove joined and rejected actions
                let unjoinedActions = allActions.filter {
                    !($0.participants.contains(uid)) &&
                    !(rejectedIds.contains($0.id ?? ""))
                }

                let comfortMatches = unjoinedActions.filter {
                    ($0.difficulty ?? 1) <= userComfortLevel
                }

                var final = comfortMatches

                // Step 4: Add slightly harder actions if needed
                if final.count < 3 {
                    let harderMatches = unjoinedActions.filter {
                        ($0.difficulty ?? 1) == userComfortLevel + 1 &&
                        !final.contains(where: { $0.id == $0.id })
                    }
                    final.append(contentsOf: harderMatches.prefix(3 - final.count))
                }

                self.suggestedActions = Array(final.prefix(3))

                if self.suggestedActions.count < 3 {
                    generateActionsWithGeminiIfNeeded(currentCount: self.suggestedActions.count)
                }
            }
        }
    }

    
    func generateActionsWithGeminiIfNeeded(currentCount: Int) {
        guard let category = issue.category?.lowercased(), let uid else { return }
        let needed = 3 - currentCount
        let db = Firestore.firestore()

        let userDoc = db.collection("users").document(uid)

        userDoc.collection("acceptedActions").whereField("issueId", isEqualTo: issue.id).getDocuments { acceptedSnap, _ in
            userDoc.collection("rejectedActions").whereField("issueId", isEqualTo: issue.id).getDocuments { rejectedSnap, _ in

                let accepted = acceptedSnap?.documents.compactMap { $0.data()["text"] as? String } ?? []
                let rejected = rejectedSnap?.documents.compactMap { $0.data()["text"] as? String } ?? []

                let prompt = """
                Suggest \(needed) short, specific collaborative actions that strangers can do together directly related to the issue titled "\(issue.title)". These strangers are potentially on different sides of the issue. This action should involve them physically getting together and doing something tangible. However, it should not directly involve discussing the issue at hand.

                The user has a comfort level of \(userComfortLevel) out of 5.

                Return your response in *exactly* the following format for each action:

                Action: [short description]
                Points: [10–100, based on effort, empathy, or impact]
                Participants: [minimum number of people required]

                Do not include any commentary, markdown, or explanations. Only list the actions in the format above.

                Actions the user has already accepted:
                \(accepted.map { "- \($0)" }.joined(separator: "\n"))

                Actions the user has rejected:
                \(rejected.map { "- \($0)" }.joined(separator: "\n"))
                """

                let apiKey = "AIzaSyAuBhbG37VharRwRA3VM2rKrPvDnuEl5sM"
                guard let url = URL(string: "https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent?key=\(apiKey)") else {
                    print("❌ Invalid Gemini URL")
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = [
                    "contents": [["parts": [["text": prompt]]]]
                ]

                request.httpBody = try? JSONSerialization.data(withJSONObject: body)

                URLSession.shared.dataTask(with: request) { data, _, error in
                    guard let data = data, error == nil else {
                        print("❌ Gemini API request failed: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }

                    do {
                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                        print("🔍 Raw Gemini response:\n\(json ?? [:])")
                        if let candidates = json?["candidates"] as? [[String: Any]],
                           let content = candidates.first?["content"] as? [String: Any],
                           let parts = content["parts"] as? [[String: Any]],
                           let text = parts.first?["text"] as? String {

                            let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                            var parsedSuggestions: [(text: String, points: Int, threshold: Int)] = []

                            var currentText: String?
                            var currentPoints: Int?
                            var currentThreshold: Int?

                            for line in lines {
                                if line.lowercased().starts(with: "action:") {
                                    currentText = line.replacingOccurrences(of: "Action:", with: "").trimmingCharacters(in: .whitespaces)
                                } else if line.lowercased().starts(with: "points:") {
                                    currentPoints = Int(line.replacingOccurrences(of: "Points:", with: "").trimmingCharacters(in: .whitespaces))
                                } else if line.lowercased().starts(with: "participants:") {
                                    currentThreshold = Int(line.replacingOccurrences(of: "Participants:", with: "").trimmingCharacters(in: .whitespaces))
                                }

                                if let text = currentText, let points = currentPoints, let threshold = currentThreshold {
                                    parsedSuggestions.append((text, points, threshold))
                                    currentText = nil
                                    currentPoints = nil
                                    currentThreshold = nil
                                }
                            }

                            DispatchQueue.main.async {
                                for (text, points, threshold) in parsedSuggestions.prefix(needed) {
                                    let newAction = SuggestedAction(
                                        id: UUID().uuidString,
                                        text: text,
                                        createdBy: "gemini",
                                        difficulty: self.userComfortLevel,
                                        threshold: threshold,
                                        participants: [],
                                        category: self.issue.category,
                                        issueId: self.issue.id,
                                        points: points
                                    )

                                    self.suggestedActions.append(newAction)

                                    let docRef = db.collection("categories").document(category)
                                        .collection("issues").document(issue.id)
                                        .collection("action").document(newAction.id!)

                                    do {
                                        try docRef.setData(from: newAction)
                                    } catch {
                                        print("❌ Failed to save action: \(error.localizedDescription)")
                                    }
                                }
                            }

                        } else {
                            print("❌ Unexpected Gemini response format")
                        }
                    } catch {
                        print("❌ Gemini JSON parsing error: \(error)")
                    }

                }.resume()
            }
        }
    }



    
    func acceptAction(_ action: SuggestedAction) {
        guard let uid,
              let category = issue.category?.lowercased(),
              let actionId = action.id else { return }

        let db = Firestore.firestore()

        let actionRef = db.collection("categories").document(category)
            .collection("issues").document(issue.id)
            .collection("action").document(actionId)

        // Add user to participants
        actionRef.updateData([
            "participants": FieldValue.arrayUnion([uid])
        ]) { error in
            if let error = error {
                print("❌ Firestore update error: \(error.localizedDescription)")
                return
            }

            // Update UI immediately
            if let index = suggestedActions.firstIndex(where: { $0.id == action.id }) {
                var updated = action
                updated.participants.append(uid)
                suggestedActions.remove(at: index)
                joinedActions.append(updated)
            }

            // Also log it in acceptedActions
            let userRef = db.collection("users").document(uid)
                .collection("acceptedActions").document(actionId)

            userRef.setData([
                "text": action.text,
                "difficulty": action.difficulty ?? 1,
                "points": action.points ?? 0,
                "category": category,
                "issueId": issue.id,
                "timestamp": Timestamp(date: Date())
            ])
 { err in
                if let err = err {
                    print("❌ Failed to write to acceptedActions: \(err.localizedDescription)")
                }
            }
        }
    }

    
    func rejectAction(_ action: SuggestedAction) {
        guard let uid,
              let category = issue.category?.lowercased(),
              let actionId = action.id else {
            return
        }

        let db = Firestore.firestore()
        let rejectionRef = db.collection("users").document(uid)
            .collection("rejectedActions").document(actionId)

        rejectionRef.setData([
            "category": category,
            "issueId": issue.id,
            "timestamp": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("❌ Error rejecting action: \(error.localizedDescription)")
            } else {
                // Optional: remove it from the UI immediately
                if let index = suggestedActions.firstIndex(where: { $0.id == action.id }) {
                    suggestedActions.remove(at: index)
                }
            }
        }
    }

    
    
    
}
