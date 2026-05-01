//
//  Utils.swift
//  Baile
//
//  Created by Karl on 01.05.26.
//
import Foundation
import SwiftData
import SwiftUI

class Utils {
    static let previewContainer: ModelContainer = {
        do {
            print("Creating container")
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Artist.self, configurations: config)
            
            for i in 0...26  {
                let image = UIImage(named: "albumArt")!
                let data = image.pngData()!
                let artist = Artist(name: "Artist\(i)", albums: [
                    Album(
                        name: "Album",
                        releaseDate: Date(),
                        albumArt: data,
                        CDs: [],
                        artist: nil
                    ),
                    Album(
                        name: "Album2",
                        releaseDate: Date(timeIntervalSinceNow: -60 * 60 * 24 * 365 * 5),
                        albumArt: data,
                        CDs: [],
                        artist: nil
                    )
                ])
                container.mainContext.insert(artist)
            }

            
            return container
        } catch {
            fatalError("Failed to create model container for previewing: \(error.localizedDescription)")
        }
    }()
}
