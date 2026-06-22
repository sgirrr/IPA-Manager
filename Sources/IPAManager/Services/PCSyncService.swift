import Foundation

class PCSyncService: ObservableObject {
    @Published var discoveredServers: [String] = []
    @Published var availableIPAs: [PCIPA] = []
    @Published var isScanning = false
    @Published var syncMessage = ""
    @Published var syncProgress: Double = 0
    @Published var manualIP: String = ""

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

        let baseIPs = [
            "192.168.1.", "192.168.0.", "192.168.2.", "192.168.8.",
            "192.168.10.", "192.168.100.", "192.168.178.",
            "10.0.0.", "10.0.1.", "172.16.0.", "172.20.10."
        ]
        let group = DispatchGroup()

        for base in baseIPs {
            for i in 1...20 {
                let ip = "\(base)\(i)"
                let url = URL(string: "http://\(ip):8080/api/list")!
                group.enter()
                URLSession.shared.dataTask(with: url) { data, resp, err in
                    defer { group.leave() }
                    if let data = data,
                       let json = try? JSONDecoder().decode([PCIPADTO].self, from: data),
                       !json.isEmpty {
                        DispatchQueue.main.async {
                            if !self.discoveredServers.contains(ip) {
                                self.discoveredServers.append(ip)
                            }
                            for item in json {
                                if !self.availableIPAs.contains(where: { $0.name == item.name && $0.downloadURL.contains(ip) }) {
                                    self.availableIPAs.append(PCIPA(
                                        name: item.name,
                                        size: item.size,
                                        downloadURL: "http://\(ip):8080\(item.path)"
                                    ))
                                }
                            }
                        }
                    }
                }.resume()
            }
        }

        group.notify(queue: .main) {
            self.isScanning = false
            if self.discoveredServers.isEmpty {
                self.syncMessage = "⚠️ لم يتم العثور على السيرفر. أدخل IP يدوياً أو تأكد من تشغيل serve-ipas.ps1"
            } else {
                self.syncMessage = "✅ تم العثور على \(self.discoveredServers.count) سيرفر, \(self.availableIPAs.count) تطبيق"
            }
        }
    }

    func connectManual() {
        guard !manualIP.isEmpty else {
            syncMessage = "⚠️ أدخل عنوان IP"
            return
        }
        let ip = manualIP.trimmingCharacters(in: .whitespaces)
        let urlStr = "http://\(ip):8080/api/list"
        guard let url = URL(string: urlStr) else {
            syncMessage = "⚠️ IP غير صحيح"
            return
        }

        isScanning = true
        availableIPAs = []
        discoveredServers = []

        URLSession.shared.dataTask(with: url) { data, resp, err in
            DispatchQueue.main.async {
                self.isScanning = false
                if let data = data, let json = try? JSONDecoder().decode([PCIPADTO].self, from: data), !json.isEmpty {
                    self.discoveredServers.append(ip)
                    for item in json {
                        self.availableIPAs.append(PCIPA(
                            name: item.name,
                            size: item.size,
                            downloadURL: "http://\(ip):8080\(item.path)"
                        ))
                    }
                    self.syncMessage = "✅ متصل! \(json.count) تطبيق"
                } else {
                    self.syncMessage = "⚠️ لا يوجد سيرفر على \(ip):8080"
                }
            }
        }.resume()
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
