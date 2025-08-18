//
//  BaseballScoringView.swift
//  Dart Games
//
//  Created by Tony Newpower on 8/18/25.
//


import SwiftUI
import SwiftData

struct BaseballScoringView: View {
    @Environment(\.modelContext) private var context

    @State var match: Match
    @State var leg: Leg

    @State private var darts: [Dart] = []
    @State private var message: String?

    // Use frozen order from the match for absolute stability
    private var orderedPlayers: [Player] {
        let map = Dictionary(uniqueKeysWithValues: match.players.map { ($0.id, $0) })
        let ordered = match.playerOrder.compactMap { map[$0] }
        return ordered.isEmpty ? match.players : ordered
    }
    private var pCount: Int { orderedPlayers.count }

    // Always reference the most recent number of recorded turns
    private var turnsSoFar: Int { leg.turns.count }

    // Inning & batter based on count (not array order)
    private var currentInning: Int {
        guard pCount > 0 else { return 1 }
        return min(9, 1 + turnsSoFar / pCount)
    }
    private var currentPlayerIndex: Int {
        guard pCount > 0 else { return 0 }
        return turnsSoFar % pCount
    }
    private var currentPlayer: Player {
        orderedPlayers[currentPlayerIndex]
    }

    // Use explicit inning+sequence for the grid (ignore any underlying reordering)
    private var sortedTurns: [Turn] {
        leg.turns.sorted { lhs, rhs in
            if lhs.sequence != rhs.sequence { return lhs.sequence < rhs.sequence }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private var boxScoreRows: [(player: Player, innings: [Int], total: Int)] {
        guard pCount > 0 else { return [] }
        var rows: [(Player, [Int])] = orderedPlayers.map { ($0, Array(repeating: 0, count: 9)) }

        // Sum by stored inning per player
        for t in sortedTurns {
            guard let inn = t.inning, (1...9).contains(inn) else { continue }
            if let rowIdx = orderedPlayers.firstIndex(where: { $0.id == t.player.id }) {
                rows[rowIdx].1[inn - 1] += t.total
            }
        }
        return rows.map { ($0.0, $0.1, $0.1.reduce(0, +)) }
    }

    private var totalsByPlayer: [UUID: Int] {
        var map: [UUID: Int] = [:]
        for row in boxScoreRows { map[row.player.id] = row.total }
        return map
    }

    private var legIsOver: Bool {
        turnsSoFar >= (9 * max(pCount, 1)) || leg.winner != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            // Totals strip
            VStack(spacing: 8) {
                ForEach(orderedPlayers) { p in
                    let isActive = (p.id == currentPlayer.id) && !legIsOver
                    HStack(spacing: 12) {
                        Image(systemName: "scope").opacity(isActive ? 1 : 0.15)
                        Text(p.name)
                            .fontWeight(isActive ? .semibold : .regular)
                        Spacer()
                        Text("\(totalsByPlayer[p.id, default: 0])")
                            .monospacedDigit()
                            .font(isActive ? .title3.weight(.semibold) : .title3)
                            .foregroundStyle(isActive ? .primary : .secondary)
                    }
                    .activeHighlight(isActive)
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.snappy, value: currentPlayerIndex)


            // Box score grid (stable)
            BaseballBoxScore(rows: boxScoreRows)

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
            // If resumed past 9 innings, ensure winner
            if turnsSoFar >= (9 * max(pCount, 1)) { finalizeWinnerIfNeeded() }
        }
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

        let points = darts.reduce(0) { $0 + $1.multiplier }   // S=1, D=2, T=3, Miss=0
        _ = turnsSoFar
        _ = currentInning

        let t = Turn(
            player: currentPlayer,
            darts: darts,
            total: points,
            bust: false,
            sequence: leg.turns.count,   // ✅
            inning: currentInning        // ✅
        )
        leg.turns.append(t)
        darts.removeAll()
        message = "Scored \(points) point\(points == 1 ? "" : "s")"
        try? context.save()

        if turnsSoFar >= (9 * max(pCount, 1)) {
            finalizeWinnerIfNeeded()
        }
    }

    private func finalizeWinnerIfNeeded() {
        let rows = boxScoreRows
        guard !rows.isEmpty else { return }
        let winnerRow = rows.max(by: { $0.total < $1.total })
        if let w = winnerRow?.player {
            leg.winner = w
            message = "Game over — \(w.name) wins!"
            try? context.save()
        }
    }

    private func undoTurn() {
        guard !leg.turns.isEmpty else { return }
        // Remove the highest-sequence turn (true "last" turn)
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

// MARK: - Box score view (unchanged API, new data source)
private struct BaseballBoxScore: View {
    let rows: [(player: Player, innings: [Int], total: Int)]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Player").font(.caption.bold()).frame(minWidth: 90, alignment: .leading)
                    ForEach(1...9, id: \.self) { i in
                        Text("\(i)").font(.caption.bold()).frame(width: 28, alignment: .trailing)
                    }
                    Text("T").font(.caption.bold()).frame(width: 36, alignment: .trailing)
                }
                Divider().gridCellUnsizedAxes(.horizontal)

                ForEach(rows, id: \.player.id) { row in
                    GridRow {
                        Text(row.player.name).frame(minWidth: 90, alignment: .leading)
                        ForEach(0..<9, id: \.self) { idx in
                            Text("\(row.innings[idx])")
                                .monospacedDigit()
                                .frame(width: 28, alignment: .trailing)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(row.total)")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                            .font(.headline)
                    }
                    .padding(.vertical, 2)
                    Divider().gridCellUnsizedAxes(.horizontal)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxHeight: 180)
    }
}

// MARK: - Hit pad (unchanged)
private struct BaseballHitPad: View {
    let inning: Int
    @Binding var darts: [Dart]

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
