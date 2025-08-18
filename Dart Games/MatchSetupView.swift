import SwiftUI
import SwiftData

struct MatchSetupView: View {
    let gameType: GameType
    @Environment(\.modelContext) private var context
    @Query private var players: [Player]

    @State private var selectedPlayers: Set<Player> = []
    @State private var doubleOut: Bool = true
    private var startingScore: Int? {
        switch gameType {
        case .x01_301: return 301
        case .x01_501: return 501
        default: return nil
        }
    }

    @State private var newPlayerName = ""

    var body: some View {
        Form {
            Section("Players") {
                if players.isEmpty {
                    Text("No players yet. Add one below.")
                        .foregroundStyle(.secondary)
                }
                ForEach(players) { p in
                    MultipleSelectionRow(title: p.name, isSelected: selectedPlayers.contains(p)) {
                        if selectedPlayers.contains(p) { selectedPlayers.remove(p) }
                        else { selectedPlayers.insert(p) }
                    }
                }
                HStack {
                    TextField("Add player name", text: $newPlayerName)
                    Button("Add") {
                        let p = Player(name: newPlayerName.trimmingCharacters(in: .whitespaces))
                        guard !p.name.isEmpty else { return }
                        context.insert(p)
                        try? context.save()
                        newPlayerName = ""
                    }
                }
            }

            if case .x01_301 = gameType { X01SettingsRow(title: "Starting", value: "301") }
            if case .x01_501 = gameType { X01SettingsRow(title: "Starting", value: "501") }

            if gameType == .x01_301 || gameType == .x01_501 {
                Toggle("Double Out", isOn: $doubleOut)
            }

            Section {
                NavigationLink("Start \(gameType.displayName)") {
                    startMatchView()
                }
                .disabled(selectedPlayers.count < 2)
            }
        }
        .navigationTitle(gameType.displayName)
    }

    @ViewBuilder
    private func startMatchView() -> some View {
        let orderedPlayers = Array(selectedPlayers)
        let match = Match(gameType: gameType,
                          players: orderedPlayers,
                          startingScore: startingScore,
                          doubleOut: doubleOut)
        context.insert(match)
        let leg = Leg(index: 1, players: orderedPlayers, startingScore: startingScore)
        match.legs.append(leg)
        try? context.save()

        switch gameType {
        case .x01_301, .x01_501:
            X01ScoringView(match: match, leg: leg)
        default:
            Text("Scoring UI for \(gameType.displayName) coming next.")
        }
    }
}

struct MultipleSelectionRow: View {
    let title: String
    var isSelected: Bool
    var onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(title)
                Spacer()
                if isSelected { Image(systemName: "checkmark") }
            }
        }
    }
}

struct X01SettingsRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
