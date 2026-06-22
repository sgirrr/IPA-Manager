import Foundation

struct Certificate: Identifiable, Codable {
    let id: UUID
    var name: String
    var p12FileName: String
    var mobileProvisionFileName: String?
    var teamID: String
    var expirationDate: Date
    var createdAt: Date

    var isExpired: Bool { Date() > expirationDate }

    var p12Path: String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Certs/\(p12FileName)").path
    }

    var provisionPath: String? {
        guard let name = mobileProvisionFileName else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Certs/\(name)").path
    }
}
