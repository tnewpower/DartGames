import SwiftUI
import SwiftData

struct ResumeMatchView: View {
    @Environment(\.modelContext) private var context
    @State var match: Match

    var body: some View {
        if let leg = match.legs.last {
            switch match.gameType {
            case .x01_301, .x01_501:
                X01ScoringView(match: match, leg: leg)
            default:
                Text("Resume not implemented for \(match.gameType.displayName) yet.")
            }
        } else {
            Text("No legs found.")
        }
    }
}
