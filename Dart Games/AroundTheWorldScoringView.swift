//
//  AroundTheWorldScoringView.swift
//  Dart Games
//
//  Created by Tony Newpower on 8/18/25.
//


import SwiftUI
import SwiftData

struct AroundTheWorldScoringView: View {
    @Environment(\.modelContext) private var context

    // Passed in by the loader
    @State var match: Match
    @State var leg: Leg

    // Turn input (max 3 darts)
    @State private var darts: [Dart] = []
    @State private var currentMult: Int = 1 // 1=S, 2=D, 3=T
    @State private var message: String?

    // You can change this to 21 if you later add Bull as a target
    private let lastTarget = 20

    // Use frozen order for stability
    private var playersOrdered: [Player] {
        let map = Dictionary(uniqueKeysWithValues: match.players.map { ($0.id, $0) })
        let ordered = match.playerOrder.compactMap { map[$0] }
        return ordered.isEmpty ? match.players : ordered
    }
    private var pCount: Int { playersOrdered.count }

    // Turn index → who’s up / inning
    private var turnsSoFar: Int { leg.turns.count }
    private var currentPlayerIndex: Int { pCount == 0 ? 0 : (turnsSoFar % pCount) }
    private var currentPlayer: Player { playersOrdered[currentPlayerIndex] }
    private var legIsOver: Bool { leg.winner != nil || progressSummary.winnerFound }

    // --- Progress computation (pure, deterministic) ---

    // Sort turns by our explicit sequence (added earlier)
    private var sortedTurns: [Turn] {
        leg.turns.sorted { a, b in
            if a.sequence != b.sequence { return a.sequence < b.sequence }
            return a.createdAt < b.createdAt
        }
    }

    // For each player, compute next target (1...lastTarget+1) and how far they’ve advanced
    private var progressSummary: (nextByPlayer: [UUID:Int], winnerFound: Bool) {
        var next: [UUID:Int] = [:]                 // next target to hit for each player
        for p in playersOrdered { next[p.id] = 1 } // everyone starts at 1

        for turn in sortedTurns {
            guard var n = next[turn.player.id], n <= lastTarget else { continue }
            // Process darts in order they were thrown
            for d in turn.darts {
                if d.segment == n { n += 1 }       // only the current number advances
                if n > lastTarget { break }
            }
            next[turn.player.id] = n
        }

        let someoneFinished = next.values.contains(where: { $0 > lastTarget })
        return (next, someoneFinished)
    }

    private func nextTarget(for player: Player) -> Int {
        progressSummary.nextByPlayer[player.id] ?? 1
    }

    private func advancementsFrom(darts: [Dart], startingAt n: Int) -> Int {
        var next = n
        var adv = 0
        for d in darts where next <= lastTarget {
            if d.segment == next {
                next += 1
                adv += 1
            }
        }
        return adv
    }

    // --- UI ---

    var body: some View {
        VStack(spacing: 16) {
            header

            // Per-player progress (who’s up highlighted)
            VStack(spacing: 8) {
                ForEach(playersOrdered) { p in
                    let n = nextTarget(for: p)
                    let done = n > lastTarget
                    let isActive = (p.id == currentPlayer.id) && !legIsOver

                    HStack(spacing: 12) {
                        Image(systemName: "target")
                            .opacity(isActive ? 1 : 0.15)
                        Text(p.name)
                            .fontWeight(isActive ? .semibold : .regular)
                        Spacer()
                        ProgressView(value: Double(min(n-1, lastTarget)),
                                     total: Double(lastTarget))
                            .frame(width: 140)
                        Text(done ? "Done" : "Next \(n)")
                            .monospacedDigit()
                            .foregroundStyle(done ? .green : .secondary)
                    }
                    .activeHighlight(isActive)
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Input pad (choose S/D/T, then tap numbers 1–20; max 3 darts)
            ATWPad(currentMult: $currentMult, darts: $darts)

            HStack {
                Button("Undo Turn") { undoTurn() }.disabled(leg.turns.isEmpty)
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
        .navigationTitle("Around the World")
    }

    private var header: some View {
        VStack(spacing: 4) {
            if let w = leg.winner {
                Text("Game Over").font(.headline)
                Text("Winner: \(w.name)").font(.subheadline)
            } else {
                Text("Order: 1 → 20 • Singles/Doubles/Trebles all count as **one** step")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func submitTurn() {
        guard !legIsOver else { return }

        // Compute how many steps this turn advances
        let n = nextTarget(for: currentPlayer)
        let adv = advancementsFrom(darts: darts, startingAt: n)

        let t = Turn(
            player: currentPlayer,
            darts: darts,
            total: adv,              // store steps advanced; useful for stats
            bust: false,
            sequence: leg.turns.count,
            inning: nil
        )
        leg.turns.append(t)
        darts.removeAll()
        message = adv == 0 ? "No advance" : "Advanced \(adv) step\(adv == 1 ? "" : "s")"
        try? context.save()

        // Check for winner based on recomputed progress
        if progressSummary.nextByPlayer[currentPlayer.id] ?? 1 > lastTarget {
            leg.winner = currentPlayer
            message = "Game over — \(currentPlayer.name) wins!"
            try? context.save()
        }
    }

    private func undoTurn() {
        guard !leg.turns.isEmpty else { return }
        // remove the highest-sequence turn
        if let lastSeq = sortedTurns.last?.sequence,
           let idx = leg.turns.firstIndex(where: { $0.sequence == lastSeq }) {
            let last = leg.turns.remove(at: idx)
            message = "Undid \(last.player.name)’s last turn."
            leg.winner = nil
            darts.removeAll()
            try? context.save()
        }
    }
}

// MARK: - ATW Input Pad
private struct ATWPad: View {
    @Binding var currentMult: Int   // 1=S, 2=D, 3=T
    @Binding var darts: [Dart]

    private let numbers = Array(1...20)

    var body: some View {
        VStack(spacing: 10) {
            // Current darts line
            HStack {
                Text("Darts: \(darts.map { label(for: $0) }.joined(separator: "  "))")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
                Button("Clear") { darts.removeAll() }.disabled(darts.isEmpty)
            }

            // Multiplier picker
            Picker("Multiplier", selection: $currentMult) {
                Text("S").tag(1)
                Text("D").tag(2)
                Text("T").tag(3)
            }
            .pickerStyle(.segmented)

            // Number grid 1..20
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(numbers, id: \.self) { n in
                    Button("\(n)") {
                        guard darts.count < 3 else { return }
                        darts.append(Dart(segment: n, multiplier: currentMult))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func label(for d: Dart) -> String {
        let pfx = d.multiplier == 3 ? "T" : d.multiplier == 2 ? "D" : "S"
        return "\(pfx)\(d.segment)"
    }
}
