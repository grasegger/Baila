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
}
