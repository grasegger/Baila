//
//  BailaApp.swift
//  Baile
//
//  Created by Karl on 30.04.26.
//

import BackgroundTasks
import OSLog
import SwiftData
import SwiftUI

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let background = Logger(subsystem: subsystem, category: "UI")
}

@main
struct BailaApp : App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CachedFile.self,
            Track.self,
            CD.self,
            Album.self,
            Artist.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        do {
            try AppFiles.ensureAppFolderExists()
            AppFiles.ensurePlaceholderFile()
        } catch {
            Logger.ui.error("Failed to create app folder: \(error.localizedDescription)")
        }
        BailaApp.registerBackgroundTask(modelContainer: sharedModelContainer)
        BailaApp.scheduleAppRefreshStatic()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .task {
                    await scanAndPersistMusicFiles(modelContainer: sharedModelContainer)
                }
        }
    }

    private func scanAndPersistMusicFiles(modelContainer: ModelContainer) async {
        do {
            try await TagReader.scanAndPersistMusicFilesStatic(modelContainer: modelContainer)
        } catch {
            Logger.background.error("Error importing music files")
        }
    }

    static func registerBackgroundTask(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.github.grasegger.JewelMusic.backgroundrefresh", using: nil) { task in
            Task {
                do {
                    try await TagReader.scanAndPersistMusicFilesStatic(modelContainer: modelContainer)
                } catch {
                    Logger.background.error("Error importing music files")
                }
                    task.setTaskCompleted(success: true)
                    scheduleAppRefreshStatic()
            }
        }
    }

    static func scheduleAppRefreshStatic() {
        let request = BGAppRefreshTaskRequest(identifier: "com.github.grasegger.JewelMusic.backgroundrefresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        try? BGTaskScheduler.shared.submit(request)
    }
}
