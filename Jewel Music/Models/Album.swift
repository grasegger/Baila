//
//  Album.swift
//  Baile
//
//  Created by Karl on 01.05.26.
//

import Foundation
import SwiftData

@Model
class Album {
    @Attribute(.unique) var id: UUID
    var name: String
    var releaseDate: Date
    @Attribute(.unique) var albumArt: Data
    @Relationship(deleteRule: .cascade, inverse: \CD.album) var CDs: [CD]
    var artist: Artist?

    init(id: UUID = UUID(), name: String, releaseDate: Date, albumArt: Data, CDs: [CD], artist: Artist?) {
        self.id = id
        self.name = name
        self.releaseDate = releaseDate
        self.albumArt = albumArt
        self.CDs = CDs
        self.artist = artist
    }
}
