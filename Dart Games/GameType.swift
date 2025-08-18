import Foundation
import SwiftData

enum GameType: String, Codable, CaseIterable, Identifiable {
    case baseball, x01_301, x01_501, cricket, aroundTheWorld
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .baseball: return "Baseball"
        case .x01_301:  return "301"
        case .x01_501:  return "501"
        case .cricket:  return "Cricket"
        case .aroundTheWorld: return "Around the World"
        }
    }
}

@Model
final class Player {
    var id: UUID
    var name: String
    var createdAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}

@Model
final class Match {
    var id: UUID
    var createdAt: Date
    var gameTypeRaw: String
    var players: [Player]
    var legs: [Leg]

    // X01 settings (extend per game as needed)
    var startingScore: Int?
    var doubleOut: Bool

    var gameType: GameType {
        get { GameType(rawValue: gameTypeRaw) ?? .x01_501 }
        set { gameTypeRaw = newValue.rawValue }
    }

    init(gameType: GameType, players: [Player], startingScore: Int? = nil, doubleOut: Bool = true) {
        self.id = UUID()
        self.createdAt = Date()
        self.gameTypeRaw = gameType.rawValue
        self.players = players
        self.legs = []
        self.startingScore = startingScore
        self.doubleOut = doubleOut
    }
}

@Model
final class Leg {
    var id: UUID
    var index: Int
    var turns: [Turn]
    var winner: Player?

    // X01 tracking (remaining per player)
    var remainingByPlayer: [UUID: Int] // Player.id : remaining

    init(index: Int, players: [Player], startingScore: Int?) {
        self.id = UUID()
        self.index = index
        self.turns = []
        self.winner = nil
        var map: [UUID: Int] = [:]
        for p in players { map[p.id] = startingScore ?? 0 }
        self.remainingByPlayer = map
    }
}

@Model
final class Turn {
    var id: UUID
    var player: Player
    var darts: [Dart]
    var total: Int
    var bust: Bool

    init(player: Player, darts: [Dart], total: Int, bust: Bool) {
        self.id = UUID()
        self.player = player
        self.darts = darts
        self.total = total
        self.bust = bust
    }
}

@Model
final class Dart {
    var id: UUID
    /// 1...20, 25 (outer bull), 50 (bull) — store raw points per dart hit
    var value: Int
    var segment: Int // 1...20, 25, 50
    var multiplier: Int // 1,2,3

    init(segment: Int, multiplier: Int) {
        self.id = UUID()
        self.segment = segment
        self.multiplier = multiplier
        self.value = segment * multiplier
    }
}
