//
//  Item.swift
//  HealthRecordingApp
//  
//  Created on 2025/07/18
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
