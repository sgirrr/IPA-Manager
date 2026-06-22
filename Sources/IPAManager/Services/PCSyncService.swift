import Foundation

class PCSyncService: ObservableObject {
    @Published var discoveredServers: [String] = []
    @Published var availableIPAs: [PCIPA] = []
    @Published var isScanning = false
    @Published var syncMessage = ""
    @Published var syncProgress: Double = 0

    struct PCIPA: Identifiable {
        let id = UUID()
        let name: String
        let size: Int64
        let downloadURL: String
        var sizeFormatted: String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: size)
        }
    }

    func scanNetwork() {
        isScanning = true
        discoveredServers = []
        availableIPAs = []

        // Common local IPs to scan
        let baseIPs = ["192.168.1.", "192.168.0.", "10.0.0."]
        let group = DispatchGroup()

        for base in baseIPs {
            for i in 1...10 {
                let ip = "\(base)\(i)"
                let url = URL(string: "http://\(ip):8080/api/list")!
                group.enter()
                URLSession.shared.dataTask(with: url) { data, resp, err in
                    defer { group.leave() }
                    if let data = data, let json = try? JSONDecoder().decode([PCIPADTO].self, from: data) {
                        DispatchQueue.main.async {
                            self.discoveredServers.append(ip)
                            for item in json {
                                self.availableIPAs.append(PCIPA(
                                    name: item.name,
                                    size: item.size,
                                    downloadURL: "http://\(ip):8080\(item.path)"
                                ))
                            }
                        }
                    }
                }.resume()
            }
        }

        group.notify(queue: .main) {
            self.isScanning = false
            if self.discoveredServers.isEmpty {
                self.syncMessage = "⚠️ No PC server found. Run serve-ipas.ps1 on PC"
            } else {
                self.syncMessage = "✅ Found \(self.discoveredServers.count) server(s), \(self.availableIPAs.count) IPA(s)"
            }
        }
    }

    func syncAll(importHandler: @escaping (URL) -> Bool, completion: @escaping (Int) -> Void) {
        guard !availableIPAs.isEmpty else {
            syncMessage = "⚠️ No IPAs to sync. Scan network first."
            completion(0)
            return
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let ipasDir = docs.appendingPathComponent("IPAs")
        try? FileManager.default.createDirectory(at: ipasDir, withIntermediateDirectories: true)

        var imported = 0
        let total = availableIPAs.count
        let group = DispatchGroup()

        for (index, ipa) in availableIPAs.enumerated() {
            guard let url = URL(string: ipa.downloadURL) else { continue }
            group.enter()
            URLSession.shared.downloadTask(with: url) { localURL, resp, err in
                defer { group.leave() }
                if let localURL = localURL {
                    let dest = ipasDir.appendingPathComponent(ipa.name)
                    try? FileManager.default.removeItem(at: dest)
                    try? FileManager.default.moveItem(at: localURL, to: dest)
                    if importHandler(dest) {
                        imported += 1
                    }
                }
                DispatchQueue.main.async {
                    self.syncProgress = Double(index + 1) / Double(total)
                }
            }.resume()
        }

        group.notify(queue: .main) {
            self.syncMessage = "✅ Imported \(imported)/\(total) IPAs"
            self.syncProgress = 0
            completion(imported)
        }
    }
}

struct PCIPADTO: Codable {
    let name: String
    let size: Int64
    let path: String
}
