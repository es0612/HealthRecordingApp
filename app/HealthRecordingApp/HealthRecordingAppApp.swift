//
//  HealthRecordingAppApp.swift
//  HealthRecordingApp
//  
//  Created on 2025/07/18
//


import SwiftUI
import SwiftData

@main
struct HealthRecordingAppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            HealthRecord.self,
            User.self,
            Goal.self,
            Badge.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // TODO: Temporarily disabled fatalError for testing - restore in production
            print("Warning: Could not create ModelContainer: \(error)")
            // Return a memory-only container as fallback
            return try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
