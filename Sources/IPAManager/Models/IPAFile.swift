import Foundation

struct IPAFile: Identifiable, Codable {
    let id: UUID
    var fileName: String
    var displayName: String
    var bundleID: String
    var version: String
    var originalSize: Int64
    var isDuplicate: Bool
    var sourceIPAID: UUID?
    var createdAt: Date

    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: originalSize)
    }

    var filePath: String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("IPAs/\(fileName)").path
    }

    init(fileName: String, displayName: String = "", bundleID: String = "", version: String = "1.0") {
        self.id = UUID()
        self.fileName = fileName
        self.displayName = displayName
        self.bundleID = bundleID
        self.version = version
        self.originalSize = 0
        self.isDuplicate = false
        self.sourceIPAID = nil
        self.createdAt = Date()
    }
}
