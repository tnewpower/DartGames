//
//  SplashGate.swift
//  Dart Games
//
//  Created by Tony Newpower on 8/19/25.
//


import SwiftUI

struct SplashGate: View {
    @State private var showSplash = true
    var body: some View {
        ZStack {
            DashboardView().opacity(showSplash ? 0 : 1)
            if showSplash {
                ZStack {
                    LinearGradient(colors: [.cyan, .indigo], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                    Image("LaunchLogoLight")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            // match launch screen background for a seamless look
            LinearGradient(colors: [Color(red:0.06, green:0.65, blue:0.91),
                                    Color(red:0.14, green:0.39, blue:0.92)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 180)
                .shadow(radius: 8, y: 4)
        }
    }
}
