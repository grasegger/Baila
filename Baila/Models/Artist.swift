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
}
