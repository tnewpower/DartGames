//
//  Item.swift
//  Dart Games
//
//  Created by Tony Newpower on 8/18/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
