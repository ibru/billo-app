//
//  Item.swift
//  Billo
//
//  Created by Jiri Urbasek on 11/25/25.
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
