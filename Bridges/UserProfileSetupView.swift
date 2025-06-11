//
//  UserProfileSetupView.swift
//  Bridges
//
//  Created by Hamza Zaidi on 03/06/2025.
//


import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct UserProfileSetupView: View {
    @State private var firstName: String = ""
    @State private var gender: String = "Prefer not to say"
    @State private var activityLevel: Int = 3
    @State private var isSaving = false
    @State private var navigateToCategoryList = false
    @State private var ageGroup: String = "16–25"


    let genderOptions = ["Male", "Female", "Non-binary", "Prefer not to say"]

    var body: some View {
        ZStack {
            Color(red: 0.9, green: 0.95, blue: 1.0)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    Text("Tell us a bit about yourself")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. What's your first name?")
                        TextField("Enter your name", text: $firstName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("2. What is your gender?")
                        Picker("Gender", selection: $gender) {
                            ForEach(genderOptions, id: \.self) {
                                Text($0)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("3. How active are you physically?")
                        Slider(value: Binding(
                            get: { Double(activityLevel) },
                            set: { activityLevel = Int($0) }
                        ), in: 1...5, step: 1)
                        Text("Activity level: \(activityLevel)/5").font(.caption)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("4. What is your age group?")
                        Picker("Age Group", selection: $ageGroup) {
                            Text("16–25").tag("16–25")
                            Text("26–40").tag("26–40")
                            Text("40+").tag("40+")
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    
                    Button(action: saveProfile) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Continue")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.top)
                    
                    NavigationLink(destination: CategoryListView(), isActive: $navigateToCategoryList) {
                        EmptyView()
                    }
                }
                .padding()
            }
            .navigationTitle("Profile Setup")
        }
    }

    func saveProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isSaving = true

        let db = Firestore.firestore()
        db.collection("users").document(uid).setData([
            "profile": [
                "firstName": firstName,
                "gender": gender,
                "activityLevel": activityLevel,
                "ageGroup": ageGroup
            ],
            "profileCompleted": true
        ], merge: true) { error in
            isSaving = false
            if error == nil {
                navigateToCategoryList = true
            } else {
                print("❌ Error saving profile: \(error!.localizedDescription)")
            }
        }
    }
}
