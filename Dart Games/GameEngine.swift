import Foundation

struct X01Engine {
    let starting: Int
    let doubleOut: Bool

    func apply(turnDarts: [Dart], currentRemaining: Int) -> (newRemaining: Int, bust: Bool, finishedOnDouble: Bool) {
        let scored = turnDarts.reduce(0) { $0 + $1.value }
        let remaining = currentRemaining - scored

        // Ends on double?
        let lastWasDouble = (turnDarts.last?.multiplier == 2)

        // Bust rules
        if remaining < 0 { return (currentRemaining, true, false) }
        if remaining == 1 { return (currentRemaining, true, false) }
        if remaining == 0 && doubleOut && !lastWasDouble { return (currentRemaining, true, false) }

        let finished = (remaining == 0) && (!doubleOut || lastWasDouble)
        return (finished ? 0 : remaining, false, finished && lastWasDouble)
    }
}
