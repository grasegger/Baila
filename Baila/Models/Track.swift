//
//  Track.swift
//  Baile
//
//  Created by Karl on 01.05.26.
//

import Foundation
import SwiftData
import SwiftUI

@Model
class Track {
  @Attribute(.unique) var id: UUID
  var name: String
  var artist: String
  var number: Int32
  var runtime: TimeInterval
  var CD: CD?
  var file: CachedFile?
  var playlistPosition: PlaylistPosition?

  init(
    id: UUID = UUID(),
    name: String,
    artist: String,
    number: Int32,
    runtime: TimeInterval,
    CD: CD?,
    file: CachedFile?,
    playlistPosition: PlaylistPosition?
  ) {
    self.id = id
    self.name = name
    self.artist = artist
    self.number = number
    self.runtime = runtime
    self.CD = CD
    self.file = file
    self.playlistPosition = playlistPosition
  }

  var artwork: Data? {
      return CD?.album?.albumArt
  }

  static func getOrCreate(
    title: String?,
    by artist: String?,
    number: Int32?,
    runtime: TimeInterval,
    on cd: CD,
    context: ModelContext
  ) throws -> Track {
    let number = number ?? 1
    let name = title ?? "Unknown Song"
    let artist = artist ?? "Unknown Artist"

    let predicate = #Predicate<Track> {
      track in track.name == name
    }

    let descriptor = FetchDescriptor<Track>(predicate: predicate)
    let results = try context.fetch(descriptor)

    let filtered = results.filter { track in
      if track.artist == artist && track.CD == cd {
        return true
      } else {
        return false
      }
    }

    if let track = filtered.first {
      track.runtime = runtime
      return track
    }

    return Track(
      name: name,
      artist: artist,
      number: number,
      runtime: runtime,
      CD: cd,
      file: nil,
      playlistPosition: nil
    )
  }
}
