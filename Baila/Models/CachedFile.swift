import CryptoKit
import Foundation
import SwiftData

@Model
final class CachedFile {
    @Attribute(.unique) var id: UUID
    private var path: String
    var fileId: Int64
    var track: Track?
    
    var filePath : URL {
        Self.documentsDirectory.appendingPathComponent(path)
    }

    nonisolated init(id: UUID = UUID(), filePath: URL, fileId: Int64, track: Track?) {
        self.id = id
        self.path = Self.relativePath(for: filePath)
        self.track = track
        self.fileId = fileId
    }

    static func getOrCreate(filePath: URL, fileId: Int64, track: Track, context: ModelContext) throws -> CachedFile {
        let descriptor = FetchDescriptor<CachedFile>(
            predicate: #Predicate { $0.fileId == fileId
            })

        let result = try context.fetch(descriptor)

        if let cached = result.first {
            cached.track = track
            return cached
        }
        return CachedFile(
            filePath: filePath,
            fileId: fileId,
            track: track
        )
    }

    nonisolated private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    nonisolated private static func relativePath(for fileURL: URL) -> String {
        let documentURLs = [
            documentsDirectory.standardizedFileURL,
            documentsDirectory.resolvingSymlinksInPath().standardizedFileURL,
        ]
        let fileURLs = [
            fileURL.standardizedFileURL,
            fileURL.resolvingSymlinksInPath().standardizedFileURL,
        ]

        for fileURL in fileURLs {
            let filePath = fileURL.path(percentEncoded: false)
            for documentURL in documentURLs {
                let documentPath = documentURL.path(percentEncoded: false)
                guard filePath.hasPrefix(documentPath + "/") else { continue }
                return String(filePath.dropFirst(documentPath.count + 1))
            }
        }

        for fileURL in fileURLs {
            let filePath = fileURL.path(percentEncoded: false)
            guard let documentsRange = filePath.range(of: "/Documents/") else { continue }
            return String(filePath[documentsRange.upperBound...])
        }

        return fileURL.lastPathComponent
    }
}
