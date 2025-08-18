import SwiftUI

// Entry point – choose the correct rules page for the game
struct RulesView: View {
    let gameType: GameType

    var body: some View {
        switch gameType {
        case .x01_301: X01RulesView(starting: 301)
        case .x01_501: X01RulesView(starting: 501)
        case .baseball: BaseballRulesView()
        case .aroundTheWorld: AroundTheWorldRulesView()
        case .cricket: CricketRulesView()
        }
    }
}

// Small bullet row helper
private struct RuleRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .imageScale(.small)
                .foregroundStyle(.tint)
                .padding(.top, 3)
            Text(.init(text))
            Spacer()
        }
    }
}

// MARK: - X01 (301/501)
private struct X01RulesView: View {
    let starting: Int
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header("X01 (\(starting))")
                RuleRow(text: "**Objective:** start at **\(starting)** and reach **exactly 0**.")
                RuleRow(text: "**Turns:** up to **3 darts** per turn; subtract the scored value from your remaining.")
                RuleRow(text: "**Double-out (optional):** if enabled, the **last dart must be a Double**. Finishing on 0 without a Double is a **bust**.")
                RuleRow(text: "**Busts:** score **over** your remaining, leave **1**, or (with Double-out on) finish on 0 **without** a Double → your score **reverts** to the start of the turn.")
                RuleRow(text: "**Order:** players alternate turns until someone finishes a leg.")

                subheader("Scoring quick facts")
                RuleRow(text: "Singles = number × **1**, Doubles × **2**, Trebles × **3**.")
                RuleRow(text: "Bull = **50**, Outer bull = **25**.")

                subheader("Checkout examples")
                Group {
                    example("170", "T20 • T20 • Bull")
                    example("167", "T20 • T19 • Bull")
                    example("164", "T20 • T18 • Bull")
                    example("40", "D20")
                    example("32", "D16 (or 16 • D8)")
                }

                footer
            }
            .padding()
        }
        .navigationTitle("X01 Rules")
    }

    private func header(_ title: String) -> some View {
        Text(title).font(.largeTitle.bold())
    }
    private func subheader(_ title: String) -> some View {
        Text(title).font(.title3.bold())
    }
    private func example(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left).font(.body.monospaced()).frame(width: 60, alignment: .leading)
            Text(right)
            Spacer()
        }
    }
    private var footer: some View {
        Text("Tip: Aim to leave an even number; **32 (D16)** is a friendly finish.")
            .foregroundStyle(.secondary)
            .padding(.top, 6)
    }
}

// MARK: - Baseball
private struct BaseballRulesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Baseball").font(.largeTitle.bold())

                RuleRow(text: "**Objective:** highest **total points** after **9 innings** wins.")
                RuleRow(text: "**Turns:** each inning, every player gets **one turn (up to 3 darts)**.")
                RuleRow(text: "**Only the inning’s number scores** (Inning 1 → only **1s**, Inning 2 → only **2s**, …).")
                RuleRow(text: "Singles = **1**, Doubles = **2**, Trebles = **3** per dart. Miss = **0**.")
                RuleRow(text: "After all players throw in Inning 9, game ends. Tied? **Extra innings** until a winner (optional).")

                Text("Variants").font(.title3.bold())
                RuleRow(text: "House rules sometimes allow **walk-off** in the last inning (home player doesn’t throw if already ahead).")

                Text("App details").font(.title3.bold())
                RuleRow(text: "Scoreboard shows per-inning box score and running totals.")
                RuleRow(text: "**Undo Turn** removes the last recorded turn.")
            }
            .padding()
        }
        .navigationTitle("Baseball Rules")
    }
}

// MARK: - Around the World
private struct AroundTheWorldRulesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Around the World").font(.largeTitle.bold())

                RuleRow(text: "**Objective:** hit **1 → 20 in order**.")
                RuleRow(text: "**Any hit counts** (Single/Double/Treble each advance **one step**).")
                RuleRow(text: "**Multiple steps in a turn:** you may advance several numbers if you hit them **in sequence** (e.g., S1, D2, T3 = +3).")
                RuleRow(text: "Hitting the **same** number again doesn’t advance.")
                RuleRow(text: "First player to pass **20** wins. (Bull as a final step is an optional variant.)")

                Text("App details").font(.title3.bold())
                RuleRow(text: "Progress bar shows how far each player has advanced; **Undo Turn** supported.")
            }
            .padding()
        }
        .navigationTitle("Around the World Rules")
    }
}

// MARK: - Cricket
private struct CricketRulesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Cricket").font(.largeTitle.bold())

                RuleRow(text: "**Targets:** **20, 19, 18, 17, 16, 15, Bull**.")
                RuleRow(text: "**Marks:** each Single = **1 mark**, Double = **2**, Treble = **3**.")
                RuleRow(text: "You **close** a number at **3 marks**. After you close a number, **additional hits score points** **only** if your opponent hasn’t closed it.")
                RuleRow(text: "Bull: outer = **25** (1 mark), inner = **50** (2 marks). Close Bull at 3 marks total.")
                RuleRow(text: "**Win:** close **all targets** and be **ahead on points**.")
                RuleRow(text: "Common variant: **no points on Bull** (house rules vary).")

                Text("App status").font(.title3.bold())
                RuleRow(text: "Scoring UI coming soon; these are the rules the app will follow.")
            }
            .padding()
        }
        .navigationTitle("Cricket Rules")
    }
}
