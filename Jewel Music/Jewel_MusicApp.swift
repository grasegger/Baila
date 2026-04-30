//
//  Jewel_MusicApp.swift
//  Jewel Music
//
//  Created by Karl on 30.04.26.
//

import SwiftUI
import SwiftData

@main
struct Jewel_MusicApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Ensure the app's working folder exists in Documents so it appears in Files app
        do {
            try AppFiles.ensureAppFolderExists()
            AppFiles.ensurePlaceholderFile()
        } catch {
            // It's generally safe to log here; consider surfacing to diagnostics later
            NSLog("Failed to create app folder: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
