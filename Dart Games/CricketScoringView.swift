import SwiftUI
import SwiftData

struct CricketScoringView: View {
    @Environment(\.modelContext) private var context

    // Passed in by the loader
    @State var match: Match
    @State var leg: Leg

    // Turn input (max 3 darts)
    @State private var darts: [Dart] = []
    @State private var currentMult: Int = 1 // 1=S, 2=D, 3=T
    @State private var message: String?

    // Targets (use 25 for Bull internally)
    private let targets: [Int] = [20, 19, 18, 17, 16, 15, 25]

    // Frozen player order for stability
    private var playersOrdered: [Player] {
        let map = Dictionary(uniqueKeysWithValues: match.players.map { ($0.id, $0) })
        let ordered = match.playerOrder.compactMap { map[$0] }
        return ordered.isEmpty ? match.players : ordered
    }
    private var pCount: Int { playersOrdered.count }

    // Whose turn?
    private var turnsSoFar: Int { leg.turns.count }
    private var currentPlayerIndex: Int { pCount == 0 ? 0 : (turnsSoFar % pCount) }
    private var currentPlayer: Player { playersOrdered[currentPlayerIndex] }

    // Sort turns by explicit sequence (stable across renders)
    private var sortedTurns: [Turn] {
        leg.turns.sorted { a, b in
            if a.sequence != b.sequence { return a.sequence < b.sequence }
            return a.createdAt < b.createdAt
        }
    }

    // Recompute state purely from saved turns
    private var cricketState: (marks: [UUID:[Int:Int]], points: [UUID:Int]) {
        var marks: [UUID:[Int:Int]] = [:]
        var points: [UUID:Int] = [:]
        for p in playersOrdered {
            marks[p.id] = Dictionary(uniqueKeysWithValues: targets.map { ($0, 0) })
            points[p.id] = 0
        }

        // helper: does at least one opponent still have this target open?
        func anyOpponentOpen(_ pid: UUID, _ t: Int) -> Bool {
            for opp in playersOrdered where opp.id != pid {
                if (marks[opp.id]?[t] ?? 0) < 3 { return true }
            }
            return false
        }

        for turn in sortedTurns {
            let pid = turn.player.id
            for d in turn.darts {
                guard let hit = cricketHit(for: d) else { continue } // ignore non-targets
                let t = hit.target
                var m = marks[pid]?[t] ?? 0

                // overflow marks beyond 3 score points if any opponent is still open
                let prior = m
                let add = hit.marks
                let new = min(3, prior + add)
                let overflow = max(0, prior + add - 3)

                if overflow > 0, anyOpponentOpen(pid, t) {
                    points[pid, default: 0] += overflow * hit.pointsPerMark
                }

                m = new
                marks[pid]?[t] = m
            }
        }

        return (marks, points)
    }

    // Winner check (close ALL targets AND be >= everyone on points)
    private var winnerID: UUID? {
        let (marks, points) = cricketState
        for p in playersOrdered {
            let closedAll = targets.allSatisfy { (marks[p.id]?[$0] ?? 0) >= 3 }
            if closedAll {
                let my = points[p.id] ?? 0
                let aheadOrTieAll = playersOrdered.allSatisfy { other in
                    (points[other.id] ?? 0) <= my
                }
                if aheadOrTieAll { return p.id }
            }
        }
        return nil
    }

    private var legIsOver: Bool { leg.winner != nil || winnerID != nil }

    // MARK: UI

