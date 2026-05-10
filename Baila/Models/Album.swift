//
//  Album.swift
//  Baile
//
//  Created by Karl on 01.05.26.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

@Model
class Album {
  @Attribute(.unique) var id: UUID
  var name: String
  var releaseDate: Date
  @Attribute(.externalStorage) var albumArt: Data?
  @Attribute(.externalStorage) var albumBackground: Data?
  var albumBackgroundStyleVersion: Int
  var dominantColorHex: String?
  var dominantColorHexes: [String]
  var isDark: Bool = false
  var artist: Artist?
    var type: String?
    @Relationship(deleteRule: .cascade, inverse: \CD.album) var CDs: [CD]

  init(
    id: UUID = UUID(),
    name: String,
    releaseDate: Date,
    albumArt: Data?,
    albumBackground: Data? = nil,
    albumBackgroundStyleVersion: Int = 0,
    dominantColorHex: String? = nil,
    dominantColorHexes: [String] = [],
    isDark: Bool = false,
    CDs: [CD],
    artist: Artist?,
    type: String? = nil
  ) {
    self.id = id
    self.name = name
    self.releaseDate = releaseDate
    self.albumArt = albumArt
    self.albumBackground = albumBackground
    self.albumBackgroundStyleVersion = albumBackgroundStyleVersion
    self.dominantColorHex = dominantColorHex ?? dominantColorHexes.first
    self.dominantColorHexes = dominantColorHexes
    self.isDark = isDark
    self.CDs = CDs
    self.artist = artist
      self.type = type
  }

  var sortedCDs: [CD] {
    CDs.sorted { $0.number < $1.number }
  }
  var allTracksSorted: [Track] {
    sortedCDs.flatMap { cd in
      cd.sortedTracks
    }
  }

  var runtime: TimeInterval {
    CDs.reduce(into: .zero) { partialResult, cd in
      partialResult += cd.runtime
    }
  }

  var releaseYear: String {
    String(Calendar.current.component(.year, from: releaseDate))
  }

  var artworkImage: UIImage? {
    if let albumArt,
       let image = UIImage(data: albumArt) {
      return image
    }

    return UIImage(named: "missing_album_art")
  }

  var backgroundImage: UIImage? {
    guard let albumBackground else { return nil }
    return UIImage(data: albumBackground)
  }

  var primaryColor: Color {
    guard let dominantColorHex,
          let color = Self.color(fromHex: dominantColorHex) else {
      return .primary
    }

    return color
  }

  private static func color(fromHex hex: String) -> Color? {
    let trimmedHex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard trimmedHex.count == 6,
          let value = Int(trimmedHex, radix: 16) else {
      return nil
    }

    return Color(
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255
    )
  }

  static func makeSortDescriptors(sortByReleaseDate: Bool, ascending: Bool) -> [SortDescriptor<Album>] {
    let order: SortOrder = ascending ? .forward : .reverse

    if sortByReleaseDate {
      return [
        SortDescriptor(\Album.releaseDate, order: order),
        SortDescriptor(\Album.name, comparator: .localizedStandard, order: order),
      ]
    } else {
      return [
        SortDescriptor(\Album.name, comparator: .localizedStandard, order: order),
        SortDescriptor(\Album.releaseDate, order: order),
      ]
    }
  }

  static func getOrCreate(
    name: String?,
    by artist: Artist,
    on releaseDateString: String?,
    image: Data?,
    background: Data? = nil,
    backgroundStyleVersion: Int = 0,
    dominantColorHex: String? = nil,
    dominantColorHexes: [String] = [],
    isDark: Bool = false,
    context: ModelContext
  ) throws -> Album {
    let name = name ?? "Unknown Album"
    var releaseDate = Date.distantPast

    if let releaseDateString,
       let parsed = try? Date(
         releaseDateString,
         strategy: .iso8601.year().month().day()
       ) {
      releaseDate = parsed
    }
    
      if let releaseDateString,
         let parsed = try? Date(
            releaseDateString,
            strategy: .iso8601.year()
         ) {
          releaseDate = parsed
      }

    let descriptor = FetchDescriptor<Album>(predicate: #Predicate { $0.name == name })
    let results = try context.fetch(descriptor)

    let filtered = results.filter { album in
      if let albumArtist = album.artist {
        return albumArtist.persistentModelID == artist.persistentModelID
      } else {
        return false
      }
    }

    if let album = filtered.first {
      if album.albumArt == nil, let image {
        album.albumArt = image
      }
      if let background {
        album.albumBackground = background
        album.albumBackgroundStyleVersion = backgroundStyleVersion
      }
      if album.dominantColorHex == nil {
        album.dominantColorHex = dominantColorHex ?? dominantColorHexes.first
      }
      if album.dominantColorHexes.isEmpty {
        album.dominantColorHexes = dominantColorHexes
      }
      album.isDark = isDark
      return album
    }

    let album = Album(
      name: name,
      releaseDate: releaseDate,
      albumArt: image,
      albumBackground: background,
      albumBackgroundStyleVersion: backgroundStyleVersion,
      dominantColorHex: dominantColorHex,
      dominantColorHexes: dominantColorHexes,
      isDark: isDark,
      CDs: [],
      artist: artist
    )

    context.insert(album)
    return album
  }
}
