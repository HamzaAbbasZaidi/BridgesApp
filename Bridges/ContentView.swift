//
//  ContentView.swift
//  Bridges
//
//  Created by Hamza Zaidi on 11/03/2025.
//

import SwiftUI
import Firebase

struct ContentView: View {
    @State private var err : String = ""
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            
            Button{
                Task{
                    do{
                        try await AuthenticationView().logout()
                    } catch let e {
                        
                        err = e.localizedDescription
                    }
                }
                } label: {
                    Text("Logout").padding(8)
                }.buttonStyle(.borderedProminent)
                
                Text(err).foregroundColor(.red).font(.caption)
                }
            
        
        .padding()
    }
}

#Preview {
    ContentView()
}