    var body: some View {
        VStack(spacing: 16) {
            header

            // Score table (marks + points), active player highlighted
            CricketGrid(players: playersOrdered,
                        targets: targets,
                        marks: cricketState.marks,
                        points: cricketState.points,
                        activePlayerID: leg.winner == nil ? currentPlayer.id : nil)

            CricketPad(currentMult: $currentMult, darts: $darts)

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
        .navigationTitle("Cricket")
    }

    private var header: some View {
        VStack(spacing: 4) {
            if let w = leg.winner {
                Text("Game Over").font(.headline)
                Text("Winner: \(w.name)").font(.subheadline)
            } else {
                Text("Targets: 20 • 19 • 18 • 17 • 16 • 15 • Bull")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("S=1 mark, D=2, T=3 • Extra marks score points while opponents are open")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Actions

    private func submitTurn() {
        guard !legIsOver else { return }

        // Compute points for THIS turn against current state
        let (marksNow, pointsNow) = cricketState
        let pid = currentPlayer.id

        func anyOpponentOpen(_ t: Int) -> Bool {
            for opp in playersOrdered where opp.id != pid {
                if (marksNow[opp.id]?[t] ?? 0) < 3 { return true }
            }
            return false
        }

        var turnPoints = 0
        var myMarks = marksNow[pid] ?? [:]

        for d in darts {
            guard let hit = cricketHit(for: d) else { continue }
            let t = hit.target
            let prior = myMarks[t] ?? 0
            let add = hit.marks
            let overflow = max(0, prior + add - 3)
            if overflow > 0, anyOpponentOpen(t) {
                turnPoints += overflow * hit.pointsPerMark
            }
            myMarks[t] = min(3, prior + add)
        }

        let t = Turn(player: currentPlayer,
                     darts: darts,
                     total: turnPoints,   // store points scored this turn
                     bust: false,
                     sequence: leg.turns.count,
                     inning: nil)
        leg.turns.append(t)
        darts.removeAll()
        message = turnPoints == 0 ? "No points" : "Scored \(turnPoints)"

        // Persist and check winner from full recompute
        try? context.save()
        if let id = winnerID, let w = playersOrdered.first(where: { $0.id == id }) {
            leg.winner = w
            try? context.save()
            message = "Game over — \(w.name) wins!"
        }
    }

    private func undoTurn() {
        guard !leg.turns.isEmpty else { return }
        if let lastSeq = sortedTurns.last?.sequence,
           let idx = leg.turns.firstIndex(where: { $0.sequence == lastSeq }) {
            let last = leg.turns.remove(at: idx)
            darts.removeAll()
            leg.winner = nil
            message = "Undid \(last.player.name)’s last turn."
            try? context.save()
        }
    }

    // MARK: Mapping darts to Cricket hits
    private struct Hit { let target: Int; let marks: Int; let pointsPerMark: Int }

    /// Returns a hit for cricket targets or nil for non-targets.
    private func cricketHit(for d: Dart) -> Hit? {
        // Bull: 25 (outer) = 1 mark; 50 (inner) = 2 marks; points are 25 per mark.
        if d.segment == 50 { return Hit(target: 25, marks: 2, pointsPerMark: 25) }
        if d.segment == 25 {
            let m = max(1, min(2, d.multiplier)) // S=1, D=2 (just in case)
            return Hit(target: 25, marks: m, pointsPerMark: 25)
        }
        // 15..20: per-mark points equals the number
        if (15...20).contains(d.segment) {
            let m = max(1, min(3, d.multiplier))
            return Hit(target: d.segment, marks: m, pointsPerMark: d.segment)
        }
        return nil // non-targets (1..14) don't count in Cricket
    }
}

// MARK: - Grid (marks & points)
private struct CricketGrid: View {
    let players: [Player]
    let targets: [Int]                // [20,19,18,17,16,15,25]
    let marks: [UUID:[Int:Int]]       // per player per target (0..3)
    let points: [UUID:Int]            // per player total points
    let activePlayerID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                // Header
                GridRow {
                    Text("Player").font(.caption.bold()).frame(minWidth: 90, alignment: .leading)
                    ForEach(targets, id: \.self) { t in
                        Text(label(for: t)).font(.caption.bold()).frame(width: 34, alignment: .center)
                    }
                    Text("Pts").font(.caption.bold()).frame(width: 44, alignment: .trailing)
                }
                Divider().gridCellUnsizedAxes(.horizontal)

                ForEach(players) { p in
                    let isActive = (activePlayerID == p.id)
                    GridRow {
                        Text(p.name).frame(minWidth: 90, alignment: .leading)
                        ForEach(targets, id: \.self) { t in
                            let m = marks[p.id]?[t] ?? 0
                            Text(marksGlyph(m))
                                .frame(width: 34, alignment: .center)
                                .font(.body.monospaced())
                                .foregroundStyle(m == 3 ? .primary : .secondary)
                        }
                        Text("\(points[p.id, default: 0])")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                            .font(.headline)
                    }
                    .padding(.vertical, 2)
                    .activeHighlight(isActive)
                    Divider().gridCellUnsizedAxes(.horizontal)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxHeight: 220)
    }

    private func label(for t: Int) -> String { t == 25 ? "Bull" : "\(t)" }

    private func marksGlyph(_ n: Int) -> String {
        switch n {
        case 0: return "—"
        case 1: return "•"
        case 2: return "••"
        default: return "✔︎" // closed (3+)
        }
    }
}

// MARK: - Input Pad
private struct CricketPad: View {
    @Binding var currentMult: Int   // 1=S, 2=D, 3=T
    @Binding var darts: [Dart]

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Darts: \(darts.map { label(for: $0) }.joined(separator: "  "))")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
                Button("Clear") { darts.removeAll() }
                    .disabled(darts.isEmpty)
            }

            Picker("Multiplier", selection: $currentMult) {
                Text("S").tag(1); Text("D").tag(2); Text("T").tag(3)
            }
            .pickerStyle(.segmented)

            // 20..15 grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach([20,19,18,17,16,15], id: \.self) { n in
                    Button("\(n)") {
                        guard darts.count < 3 else { return }
                        darts.append(Dart(segment: n, multiplier: currentMult))
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack {
                Button("Outer Bull") { addBull(outer: true) }
                Button("Inner Bull") { addBull(outer: false) }
                Button("Miss") { addMiss() }
            }
            .buttonStyle(.bordered)
        }
    }

    private func addBull(outer: Bool) {
        guard darts.count < 3 else { return }
        if outer { darts.append(Dart(segment: 25, multiplier: 1)) }
        else     { darts.append(Dart(segment: 50, multiplier: 1)) } // 50 is treated specially
    }

    private func addMiss() {
        guard darts.count < 3 else { return }
        darts.append(Dart(segment: 0, multiplier: 0))
    }

    private func label(for d: Dart) -> String {
        if d.segment == 0 { return "M" }
        if d.segment == 50 { return "50" }
        if d.segment == 25 { return "25" }
        let p = d.multiplier == 3 ? "T" : d.multiplier == 2 ? "D" : "S"
        return "\(p)\(d.segment)"
    }
}
