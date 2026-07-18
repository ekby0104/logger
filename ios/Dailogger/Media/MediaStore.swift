import Foundation
import UIKit

/// Persists moment media in Documents/Moments; SwiftData stores only file names.
enum MediaStore {
    static var momentsDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("Moments", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func persistVideo(from tempURL: URL, id: UUID) -> String? {
        let name = "\(id.uuidString).mov"
        let destination = momentsDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: tempURL, to: destination)
            return name
        } catch {
            return nil
        }
    }

    static func persistThumbnail(_ image: UIImage, id: UUID) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let name = "\(id.uuidString).jpg"
        do {
            try data.write(to: momentsDirectory.appendingPathComponent(name))
            return name
        } catch {
            return nil
        }
    }

    static func deleteFile(named fileName: String?) {
        guard let fileName, !fileName.isEmpty else { return }
        try? FileManager.default.removeItem(at: momentsDirectory.appendingPathComponent(fileName))
    }

    static func url(fileName: String?) -> URL? {
        guard let fileName, !fileName.isEmpty else { return nil }
        let url = momentsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
