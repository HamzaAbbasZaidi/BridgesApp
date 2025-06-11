//
//  ChatView.swift
//  Bridges
//
//  Created by Hamza Zaidi on 19/05/2025.
//


import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct ChatView: View {
    let category: String
    let issueId: String
    let actionId: String

    @State private var messages: [ChatMessage] = []
    @State private var newMessage = ""
    @State private var listener: ListenerRegistration?
    let uid = Auth.auth().currentUser?.uid
    let username = Auth.auth().currentUser?.displayName ?? "Anonymous"

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            HStack {
                                if message.senderId == uid {
                                    Spacer()
                                }

                                VStack(alignment: .leading) {
                                    Text(message.senderName)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(message.text)
                                        .padding(8)
                                        .background(message.senderId == uid ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                                        .cornerRadius(8)
                                }

                                if message.senderId != uid {
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            HStack {
                TextField("Type a message...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Send") {
                    sendMessage()
                }
            }
            .padding()
        }
        .onAppear {
            listenForMessages()
        }
        .onDisappear {
            listener?.remove()
        }
    }

    func listenForMessages() {
        let db = Firestore.firestore()
        listener = db.collection("categories").document(category)
            .collection("issues").document(issueId)
            .collection("action").document(actionId)
            .collection("chat")
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                self.messages = docs.compactMap { try? $0.data(as: ChatMessage.self) }
            }
    }

    func sendMessage() {
        guard !newMessage.trimmingCharacters(in: .whitespaces).isEmpty,
              let uid = uid else { return }

        let db = Firestore.firestore()
        let ref = db.collection("categories").document(category)
            .collection("issues").document(issueId)
            .collection("action").document(actionId)
            .collection("chat").document()

        let message = ChatMessage(
            id: ref.documentID,
            text: newMessage,
            senderId: uid,
            senderName: username,
            timestamp: Date()
        )

        do {
            try ref.setData(from: message)
            newMessage = ""
        } catch {
            print("Error sending message: \(error.localizedDescription)")
        }
    }
}
