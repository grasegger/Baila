//
//  CD.swift
//  Baile
//
//  Created by Karl on 01.05.26.
//

import Foundation
import SwiftData

@Model
class CD {
  @Attribute(.unique) var id: UUID
  var number: Int32
  @Relationship(deleteRule: .cascade, inverse: \Track.CD) var tracks: [Track]
  var album: Album?

  init(id: UUID = UUID(), number: Int32, tracks: [Track], album: Album?) {
    self.id = id
    self.number = number
    self.tracks = tracks
    self.album = album
  }

  var sortedTracks: [Track] {
    tracks.sorted { $0.number < $1.number }
  }

  var runtime: TimeInterval {
    tracks.reduce(into: .zero) { partialResult, track in
      partialResult += track.runtime
    }
  }

  static func getOrCreate(number: Int32?, album: Album, context: ModelContext) throws -> CD {
    let number = number ?? 1

    let predicate = #Predicate<CD> {
      (cd: CD) in cd.number == number
    }
    let descriptor = FetchDescriptor<CD>(predicate: predicate)
    let results = try context.fetch(descriptor)

    let filtered = results.filter { cd in
      if let cdAlbum = cd.album {
        return cdAlbum.persistentModelID == album.persistentModelID
      } else {
        return false
      }
    }

    if let first = filtered.first {
      return first
    }

    let cd = CD(number: number, tracks: [], album: album)
    context.insert(cd)
    return cd
  }
}
