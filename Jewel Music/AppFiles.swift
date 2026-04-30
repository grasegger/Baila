import Foundation

enum AppFiles {
    // Name of the subfolder we want inside the app's Documents directory
    static let appFolderName = "AppData"

    /// URL to the app's Documents directory.
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// URL to the app-specific working folder inside Documents (created on demand).
    static var appFolderURL: URL {
        documentsDirectory.appendingPathComponent(appFolderName, isDirectory: true)
    }

    /// Ensures that the app-specific folder exists in the Documents directory.
    /// - Throws: Propagates FileManager errors if creation fails.
    @discardableResult
    static func ensureAppFolderExists() throws -> URL {
        let url = appFolderURL
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) || !isDir.boolValue {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    /// Creates a tiny placeholder file so the Files app shows the container immediately.
    static func ensurePlaceholderFile() {
        let placeholderURL = appFolderURL.appendingPathComponent(".keep")
        if !FileManager.default.fileExists(atPath: placeholderURL.path) {
            let data = Data() // empty file
            try? data.write(to: placeholderURL)
        }
    }
}
