import SwiftUI
import UIKit

struct IPADetailView: View {
    @EnvironmentObject var ipaManager: IPAManagerService
    @EnvironmentObject var signingService: SigningService
    @State var ipa: IPAFile
    @Environment(\.dismiss) var dismiss

    @State private var editName: String
    @State private var editBundleID: String
    @State private var editVersion: String
    @State private var installMessage = ""
    @State private var showAlert = false
    @State private var showDeleteConfirm = false
    @State private var isInstalling = false
    @State private var showCertSheet = false

    private var hasCerts: Bool { !signingService.certificates.isEmpty }
    private var validCerts: [Certificate] { signingService.certificates.filter { !$0.isExpired } }

    init(ipa: IPAFile) {
        _ipa = State(initialValue: ipa)
        _editName = State(initialValue: ipa.displayName)
        _editBundleID = State(initialValue: ipa.bundleID)
        _editVersion = State(initialValue: ipa.version)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("App Info") {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 72, height: 72)
                            Image(systemName: "app.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ipa.displayName)
                                .font(.title3.weight(.bold))
                            Text(ipa.bundleID)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(ipa.sizeFormatted + " • v\(ipa.version)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                }

                Section("One-Click Install") {
                    if validCerts.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("No valid certificate", systemImage: "exclamationmark.shield.fill")
                                .foregroundColor(.orange)
                                .font(.subheadline)
                            Text("Go to the Signing tab and import a .p12 + .mobileprovision first")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("Import Certificate") {
                                showCertSheet = true
                            }
                            .font(.subheadline)
                            .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text("Using: \(validCerts[0].name)")
                                    .font(.subheadline)
                            }

                            Button {
                                oneClickInstall()
                            } label: {
                                HStack {
                                    Spacer()
                                    if isInstalling {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "arrow.down.circle.fill")
                                        Text("Sign & Install")
                                            .fontWeight(.semibold)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color(red: 0.914, green: 0.271, blue: 0.376))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(isInstalling)
                        }
                    }
                }

                Section("Edit Properties") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App Name").font(.caption).foregroundColor(.secondary)
                        TextField("Display Name", text: $editName)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bundle ID").font(.caption).foregroundColor(.secondary)
                        TextField("com.example.app", text: $editBundleID)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version").font(.caption).foregroundColor(.secondary)
                        TextField("1.0", text: $editVersion)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button("Save Changes") {
                        ipa.displayName = editName
                        ipa.bundleID = editBundleID
                        ipa.version = editVersion
                        ipaManager.updateMetadata(ipa)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
                }

                Section("Actions") {
                    Button {
                        let newID = editBundleID + ".dupe"
                        let newName = editName + " (2)"
                        if ipaManager.duplicateIPA(ipa, newBundleID: newID, newName: newName) {
                            installMessage = "✅ Duplicate created with new Bundle ID"
                            showAlert = true
                        }
                    } label: {
                        Label("Duplicate App", systemImage: "doc.on.doc")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete App", systemImage: "trash")
                    }
                }

                if ipa.isDuplicate {
                    Section {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                            Text("This is a duplicate app with a modified Bundle ID. You can install it alongside the original.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("App Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Installation", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(installMessage)
            }
            .alert("Delete App?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    ipaManager.deleteIPA(ipa)
                    dismiss()
                }
            } message: {
                Text("This will remove \(ipa.displayName) from your library. The IPA file will be deleted.")
            }
            .sheet(isPresented: $showCertSheet) {
                CertificatesView()
            }
        }
    }

    private func oneClickInstall() {
        guard !validCerts.isEmpty else {
            installMessage = "⚠️ No valid certificate available. Import one in the Signing tab."
            showAlert = true
            return
        }

        isInstalling = true
        let cert = validCerts[0]
        let ipaPath = ipaManager.ipas.first { $0.id == ipa.id }?.filePath ?? ""

        guard !ipaPath.isEmpty else {
            installMessage = "⚠️ IPA file not found"
            showAlert = true
            isInstalling = false
            return
        }

        DispatchQueue.global().async { [self] in
            let result = signingService.signIPA(
                ipaPath: ipaPath,
                certificate: cert,
                newBundleID: editBundleID != ipa.bundleID ? editBundleID : nil
            )

            DispatchQueue.main.async {
                isInstalling = false

                if !result.isEmpty {
                    let isJailbroken = FileManager.default.fileExists(atPath: "/var/jb") ||
                                       FileManager.default.fileExists(atPath: "/usr/bin/ldid")

                    if isJailbroken {
                        installAndLaunch(ipaPath: result)
                    } else {
                        // Try TrollStore URL scheme
                        let encodedPath = result.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? result
                        if let tsURL = URL(string: "trollstore://install?path=\(encodedPath)"),
                           UIApplication.shared.canOpenURL(tsURL) {
                            UIApplication.shared.open(tsURL)
                            installMessage = "✅ Opening in TrollStore..."
                        } else {
                            installMessage = """
                            ✅ IPA signed successfully!

                            Path: \(result)

                            Install via TrollStore:
                            1. Open TrollStore
                            2. Share → Open in TrollStore
                            3. Tap Install

                            Or copy to PC and use Sideloadly/AltStore
                            """
                        }
                        showAlert = true
                    }
                } else {
                    installMessage = "❌ Signing failed:\n\(signingService.lastSignResult)"
                    showAlert = true
                }
            }
        }
    }

    private func installAndLaunch(ipaPath: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "appinst \"\(ipaPath)\""]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                installMessage = """
                ✅ \(ipa.displayName) installed successfully!

                The app should appear on your home screen.
                """
            } else {
                installMessage = "⚠️ appinst failed (exit code \(process.terminationStatus)). Make sure appinst is installed from Sileo/Cydia."
            }
        } catch {
            installMessage = "⚠️ Installation failed: \(error.localizedDescription). Install appinst from Sileo/Cydia first."
        }
        showAlert = true
    }
}
