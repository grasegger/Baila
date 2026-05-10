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
struct BailaApp: App {
  private let isRunningPreview =
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
  let sharedModelContainer: ModelContainer

  init() {
    guard !isRunningPreview else {
      sharedModelContainer = Self.makeModelContainer(isStoredInMemoryOnly: true)
      return
    }
      
#if targetEnvironment(simulator)
     Self.deleteSwiftDataStore()
#endif

    sharedModelContainer = Self.makeModelContainer(isStoredInMemoryOnly: false)

    do {
      try AppFiles.ensureAppFolderExists()
    } catch {
      Logger.ui.error("Failed to create app folder: \(error.localizedDescription)")
    }

    PlaybackController.shared.configure(modelContainer: sharedModelContainer)
    TagReaderService.shared.configure(modelContainer: sharedModelContainer)
    Task {
      await TagReaderService.shared.backfillAlbumBackgroundLuminanceIfNeeded()
    }
  }
 
  private static func makeModelContainer(isStoredInMemoryOnly: Bool) -> ModelContainer {
    let schema = Schema([
      CachedFile.self,
      Track.self,
      CD.self,
      Album.self,
      Artist.self,
      PlaylistPosition.self,
    ])
    let modelConfiguration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: isStoredInMemoryOnly
    )

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }

  private static func deleteSwiftDataStore() {
    let fileManager = FileManager.default
    guard let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

    let databaseFiles = ["default.store", "default.store-shm", "default.store-wal"]

    for fileName in databaseFiles {
      let fileURL = url.appendingPathComponent(fileName)
      guard fileManager.fileExists(atPath: fileURL.path) else { continue }

      do {
        try fileManager.removeItem(at: fileURL)
        Logger.ui.debug("Deleted SwiftData store file: \(fileName)")
      } catch {
        Logger.ui.error("Failed to delete SwiftData store file \(fileName): \(error.localizedDescription)")
      }
    }
  }
  var body: some Scene {
    WindowGroup {
      MainView()
        .modelContainer(sharedModelContainer)
    }
  }

}
