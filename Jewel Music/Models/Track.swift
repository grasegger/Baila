//
//  Track.swift
//  Baile
//
//  Created by Karl on 01.05.26.
//

import Foundation
import SwiftData

@Model
class Track {
    @Attribute(.unique) var id: UUID
    var name: String
    var artist: String
    var number: Int32
    var CD: CD?
    var file: CachedFile?
    
    init(id: UUID = UUID(), name: String, artist: String, number: Int32, CD: CD?, file: CachedFile?) {
        self.id = id
        self.name = name
        self.artist = artist
        self.number = number
        self.CD = CD
        self.file = file
    }
}
