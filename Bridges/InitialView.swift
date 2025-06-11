//
//  InitialView.swift
//  Bridges
//
//  Created by Hamza Zaidi on 28/03/2025.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

enum OnboardingStep {
    case profile
    case issueSelection
    case done
}

struct InitialView: View {
    @State private var isLoading = true
    @State private var isLoggedIn = false
    @State private var profileCompleted = false
    @State private var hasCompletedOnboarding = false
    @State private var onboardingStep: OnboardingStep = .profile


    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if !isLoggedIn {
                LoginView()
            } else {
                NavigationStack {
                    switch onboardingStep {
                    case .profile:
                        UserProfileSetupView()
                    case .issueSelection:
                        CategoryListView()
                    case .done:
                        MainTopicsView()
                    }
                }
            }
        }
    


        .onAppear {
            Auth.auth().addStateDidChangeListener { _, user in
                if let user = user {
                    isLoggedIn = true
                    fetchOnboardingStatus(for: user.uid)
                } else {
                    isLoggedIn = false
                    isLoading = false
                }
            }
        }
    }

    private func fetchOnboardingStatus(for uid: String) {
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(uid)

        docRef.getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                let profileDone = data?["profileCompleted"] as? Bool ?? false
                let onboardingDone = data?["hasCompletedOnboarding"] as? Bool ?? false

                if !profileDone {
                    onboardingStep = .profile
                } else if !onboardingDone {
                    onboardingStep = .issueSelection
                } else {
                    onboardingStep = .done
                }
            } else {
                onboardingStep = .profile
            }
            isLoading = false
        }
    }


}



