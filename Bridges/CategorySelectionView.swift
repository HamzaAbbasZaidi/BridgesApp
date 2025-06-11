//
//  CategorySelectionView.swift
//  Bridges
//
//  Created by Hamza Zaidi on 06/05/2025.
//


import SwiftUI

struct CategorySelectionView: View {
    let categories = ["Sport", "Regional", "Politics", "Faith"]
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Welcome to Bridges.")
                    .font(.largeTitle.bold())
                Text("Join an issue that resonates...") // etc.

                ForEach(categories, id: \.self) { category in
                    NavigationLink(destination: IssueListView(category: category)) {
                        Text(category)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.black)
                            .cornerRadius(10)
                    }
                }

                Button("See full list of topics") { /* navigate */ }
                Button("Create a topic of your own!") { /* navigate */ }
            }
            .padding()
        }
    }
}


