import UIKit

/// File-backed storage for reflection photos (the Phase 3 mechanism the spec describes).
/// Images are re-encoded to JPEG and written into a `DayPhotos` folder in the app's
/// documents directory; only the generated filename is stored on `DayEntry.photoFilenames`.
///
/// Photos are deliberately device-local — they are NOT carried over WatchConnectivity
/// (see `SyncMerger`), so a filename always resolves to a real file on the device that
/// captured it.
enum PhotoStorage {
    /// `DayPhotos` under the documents directory, created on first access.
    private static var directory: URL {
        let dir = URL.documentsDirectory.appending(path: "DayPhotos")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(for filename: String) -> URL {
        directory.appending(path: filename)
    }

    /// Re-encode `image` to JPEG and write it under a fresh UUID filename. Returns the
    /// filename to persist, or nil if encoding/writing failed.
    static func save(_ image: UIImage, quality: CGFloat = 0.8) -> String? {
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: url(for: filename), options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    static func load(_ filename: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: filename).path)
    }

    static func delete(_ filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
    }
}
