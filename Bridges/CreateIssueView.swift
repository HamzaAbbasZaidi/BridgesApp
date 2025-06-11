//
//  CreateIssueView.swift
//  Bridges
//
//  Created by Hamza Zaidi on 11/06/2025.
//


import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct CreateIssueView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var isSubmitting = false

    // Used to notify MainTopicsView of the new issue
    var onSubmit: (Issue) -> Void

    var body: some View {
        ZStack {
            Color(red: 0.9, green: 0.95, blue: 1.0)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Create a New Topic")
                    .font(.largeTitle.bold())
                    .foregroundColor(.blue)

                TextField("Enter topic title", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                TextField("Enter topic description", text: $description, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(4...6)
                    .padding(.horizontal)

                if isSubmitting {
                    ProgressView()
                } else {
                    Button("Submit") {
                        submitIssue()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
        }
    }

    func submitIssue() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard !title.isEmpty, !description.isEmpty else { return }

        isSubmitting = true
        let db = Firestore.firestore()
        let category = "Sport" // default category for now; can be dynamic if needed

        let newDoc = db.collection("categories").document(category.lowercased())
            .collection("issues").document()

        let issue = Issue(
            id: newDoc.documentID,
            title: title,
            description: description,
            activityScore: 0,
            category: category
        )

        do {
            try newDoc.setData(from: issue) { error in
                isSubmitting = false
                if error == nil {
                    onSubmit(issue)
                    dismiss()
                } else {
                    print("❌ Failed to save new topic: \(error!.localizedDescription)")
                }
            }
        } catch {
            isSubmitting = false
            print("❌ Encoding error: \(error.localizedDescription)")
        }
    }
}
