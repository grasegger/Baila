import Foundation

enum AppFiles {

    /// URL to the app's Documents directory.
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Ensures that the app-specific folder exists in the Documents directory.
    /// - Throws: Propagates FileManager errors if creation fails.
    @discardableResult
    static func ensureAppFolderExists() throws -> URL {
        let url = documentsDirectory
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) || !isDir.boolValue {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    /// Creates a tiny placeholder file so the Files app shows the container immediately.
    static func ensurePlaceholderFile() {
        let placeholderURL = documentsDirectory.appendingPathComponent("Put music here.txt")
        if !FileManager.default.fileExists(atPath: placeholderURL.path) {
            let data = "Put your music here!"
            try? data.write(to: placeholderURL, atomically: true, encoding: .utf8)
        }
    }
}
