//
//  Dart_GamesApp.swift
//  Dart Games
//
//  Created by Tony Newpower on 8/18/25.
//

import SwiftUI
import SwiftData

@main
struct Dart_GamesApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
        .modelContainer(for: [Player.self, Match.self, Leg.self, Turn.self, Dart.self])
    }
}
