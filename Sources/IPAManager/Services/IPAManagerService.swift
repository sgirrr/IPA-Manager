import Foundation
import ZIPFoundation

class IPAManagerService: ObservableObject {
    @Published var ipas: [IPAFile] = []

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var ipasDirectory: URL {
        documentsURL.appendingPathComponent("IPAs", isDirectory: true)
    }

    private var metadataURL: URL {
        documentsURL.appendingPathComponent("metadata.json")
    }

    init() {
        setupDirectory()
        loadMetadata()
    }

    private func setupDirectory() {
        try? FileManager.default.createDirectory(at: ipasDirectory, withIntermediateDirectories: true)
    }

    func saveIPA(from sourceURL: URL) -> Bool {
        let fileName = sourceURL.lastPathComponent
        let destURL = ipasDirectory.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)

            var info = readIPAMetadata(from: destURL)
            info.fileName = fileName
            if let attrs = try? FileManager.default.attributesOfItem(atPath: destURL.path) {
                info.originalSize = (attrs[.size] as? Int64) ?? 0
            }
            info.createdAt = Date()
            ipas.append(info)
            saveMetadata()
            return true
        } catch {
            print("Save failed: \(error)")
            return false
        }
    }

    func duplicateIPA(_ ipa: IPAFile, newBundleID: String, newName: String) -> Bool {
        guard ipas.contains(where: { $0.id == ipa.id }) else { return false }

        let originalURL = ipasDirectory.appendingPathComponent(ipa.fileName)
        let baseName = (ipa.fileName as NSString).deletingPathExtension
        let ext = (ipa.fileName as NSString).pathExtension
        let newFileName = "\(baseName)_dupe.\(ext)"
        let newURL = ipasDirectory.appendingPathComponent(newFileName)

        do {
            try FileManager.default.copyItem(at: originalURL, to: newURL)
            try modifyIPA(at: newURL, newBundleID: newBundleID, newName: newName)

            var newIPA = IPAFile(fileName: newFileName, displayName: newName, bundleID: newBundleID, version: ipa.version)
            newIPA.originalSize = ipa.originalSize
            newIPA.isDuplicate = true
            newIPA.sourceIPAID = ipa.id
            newIPA.createdAt = Date()
            ipas.append(newIPA)
            saveMetadata()
            return true
        } catch {
            try? FileManager.default.removeItem(at: newURL)
            return false
        }
    }

    func deleteIPA(_ ipa: IPAFile) {
        let url = ipasDirectory.appendingPathComponent(ipa.fileName)
        try? FileManager.default.removeItem(at: url)
        ipas.removeAll { $0.id == ipa.id }
        saveMetadata()
    }

    func updateMetadata(_ ipa: IPAFile) {
        guard let index = ipas.firstIndex(where: { $0.id == ipa.id }) else { return }
        ipas[index] = ipa
        saveMetadata()
    }

    func installIPA(_ ipa: IPAFile) -> String {
        let path = ipasDirectory.appendingPathComponent(ipa.fileName).path
        return """
        install instructions for \(ipa.displayName):
        
        Path: \(path)
        
        Jailbroken (via SSH/terminal):
        appinst "\(path)"
        
        TrollStore:
        Open TrollStore → Share → Open in TrollStore
        
        AltStore / Sideloadly:
        Transfer IPA to PC via the upload server, then sideload normally.
        """
    }

    // MARK: - IPA Modification

    private func modifyIPA(at url: URL, newBundleID: String, newName: String) throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try FileManager.default.unzipItem(at: url, to: tempDir)

        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        guard let payloadDir = contents.first(where: { $0.lastPathComponent == "Payload" }) else { return }
        let apps = try FileManager.default.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil)
        guard let appDir = apps.first(where: { $0.pathExtension == "app" }) else { return }

        let plistURL = appDir.appendingPathComponent("Info.plist")
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return }

        var plistData = try Data(contentsOf: plistURL)
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard var plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: &format) as? [String: Any] else { return }

        plist["CFBundleIdentifier"] = newBundleID
        plist["CFBundleDisplayName"] = newName
        plist["CFBundleName"] = newName

        plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: plistURL)

        try FileManager.default.zipItem(at: tempDir, to: url, shouldKeepParent: true)
    }

    private func readIPAMetadata(from url: URL) -> IPAFile {
        var ipa = IPAFile(fileName: url.lastPathComponent)

        guard let archive = try? Archive(url: url, accessMode: .read) else { return ipa }

        let infoPlistPath = archive.first { $0.path.hasSuffix(".app/Info.plist") || $0.path.hasSuffix(".app/Info.plist") }
        if let entry = infoPlistPath {
            var plistData = Data()
            _ = try? archive.extract(entry) { data in
                plistData.append(data)
            }
            if let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                ipa.displayName = (plist["CFBundleDisplayName"] as? String) ??
                                   (plist["CFBundleName"] as? String) ??
                                   (url.lastPathComponent as NSString).deletingPathExtension
                ipa.bundleID = (plist["CFBundleIdentifier"] as? String) ?? "com.unknown"
                ipa.version = (plist["CFBundleShortVersionString"] as? String) ?? "1.0"
            }
        }
        return ipa
    }

    // MARK: - Import from Files

    func importIPA(from url: URL) -> Bool {
        return saveIPA(from: url)
    }

    var availableIPAsCount: Int { ipas.count }

    private func saveMetadata() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(ipas) {
            try? data.write(to: metadataURL)
        }
    }

    private func loadMetadata() {
        guard let data = try? Data(contentsOf: metadataURL) else { return }
        ipas = (try? JSONDecoder().decode([IPAFile].self, from: data)) ?? []
    }
}
