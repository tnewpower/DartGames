//
//  DashboardView.swift
//  Dart Games
//
//  Created by Tony Newpower on 8/18/25.
//


import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Match.createdAt, order: .reverse) private var recentMatches: [Match]

    private let tiles: [GameType] = [.x01_301, .x01_501, .baseball, .cricket, .aroundTheWorld]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Darts Hub").font(.largeTitle.bold())

                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 16) {
                        ForEach(tiles) { type in
                            NavigationLink {
                                MatchSetupView(gameType: type)
                            } label: {
                                GameTile(title: type.displayName)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())    
                        }
                    }

                    if !recentMatches.isEmpty {
                        Text("Recently Played").font(.title3.bold())
                        ForEach(recentMatches.prefix(5)) { match in
                            NavigationLink {
                                ResumeMatchView(match: match)
                            } label: {
                                HStack {
                                    Text(match.gameType.displayName)
                                    Spacer()
                                    Text(match.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct GameTile: View {
    let title: String
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(.thinMaterial)
            VStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 30, weight: .semibold))
                Text(title).font(.headline)
            }.padding(16)
        }.frame(height: 110)
    }
}
