import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct ActsOfKindnessView: View {
    let issue: Issue

    @State private var pairing: (doerId: String, recipientId: String)? = nil
    @State private var proposedAction: String = ""
    @State private var doerAccepted = false
    @State private var recipientAccepted = false
    @State private var actionConfirmed = false
    @State private var loading = false
    @State private var userRole: String? = nil // "doer" or "recipient"
    @State private var isWaitingForPair = true
    @State private var pairDocRef: DocumentReference? = nil

    var body: some View {
        VStack(spacing: 24) {
            Text("Acts of Kindness")
                .font(.largeTitle.bold())
                .padding(.top)

            if isWaitingForPair {
                Text("You have joined the act as a \(userRole ?? "participant").")
                Text("Waiting for someone else to join...")
                    .foregroundColor(.orange)
                ProgressView()
            } else if actionConfirmed {
                Text("🎉 Action confirmed! Points will be allocated.")
                    .foregroundColor(.green)
            } else {
                Text("AI-Suggested Action")
                    .font(.title2)
                Text(proposedAction.isEmpty ? "Loading suggestion..." : proposedAction)
                    .multilineTextAlignment(.center)
                    .padding()

                if let uid = Auth.auth().currentUser?.uid {
                    if uid == pairing?.doerId && !doerAccepted {
                        Button("I can do this") {
                            doerAccepted = true
                            pairDocRef?.updateData(["doerAccepted": true])
                        }
                    } else if uid == pairing?.recipientId && !recipientAccepted {
                        Button("I agree to receive this") {
                            recipientAccepted = true
                            pairDocRef?.updateData(["recipientAccepted": true])
                        }
                    } else if (uid == pairing?.doerId && doerAccepted) || (uid == pairing?.recipientId && recipientAccepted) {
                        Text("Waiting on the other person to confirm...")
                            .foregroundColor(.orange)
                    }
                }

                if doerAccepted && recipientAccepted {
                    Button("Confirm and allocate points") {
                        actionConfirmed = true
                        allocatePoints()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                } else {
                    Button("Suggest another action") {
                        generateSuggestion()
                        doerAccepted = false
                        recipientAccepted = false
                        pairDocRef?.updateData(["doerAccepted": false, "recipientAccepted": false])
                    }
                    .disabled(loading)
                }
            }
            Spacer()
        }
        .padding()
        .onAppear {
            loadExistingOrPairUser()
        }
    }

    func loadExistingOrPairUser() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let pairRef = db.collection("issues").document(issue.id).collection("kindnessPairs")

        pairRef.whereField("active", isEqualTo: true)
            .whereFilter(Filter.orFilter([
                Filter.whereField("doer", isEqualTo: uid),
                Filter.whereField("recipient", isEqualTo: uid)
            ])).getDocuments { snapshot, _ in
                if let existing = snapshot?.documents.first {
                    let data = existing.data()
                    let doer = data["doer"] as? String ?? ""
                    let recipient = data["recipient"] as? String ?? ""
                    pairing = (doer, recipient)
                    userRole = (uid == doer ? "doer" : "recipient")
                    pairDocRef = existing.reference

                    if doer != "waiting" && recipient != "waiting" {
                        isWaitingForPair = false

                        if let existing = data["suggestedAction"] as? String, !existing.isEmpty {
                            self.proposedAction = existing
                        } else {
                            generateSuggestion()
                        }
                        
                        

                        if let doerAgreed = data["doerAccepted"] as? Bool {
                            self.doerAccepted = doerAgreed
                        }
                        if let recipientAgreed = data["recipientAccepted"] as? Bool {
                            self.recipientAccepted = recipientAgreed
                        }
                    } else {
                        isWaitingForPair = true
                        waitForReadiness(pairDoc: existing.reference)
                    }
                } else {
                    pairUsers(pairRef: pairRef)
                }
            }
    }

    func pairUsers(pairRef: CollectionReference) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        pairRef.whereField("active", isEqualTo: true).getDocuments { snapshot, _ in
            if let existingPair = snapshot?.documents.first {
                let data = existingPair.data()
                let pairDoc = existingPair.reference

                if let doer = data["doer"] as? String, doer == "waiting" {
                    pairDoc.updateData(["doer": uid])
                    pairing = (uid, data["recipient"] as? String ?? "")
                    userRole = "doer"
                    isWaitingForPair = true
                    pairDocRef = pairDoc
                    waitForReadiness(pairDoc: pairDoc)
                } else if let recipient = data["recipient"] as? String, recipient == "waiting" {
                    pairDoc.updateData(["recipient": uid])
                    pairing = (data["doer"] as? String ?? "", uid)
                    userRole = "recipient"
                    isWaitingForPair = true
                    pairDocRef = pairDoc
                    waitForReadiness(pairDoc: pairDoc)
                } else {
                    loadExistingOrPairUser()
                }
            } else {
                let isDoer = Bool.random()
                let doer = isDoer ? uid : "waiting"
                let recipient = isDoer ? "waiting" : uid
                userRole = isDoer ? "doer" : "recipient"

                let newDoc = pairRef.document()
                newDoc.setData([
                    "doer": doer,
                    "recipient": recipient,
                    "active": true
                ]) { _ in
                    pairing = (doer, recipient)
                    isWaitingForPair = true
                    pairDocRef = newDoc
                    waitForReadiness(pairDoc: newDoc)
                }
            }
        }
    }

    func waitForReadiness(pairDoc: DocumentReference) {
        pairDoc.addSnapshotListener { docSnapshot, _ in
            guard let data = docSnapshot?.data(),
                  let doer = data["doer"] as? String,
                  let recipient = data["recipient"] as? String,
                  doer != "waiting", recipient != "waiting" else {
                return
            }

            pairing = (doer, recipient)
            isWaitingForPair = false

            if let existing = data["suggestedAction"] as? String, !existing.isEmpty {
                self.proposedAction = existing
            } else {
                generateSuggestion()
            }
            
            // Ensure acceptance fields exist
            if data["doerAccepted"] == nil || data["recipientAccepted"] == nil {
                pairDoc.updateData([
                    "doerAccepted": data["doerAccepted"] as? Bool ?? false,
                    "recipientAccepted": data["recipientAccepted"] as? Bool ?? false
                ])
            }

            if let doerAgreed = data["doerAccepted"] as? Bool {
                self.doerAccepted = doerAgreed
            }
            if let recipientAgreed = data["recipientAccepted"] as? Bool {
                self.recipientAccepted = recipientAgreed
            }
        }
    }

    func generateSuggestion() {
        loading = true

        let suggestions = [
                "Give a compliment and buy a small treat for the other person.",
                "Write a short, kind note and leave it somewhere for them to find.",
                "Offer to carry something heavy or help with a small chore.",
                "Draw something meaningful for the other person.",
                "Prepare a surprise snack or drink they might enjoy.",
                "Tell them something you genuinely admire about them.",
                "Offer to listen without interrupting for 5 minutes.",
                "Give them a small handmade item (origami, bracelet, etc.).",
                "Find a photo of a shared memory and write a message about it.",
                "Teach them something useful in less than 2 minutes."
            ]

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let suggestion = suggestions.randomElement() ?? "Do something thoughtful and unexpected."
            self.proposedAction = suggestion
            self.loading = false

            pairDocRef?.updateData(["suggestedAction": suggestion])
        }
    }


    func allocatePoints() {
        let db = Firestore.firestore()
        let doerPoints = 60
        let recipientPoints = 40

        if let doer = pairing?.doerId, let recipient = pairing?.recipientId {
            db.collection("users").document(doer).updateData([
                "points": FieldValue.increment(Int64(doerPoints))
            ])
            db.collection("users").document(recipient).updateData([
                "points": FieldValue.increment(Int64(recipientPoints))
            ])
        }
    }
}
