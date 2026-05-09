//
//  Artist.swift
//  Baile
//
//  Created by Karl on 01.05.26.
//

import Foundation
import SwiftData

@Model
class Artist {
  @Attribute(.unique) var id: UUID
  @Attribute(.unique) var name: String
  @Relationship(deleteRule: .cascade, inverse: \Album.artist) var albums: [Album]

  init(id: UUID = UUID(), name: String, albums: [Album]) {
    self.id = id
    self.name = name
    self.albums = albums
  }

  public var nameWithoutThe: String {
    name.replacingOccurrences(of: "the", with: "")
          .replacingOccurrences(of: "The", with: "")
  }

  var runtime: TimeInterval {
    albums.reduce(into: .zero) { partialResult, album in
      partialResult += album.runtime
    }
  }

  static func getOrCreate(name: String?, context: ModelContext) throws -> Artist {
    let name = name ?? "Unknown Artist"

    let descriptor = FetchDescriptor<Artist>(predicate: #Predicate { $0.name == name })
    let result = try context.fetch(descriptor)

    if let artist = result.first {
      return artist
    }

    let artist = Artist(name: name, albums: [])
    context.insert(artist)
    return artist
  }
}
