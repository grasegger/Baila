import AVFoundation
//
//  Utils.swift
//  Baile
//
//  Created by Karl on 01.05.26.
//
import Foundation
import MediaPlayer
import OSLog
import SwiftData
import SwiftUI

// todo dont do this
class Utils {
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
      let missingAlbumArt = UIImage(named: "missing_album_art")?.pngData()
      let missingAlbumArtColor = "#3A3530"
      let missingAlbumArtColors = ["#3A3530", "#EEE8E0", "#151515"]

        
      for i in 0...26 {
        let albumCount = Int.random(in: 1...8)
        let albums = (0..<albumCount).map { (albumIndex: Int) in
          Album(
            name: "Album \(albumIndex + 1)",
            releaseDate: Date(timeIntervalSinceNow: -Double(albumIndex) * 60 * 60 * 24 * 365),
            albumArt: missingAlbumArt,
            dominantColorHex: missingAlbumArtColor,
            dominantColorHexes: missingAlbumArtColors,
            CDs: [],
            artist: nil
          )
        }
          if i.isMultiple(of: 2)
          {
              let artist = Artist(name: "The ZArtist\(i)", albums: albums)
              container.mainContext.insert(artist)
          } else {
              let artist = Artist(name: "ZArtist\(i)", albums: albums)
              container.mainContext.insert(artist)

          }
      }

      let artist = Artist(name: "Someone who played a guitar once", albums: [])

      let album = Album(
        name: "This should have been a single but there is a second track",
        releaseDate: Date(),
        albumArt: missingAlbumArt,
        dominantColorHex: missingAlbumArtColor,
        dominantColorHexes: missingAlbumArtColors,
        CDs: [],
        artist: artist
      )
      let cd = CD(number: 1, tracks: [], album: album)
      let track = Track(
        name: "Extra long track name so it has to be cut off ...",
        artist: artist.name,
        number: 1,
        runtime: 245,
        CD: cd,
        file: nil, playlistPosition: nil
      )

      artist.albums = [album]
      album.CDs = [cd]
      cd.tracks = [track]
        
        container.mainContext.insert(track)
        container.mainContext.insert(artist)
        container.mainContext.insert(album)
        container.mainContext.insert(cd)

      let previewArtist = Artist(name: "Album Art Preview", albums: [])
      let previewAlbums = [
        Album(
          name: "Visible Cover",
          releaseDate: .now,
          albumArt: missingAlbumArt,
          dominantColorHex: missingAlbumArtColor,
          dominantColorHexes: missingAlbumArtColors,
          CDs: [],
          artist: previewArtist
        ),
        Album(
          name: "Second Album",
          releaseDate: Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now,
          albumArt: missingAlbumArt,
          dominantColorHex: missingAlbumArtColor,
          dominantColorHexes: missingAlbumArtColors,
          CDs: [],
          artist: previewArtist
        ),
        Album(
          name: "Third Album",
          releaseDate: Calendar.current.date(byAdding: .year, value: -2, to: .now) ?? .now,
          albumArt: missingAlbumArt,
          dominantColorHex: missingAlbumArtColor,
          dominantColorHexes: missingAlbumArtColors,
          CDs: [],
          artist: previewArtist
        )
      ]

      previewArtist.albums = previewAlbums
      container.mainContext.insert(previewArtist)
      for previewAlbum in previewAlbums {
        container.mainContext.insert(previewAlbum)
      }

      try container.mainContext.save()

      return container
    } catch {
      fatalError("Failed to create model container for previewing: \(error.localizedDescription)")
    }
  }()
}
