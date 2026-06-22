import Foundation

class SigningService: ObservableObject {
    @Published var certificates: [Certificate] = []
    @Published var lastSignResult: String = ""

    private var docsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var certsDirectory: URL {
        docsURL.appendingPathComponent("Certs", isDirectory: true)
    }

    private var metadataURL: URL {
        docsURL.appendingPathComponent("cert_metadata.json")
    }

    init() {
        try? FileManager.default.createDirectory(at: certsDirectory, withIntermediateDirectories: true)
        loadMetadata()
    }

    func importCertificate(p12URL: URL, provisionURL: URL? = nil, password: String = "") -> Bool {
        let fileName = p12URL.lastPathComponent
        let dest = certsDirectory.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: p12URL, to: dest)

            var provisionFile: String?
            if let provURL = provisionURL {
                let provName = provURL.lastPathComponent
                let provDest = certsDirectory.appendingPathComponent(provName)
                if FileManager.default.fileExists(atPath: provDest.path) {
                    try FileManager.default.removeItem(at: provDest)
                }
                try FileManager.default.copyItem(at: provURL, to: provDest)
                provisionFile = provName
            }

            let teamID = extractTeamID(from: dest) ?? "unknown"
            var expDate = Date().addingTimeInterval(365 * 86400)
            if let provName = provisionFile {
                let provURL = certsDirectory.appendingPathComponent(provName)
                expDate = extractExpirationDate(from: provURL) ?? expDate
            }

            let cert = Certificate(
                id: UUID(),
                name: fileName.replacingOccurrences(of: ".p12", with: ""),
                p12FileName: fileName,
                mobileProvisionFileName: provisionFile,
                teamID: teamID,
                expirationDate: expDate,
                createdAt: Date()
            )
            certificates.append(cert)
            saveMetadata()
            return true
        } catch {
            lastSignResult = "Import failed: \(error.localizedDescription)"
            return false
        }
    }

    func removeCertificate(_ cert: Certificate) {
        try? FileManager.default.removeItem(atPath: cert.p12Path)
        if let prov = cert.provisionPath {
            try? FileManager.default.removeItem(at: prov)
        }
        certificates.removeAll { $0.id == cert.id }
        saveMetadata()
    }

    func signIPA(ipaPath: String, certificate: Certificate, newBundleID: String? = nil) -> String {
        let isJailbroken = FileManager.default.fileExists(atPath: "/var/jb") ||
                           FileManager.default.fileExists(atPath: "/usr/bin/ldid")

        guard isJailbroken else {
            lastSignResult = "⚠️ On-device signing requires a jailbroken device, TrollStore, or a PC with iOS App Signer."
            return lastSignResult
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let ipaURL = URL(fileURLWithPath: ipaPath)
        let ipaName = ipaURL.lastPathComponent
        let outputPath = docsURL.appendingPathComponent("IPAs/signed_\(ipaName)").path

        let script = """
        #!/bin/bash
        cd /tmp
        rm -rf "signed_temp"
        mkdir "signed_temp"
        unzip -q "\(ipaPath)" -d "signed_temp/" 2>/dev/null

        APP=$(ls "signed_temp/Payload/" 2>/dev/null | head -1)
        [ -z "$APP" ] && { echo "No .app found"; exit 1; }

        \(newBundleID != nil ? "/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier \(newBundleID!)' \"signed_temp/Payload/$APP/Info.plist\" 2>/dev/null" : "")

        cp "\(certificate.provisionPath ?? "")" "signed_temp/Payload/$APP/embedded.mobileprovision" 2>/dev/null

        ldid -S "signed_temp/Payload/$APP/\(certificate.p12FileName)" 2>/dev/null || \\
        ldid2 -S "signed_temp/Payload/$APP/\(certificate.p12FileName)" 2>/dev/null || \\
        echo "ldid failed — install ldid from Sileo/Cydia"

        cd signed_temp
        zip -qr "\(outputPath)" Payload/ 2>/dev/null

        echo "✅ Signed IPA: \(outputPath)"
        """

        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("sign.sh")
        do {
            try script.write(to: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath.path]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            lastSignResult = output

            if output.contains("✅") {
                return outputPath
            }
            return ""
        } catch {
            lastSignResult = "Signing failed: \(error.localizedDescription)"
            return ""
        }
    }

    // MARK: - Helpers

    private func extractTeamID(from p12URL: URL) -> String? {
        guard let archive = try? FileHandle(forReadingFrom: p12URL) else { return nil }
        let data = archive.readDataToEndOfFile()
        let hex = data.map { String(format: "%02x", $0) }.joined()
        let patterns = ["teamid", "TeamID", "team"]
        for pattern in patterns {
            if let range = hex.range(of: pattern.data(using: .utf8)!.map { String(format: "%02x", $0) }.joined()) {
                let start = hex[range.upperBound...].prefix(64)
                return String(start).data(using: .utf8).flatMap { String(data: $0, encoding: .utf8) }
            }
        }
        return nil
    }

    private func extractExpirationDate(from provisionURL: URL) -> Date? {
        guard let data = try? Data(contentsOf: provisionURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let expDate = plist["ExpirationDate"] as? Date else { return nil }
        return expDate
    }

    // MARK: - Persistence

    private func saveMetadata() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(certificates) {
            try? data.write(to: metadataURL)
        }
    }

    private func loadMetadata() {
        guard let data = try? Data(contentsOf: metadataURL) else { return }
        certificates = (try? JSONDecoder().decode([Certificate].self, from: data)) ?? []
    }
}
