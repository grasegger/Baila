import Foundation
import SwiftData
import CryptoKit

@Model
final class CachedFile {
    @Attribute(.unique) var id: UUID
    var path: URL
    var checksum: String = ""
    var track: Track?

    init(id: UUID = UUID(), filePath: URL, hash: SHA256.Digest, track: Track?) {
        self.id = id
        self.path = filePath
        self.checksum = hash.map { String(format: "%02x", $0) }.joined().uppercased()
        self.track = track
    }
    
}
