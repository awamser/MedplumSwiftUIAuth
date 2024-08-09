//
//  LoginView.swift
//  MedplumSwiftUIAuth
//
//  Created by alan on 8/2/24.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack {
            Text("Medplum OAuth Demo")
                .font(.title)
                .padding()
            Button(action: {
                authViewModel.login()
            }) {
                Text("Login with Medplum")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        
    }
}

#Preview {
    LoginView(authViewModel: AuthViewModel())
}
