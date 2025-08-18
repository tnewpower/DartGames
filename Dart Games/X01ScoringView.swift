import SwiftUI
import SwiftData

struct X01ScoringView: View {
    @Environment(\.modelContext) private var context
    @State var match: Match
    @State var leg: Leg

    // turn state
    @State private var currentPlayerIndex: Int = 0
    @State private var darts: [Dart] = []
    @State private var message: String?

    private var players: [Player] { match.players }
    private var engine: X01Engine { .init(starting: match.startingScore ?? 501, doubleOut: match.doubleOut) }
    private var currentPlayer: Player { players[currentPlayerIndex] }
    private var remaining: Int { leg.remainingByPlayer[currentPlayer.id] ?? (match.startingScore ?? 501) }

    var body: some View {
        VStack(spacing: 16) {
            header

            VStack(spacing: 8) {
                ForEach(players) { p in
                    let rem = leg.remainingByPlayer[p.id] ?? (match.startingScore ?? 501)
                    HStack {
                        Text(p.name).bold()
                        Spacer()
                        Text("\(rem)")
                            .monospacedDigit()
                            .font(.title3)
                            .foregroundStyle(p.id == currentPlayer.id ? .primary : .secondary)
                    }
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            DartPad(darts: $darts)

            HStack {
                Button("Undo Turn") { undoTurn() }.disabled(leg.turns.isEmpty)
                Spacer()
                Button("Enter") { submitTurn() }
                    .buttonStyle(.borderedProminent)
                    .disabled(darts.isEmpty || (darts.count > 3))
            }

            if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("\(match.gameType.displayName)")
        .onAppear {
            // Resume position if needed
            if let last = leg.turns.last, let idx = players.firstIndex(where: { $0.id == last.player.id }) {
                currentPlayerIndex = (idx + 1) % players.count
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Leg \(leg.index)").font(.headline)
            Text("Current: \(currentPlayer.name) — Remaining \(remaining)").font(.subheadline)
        }
    }

    private func submitTurn() {
        let result = engine.apply(turnDarts: darts, currentRemaining: remaining)

        if result.bust {
            // record a bust (score 0)
            let t = Turn(player: currentPlayer, darts: darts, total: 0, bust: true)
            leg.turns.append(t)
            darts.removeAll()
            message = "Bust! No score."
            advancePlayer()
        } else {
            let scored = darts.reduce(0) { $0 + $1.value }
            leg.remainingByPlayer[currentPlayer.id] = result.newRemaining
            let t = Turn(player: currentPlayer, darts: darts, total: scored, bust: false)
            leg.turns.append(t)
            darts.removeAll()
            message = "Scored \(scored)"
            if result.newRemaining == 0 {
                leg.winner = currentPlayer
                message = "Leg won by \(currentPlayer.name)!"
            } else {
                advancePlayer()
            }
        }
        try? context.save()
    }

    private func advancePlayer() {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
    }

    private func undoTurn() {
        guard let last = leg.turns.popLast() else { return }
        // Restore remaining if not a bust
        if !last.bust {
            let prior = (leg.remainingByPlayer[last.player.id] ?? 0) + last.total
            leg.remainingByPlayer[last.player.id] = prior
        }
        darts.removeAll()
        leg.winner = nil
        // set current player back to the one who just played
        if let idx = players.firstIndex(where: { $0.id == last.player.id }) {
            currentPlayerIndex = idx
        }
        message = "Undid last turn."
        try? context.save()
    }
}

/// Simple pad with common segments; tap fills up to 3 darts.
struct DartPad: View {
    @Binding var darts: [Dart]

    private let rows: [[(Int, Int)]] = [
        [(20,3),(20,2),(20,1)],
        [(19,3),(19,2),(19,1)],
        [(18,3),(18,2),(18,1)],
        [(17,3),(17,2),(17,1)],
        [(16,3),(16,2),(16,1)],
        [(15,3),(15,2),(15,1)],
        [(25,2),(25,1),(50,1)] // D25 (counts as 50), single 25, bull 50
    ]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Darts: \(darts.map{$0.value}.map(String.init).joined(separator: " + "))")
                    .monospacedDigit()
                Spacer()
                Button("Clear") { darts.removeAll() }.disabled(darts.isEmpty)
            }

            ForEach(0..<rows.count, id: \.self) { r in
                HStack {
                    ForEach(0..<rows[r].count, id: \.self) { c in
                        let (seg, mul) = rows[r][c]
                        Button(label(seg: seg, mul: mul)) {
                            guard darts.count < 3 else { return }
                            // Normalize "D25" to bull (50): seg=25,mul=2 => 50, okay.
                            darts.append(Dart(segment: seg, multiplier: mul))
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func label(seg: Int, mul: Int) -> String {
        if seg == 50 && mul == 1 { return "Bull (50)" }
        if seg == 25 && mul == 2 { return "D-Bull (50)" }
        let prefix = (mul == 3 ? "T" : (mul == 2 ? "D" : "S"))
        return "\(prefix)\(seg)"
    }
}
