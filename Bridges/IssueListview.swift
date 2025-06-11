//
//  IssueListview.swift
//  Bridges
//
//  Created by Hamza Zaidi on 06/05/2025.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct IssueListView: View {
    let category: String
    @State private var issues: [String] = []
    @State private var selected: Set<String> = []
    @State private var navigateToMainTopics = false

    var body: some View {
        ZStack {
            Color(red: 0.9, green: 0.95, blue: 1.0)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("\(category.capitalized) Bridges")
                        .font(.largeTitle.bold())
                        .foregroundColor(.blue)

                    Text("Pick one or more topics within \(category.lowercased()) that interest you. These are areas where people often disagree — and we’re helping build bridges with small, kind actions.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.blue.opacity(0.8))
                        .padding(.horizontal)
                }
                .padding(.top)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(issues, id: \.self) { issue in
                            Button(action: {
                                toggleSelection(issue)
                            }) {
                                HStack {
                                    Text(issue)
                                        .fontWeight(.medium)
                                    Spacer()
                                    if selected.contains(issue) {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                }
                                .padding()
                                .background(Color.blue.opacity(0.85))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }

                        NavigationLink(destination: CreateTopicView(category: category)) {
                            Text("Create a \(category.lowercased()) topic of your own! (+50 points)")
                                .fontWeight(.medium)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green.opacity(0.85))
                                .foregroundColor(.black)
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }
                }

                Text("Placeholder text")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.9))
                    .foregroundColor(.white)
                    .font(.footnote)

                NavigationLink(destination: MainTopicsView(),
                               isActive: $navigateToMainTopics) {
                    EmptyView()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchIssues()
        }
        .toolbar {
            Button("Save") {
                saveSelection()
            }
        }
        .onDisappear {
            saveSelection()
        }
    }


    func fetchIssues() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let issuesRef = db.collection("categories").document(category.lowercased()).collection("issues")
        let userDoc = db.collection("users").document(uid)

        issuesRef.getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("❌ Failed to load issues for category \(category.lowercased())")
                return
            }

            let titles = documents.compactMap { $0.data()["title"] as? String }
            self.issues = titles

            // Fetch previously selected issues
            userDoc.getDocument { userSnapshot, _ in
                if let data = userSnapshot?.data(),
                   let selected = data["selectedIssues"] as? [String] {
                    self.selected = Set(selected)
                }
            }
        }
    }






    func saveSelection() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(uid).setData([
            "selectedIssues": Array(selected),
            "hasCompletedOnboarding": true
        ], merge: true) { error in
            if error == nil {
                navigateToMainTopics = true
            }
        }
    }

    func toggleSelection(_ issue: String) {
        if selected.contains(issue) {
            selected.remove(issue)
        } else {
            selected.insert(issue)
        }
    }
}
