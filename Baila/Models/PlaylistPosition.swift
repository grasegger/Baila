//
//  PlaylistPosition.swift
//  Baila
//
//  Created by Karl on 03.05.26.
//

import Foundation
import SwiftData

@Model
class PlaylistPosition {
  @Attribute(.unique) var id: UUID
  var position: Int
  @Relationship(
    deleteRule: .nullify,
    inverse: \Track.playlistPosition
  ) var track: Track?

  init(id: UUID = UUID(), position: Int, track: Track?) {
    self.id = id
    self.position = position
    self.track = track
  }
    
    var hasNext : Bool {
        return next() != nil
    }
    
    var hasPrev : Bool {
        return prev() != nil
    }

  func next() -> PlaylistPosition? {
    guard let modelContext else {
      return nil
    }

    let currentPosition = position
    var descriptor = FetchDescriptor<PlaylistPosition>(
      predicate: #Predicate { $0.position > currentPosition },
      sortBy: [SortDescriptor(\.position)]
    )
    descriptor.fetchLimit = 1

    return try? modelContext.fetch(descriptor).first
  }

  func prev() -> PlaylistPosition? {
    guard let modelContext else {
      return nil
    }

    let currentPosition = position
    var descriptor = FetchDescriptor<PlaylistPosition>(
      predicate: #Predicate { $0.position < currentPosition },
      sortBy: [SortDescriptor(\.position, order: .reverse)]
    )
    descriptor.fetchLimit = 1

    return try? modelContext.fetch(descriptor).first
  }
}
