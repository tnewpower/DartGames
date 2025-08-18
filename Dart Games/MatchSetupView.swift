//
//  MatchSetupView.swift
//  Dart Games
//
//  Created by Tony Newpower on 8/18/25.
//


import SwiftUI
import SwiftData

// MARK: - Lightweight route (stable for navigation)
enum MatchRoute: Hashable, Identifiable {
    case x01(UUID)
    case baseball(UUID)
    case aroundTheWorld(UUID)
    case cricket(UUID)

    var id: String {
        switch self {
        case .x01(let id):            return "x01-\(id.uuidString)"
        case .baseball(let id):       return "bb-\(id.uuidString)"
        case .aroundTheWorld(let id): return "atw-\(id.uuidString)"
        case .cricket(let id):        return "ck-\(id.uuidString)"
        }
    }
}

// MARK: - Match Setup
struct MatchSetupView: View {
    let gameType: GameType

    @Environment(\.modelContext) private var context
    @Query(sort: \Player.createdAt, order: .forward) private var players: [Player]

    @State private var selectedPlayerIDs: Set<UUID> = []
    @State private var newPlayerName: String = ""
    @State private var route: MatchRoute? = nil
    @State private var doubleOut: Bool = true
    @FocusState private var nameFieldFocused: Bool

    private var startingScore: Int? {
        switch gameType {
        case .x01_301: return 301
        case .x01_501: return 501
        default:       return nil
        }
    }

    var body: some View {
        Form {
            playersSection
            if startingScore != nil { x01OptionsSection }
            rulesSection
            startSection
        }
        .navigationTitle(gameType.displayName)
        .navigationDestination(item: $route) { route in
            switch route {
            case .x01(let id):
                X01LoaderView(matchID: id)
            case .baseball(let id):
                BaseballLoaderView(matchID: id)
            case .aroundTheWorld(let id):
                AroundTheWorldLoaderView(matchID: id)   
            case .cricket(let id):
                CricketPlaceholderView(matchID: id)          // stub for now
            }
        }

    }

    // MARK: Sections

    private var playersSection: some View {
        Section("Players") {
            if players.isEmpty {
                Text("No players yet. Add one below.")
                    .foregroundStyle(.secondary)
            }

            ForEach(players) { p in
                Toggle(p.name, isOn: selectionBinding(for: p.id))
            }

            HStack {
                TextField("Add player name", text: $newPlayerName)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { addPlayer() }
                Button("Add") { addPlayer() }
                    .disabled(newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var x01OptionsSection: some View {
        Section("X01 Options") {
            HStack {
                Text("Starting")
                Spacer()
                Text("\(startingScore!)").foregroundStyle(.secondary)
            }
            Toggle("Double Out", isOn: $doubleOut)
        }
    }

    private var startSection: some View {
        Section {
            Button("Start \(gameType.displayName)") { startMatch() }
                .disabled(selectedPlayerIDs.count < 2)
        }
    }
    
    private var rulesSection: some View {
        Section("Rules & Tips") {
            NavigationLink {
                RulesView(gameType: gameType)
            } label: {
                Label("\(gameType.displayName) rules", systemImage: "book")
            }
        }
    }


    // MARK: Helpers

    private func selectionBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedPlayerIDs.contains(id) },
            set: { isOn in
                if isOn { selectedPlayerIDs.insert(id) }
                else    { selectedPlayerIDs.remove(id) }
            }
        )
    }

    private func addPlayer() {
        let name = newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let p = Player(name: name)
        context.insert(p)
        try? context.save()

        // auto-select newly added player so Start enables after two adds
        selectedPlayerIDs.insert(p.id)
        newPlayerName = ""
        nameFieldFocused = true
    }

    private func startMatch() {
        let chosen = players.filter { selectedPlayerIDs.contains($0.id) }
        guard chosen.count >= 2 else { return }

        let match = Match(gameType: gameType,
                          players: chosen,
                          startingScore: startingScore,
                          doubleOut: doubleOut)
        context.insert(match)
        let leg = Leg(index: 1, players: chosen, startingScore: startingScore)
        match.legs.append(leg)
        try? context.save()

        switch gameType {
        case .x01_301, .x01_501:
            route = .x01(match.id)
        case .baseball:
            route = .baseball(match.id)
        case .aroundTheWorld:
            route = .aroundTheWorld(match.id)
        case .cricket:
            route = .cricket(match.id)
        }
    }
}



// MARK: - Loader / Placeholder

struct X01LoaderView: View {
    @Environment(\.modelContext) private var context
    let matchID: UUID

    var body: some View {
        if let match = try? context.fetch(
            FetchDescriptor<Match>(predicate: #Predicate { $0.id == matchID })
        ).first, let leg = match.legs.last {
            X01ScoringView(match: match, leg: leg)
        } else {
            Text("Match not found.")
                .foregroundStyle(.secondary)
        }
    }
}

struct BaseballLoaderView: View {
    @Environment(\.modelContext) private var context
    let matchID: UUID

    var body: some View {
        if let match = try? context.fetch(
            FetchDescriptor<Match>(predicate: #Predicate { $0.id == matchID })
        ).first,
           let leg = match.legs.last {
            BaseballScoringView(match: match, leg: leg)
        } else {
            Text("Match not found.")
                .foregroundStyle(.secondary)
        }
    }
}

struct AroundTheWorldLoaderView: View {
    @Environment(\.modelContext) private var context
    let matchID: UUID

    var body: some View {
        if let match = try? context.fetch(
            FetchDescriptor<Match>(predicate: #Predicate { $0.id == matchID })
        ).first, let leg = match.legs.last {
            AroundTheWorldScoringView(match: match, leg: leg)
        } else {
            Text("Match not found.")
                .foregroundStyle(.secondary)
        }
    }
}

struct CricketPlaceholderView: View {
    let matchID: UUID
    var body: some View {
        VStack(spacing: 12) {
            Text("Cricket scoring coming next.")
            Text("Match \(matchID.uuidString.prefix(8))…")
                .foregroundStyle(.secondary).font(.footnote)
        }.padding()
    }
}


