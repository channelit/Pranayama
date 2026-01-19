//
//  Item.swift
//  Pranayama
//
//  Created by Hardik Patel on 2/20/25.
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
