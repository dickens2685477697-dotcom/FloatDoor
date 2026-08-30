import Foundation

/// Result of importing bytes into app-owned storage.
struct StoredFile {
    let filename: String
    let fileSize: Int64
    let contentTypeIdentifier: String?
}
