import SwiftUI
import SwiftData

struct BaseballScoringView: View {
    @Environment(\.modelContext) private var context

    // Passed in by the loader
    @State var match: Match
    @State var leg: Leg

    // Ephemeral input for the current turn (0–3 “hits”)
    @State private var darts: [Dart] = []
    @State private var message: String?

    private var players: [Player] { match.players }
    private var pCount: Int { players.count }

    // Derived from existing turns (so resume works)
    private var turnsSoFar: Int { leg.turns.count }
    private var currentInning: Int {
        min(9, 1 + turnsSoFar / max(pCount, 1))
    }
    private var currentPlayerIndex: Int {
        pCount == 0 ? 0 : (turnsSoFar % pCount)
    }
    private var currentPlayer: Player {
        players[currentPlayerIndex]
    }

    // Totals per player
    private var totalsByPlayer: [UUID: Int] {
        var map: [UUID: Int] = [:]
        for t in leg.turns {
            map[t.player.id, default: 0] += t.total
        }
        return map
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            // Scoreboard (totals so far)
            VStack(spacing: 8) {
                ForEach(players) { p in
                    HStack {
                        Text(p.name)
                            .fontWeight(p.id == currentPlayer.id ? .bold : .regular)
                        Spacer()
                        Text("\(totalsByPlayer[p.id, default: 0])")
                            .monospacedDigit()
                            .font(.title3)
                            .foregroundStyle(p.id == currentPlayer.id ? .primary : .secondary)
                    }
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            BaseballHitPad(inning: currentInning, darts: $darts)

            HStack {
                Button("Undo Turn") { undoTurn() }
                    .disabled(leg.turns.isEmpty)
                Spacer()
                Button("Enter") { submitTurn() }
                    .buttonStyle(.borderedProminent)
                    .disabled(darts.isEmpty || darts.count > 3 || legIsOver)
            }

            if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Baseball")
        .onAppear {
            // If we already finished (resume case), ensure winner is set and UI reflects it
            if leg.turns.count >= (9 * max(pCount, 1)) {
                finalizeWinnerIfNeeded()
            }
        }
    }

    private var legIsOver: Bool {
        leg.turns.count >= (9 * max(pCount, 1)) || leg.winner != nil
    }

    private var header: some View {
        VStack(spacing: 4) {
            if let w = leg.winner {
                Text("Game Over").font(.headline)
                Text("Winner: \(w.name)").font(.subheadline)
            } else {
                Text("Inning \(currentInning) of 9").font(.headline)
                Text("At dart: \(currentPlayer.name)").font(.subheadline)
            }
        }
    }

    // MARK: - Actions

    private func submitTurn() {
        guard !legIsOver else { return }

        // In Baseball: single=1, double=2, triple=3 regardless of inning number
        let points = darts.reduce(0) { $0 + $1.multiplier }   // ignore Dart.value for Baseball

        let t = Turn(player: currentPlayer, darts: darts, total: points, bust: false)
        leg.turns.append(t)
        darts.removeAll()

        message = "Scored \(points) point\(points == 1 ? "" : "s")"
        try? context.save()

        // If we just finished the last player of the 9th inning, finalize
        if leg.turns.count >= (9 * max(pCount, 1)) {
            finalizeWinnerIfNeeded()
        }
    }

    private func finalizeWinnerIfNeeded() {
        // Highest total wins (simple rules; you can add tie-breakers later)
        var best: (Player, Int)? = nil
        for p in players {
            let total = totalsByPlayer[p.id, default: 0]
            if best == nil || total > best!.1 {
                best = (p, total)
            }
        }
        if let winner = best?.0 {
            leg.winner = winner
            message = "Game over — \(winner.name) wins!"
            try? context.save()
        }
    }

    private func undoTurn() {
        guard let last = leg.turns.popLast() else { return }
        darts.removeAll()
        message = "Undid \(last.player.name)’s last turn."
        leg.winner = nil
        try? context.save()
    }
}

// MARK: - Simple S/D/T input for current inning
private struct BaseballHitPad: View {
    let inning: Int
    @Binding var darts: [Dart]   // we’ll store S/D/T as Dart(multiplier: 1/2/3); segment=inning

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Inning \(inning) — Darts: \(darts.map { label(for: $0) }.joined(separator: "  "))")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
                Button("Clear") { darts.removeAll() }
                    .disabled(darts.isEmpty)
            }
            HStack {
                Button("Single") { add(multiplier: 1) }
                Button("Double") { add(multiplier: 2) }
                Button("Triple") { add(multiplier: 3) }
                Button("Miss")  { add(multiplier: 0) }
            }
            .buttonStyle(.bordered)
        }
    }

    private func add(multiplier: Int) {
        guard darts.count < 3 else { return }
        // segment stored as inning; value is unused by Baseball scoring logic
        let seg = multiplier == 0 ? 0 : inning
        let m   = multiplier == 0 ? 0 : multiplier
        darts.append(Dart(segment: seg, multiplier: m))
    }

    private func label(for d: Dart) -> String {
        switch d.multiplier {
        case 0: return "M"
        case 1: return "S"
        case 2: return "D"
        case 3: return "T"
        default: return "?"
        }
    }
}
