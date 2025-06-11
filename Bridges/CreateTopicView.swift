//
//  CreateTopicView.swift
//  Bridges
//
//  Created by Hamza Zaidi on 10/06/2025.
//


import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct CreateTopicView: View {
    let category: String
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Create a New Topic in \(category.capitalized)")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            TextField("Topic title", text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextEditor(text: $description)
                .frame(height: 120)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5)))
                .padding(.horizontal, 2)

            if isSaving {
                ProgressView()
            } else {
                Button("Create Topic (+50 points)") {
                    createTopic()
                }
                .disabled(title.isEmpty || description.isEmpty)
                .bold()
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.85))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
    }

    // REVERT to this simplified version:
    func createTopic() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isSaving = true

        let db = Firestore.firestore()
        let issuesRef = db.collection("categories").document(category.lowercased()).collection("issues")
        
        let newTopic = [
            "title": title,
            "description": description,
            "activityScore": 0
        ] as [String : Any]
        
        issuesRef.addDocument(data: newTopic) { error in
            DispatchQueue.main.async {
                if error == nil {
                    let userRef = db.collection("users").document(uid)
                    userRef.updateData(["points": FieldValue.increment(Int64(50))])
                    dismiss() // Simple dismiss without notifications
                }
                isSaving = false
            }
        }
    }

}
