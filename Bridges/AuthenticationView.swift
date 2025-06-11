//
//  AuthenticationView.swift
//  Bridges
//
//  Created by Hamza Zaidi on 29/03/2025.
//

import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn
import FirebaseFirestore

class AuthenticationView: ObservableObject{
    
    @Published var isLoginSuccessed = false
    
    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {return}
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: Application_utility.rootViewController) { user, error in
            
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            guard
                let user = user?.user,
                let idToken = user.idToken else { return }
            
            let accessToken = user.accessToken
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken.tokenString, accessToken: accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) { res, error in
                if let error = error{
                    print(error.localizedDescription)
                    return
                }
                guard let user = res?.user else { return }
                print(user)
                
                let db = Firestore.firestore()
                let userRef = db.collection("users").document(user.uid)

                userRef.setData([
                    "uid": user.uid,
                    "name": user.displayName ?? "No Name",
                    "email": user.email ?? "No Email"
                ], merge: true) { error in
                    if let error = error {
                        print("Error saving user data: \(error.localizedDescription)")
                    } else {
                        print("User data saved to Firestore.")
                    }
                }
                
            }
        }
        
    }
    
    func logout() async throws{
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }
    
}

