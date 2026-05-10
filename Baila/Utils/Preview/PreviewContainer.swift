//
//  Utils.swift
//  Baile
//
//  Created by Karl on 01.05.26.
//
import Foundation
import SwiftData

#if DEBUG

class PreviewContainer {
    static let previewContainer: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: Artist.self,
                Album.self,
                CD.self,
                Track.self,
                CachedFile.self,
                PlaylistPosition.self,
                configurations: config
            )
            TagReaderService.shared.configure(modelContainer: container)
            
            func makeAlbum(
                name: String,
                releaseDate: Date
            ) -> Album {
                let artwork = PreviewArtwork.randomFixture()
                let albumArt = artwork.albumArt
                
                return Album(
                    name: name,
                    releaseDate: releaseDate,
                    albumArt: albumArt,
                    albumBackground: albumArt,
                    dominantColorHex: artwork.dominantColorHex,
                    dominantColorHexes: artwork.dominantColorHexes,
                    isDark: artwork.isDark,
                    CDs: [],
                    artist: nil
                )
            }
            
            let artists = [
                Artist(
                    name: "The Preview Artist",
                    albums: [
                        makeAlbum(
                            name: "Preview Album",
                            releaseDate: Date(timeIntervalSince1970: 1_704_067_200)
                        )
                    ]
                ),
                Artist(
                    name: "Sample Artist",
                    albums: [
                        makeAlbum(
                            name: "Sample Record",
                            releaseDate: Date(timeIntervalSince1970: 1_672_531_200)
                        )
                    ]
                )
            ]
            
            artists.forEach(container.mainContext.insert)
            
            try container.mainContext.save()
            
            return container
        } catch {
            fatalError("Failed to create model container for previewing: \(error.localizedDescription)")
        }
    }()
}

#endif // DEBUG
