//
//  ContentView.swift
//  MedplumSwiftUIAuth
//
//  Created by alan on 8/1/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        if authViewModel.isAuthenticated {
            VStack {
                Text("You're logged in.")
                    .font(.title)
                    .padding()
                
                Text("Access Token: \(authViewModel.accessToken ?? "N/A")")
                    .padding()
                    .blur(radius: 5)
                
                Button(action: {
                    authViewModel.logout()
                }) {
                    Text("Logout")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            
        } else {
            LoginView(authViewModel: authViewModel)
        }
    }
}

#Preview {
    ContentView()
}
