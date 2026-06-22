import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var ipaManager: IPAManagerService
    @State private var showClearConfirm = false

    var body: some View {
        NavigationView {
            Form {
                Section("Storage") {
                    HStack {
                        Label("Installed Apps", systemImage: "square.grid.3x3.fill")
                        Spacer()
                        Text("\(ipaManager.ipas.count)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Total Size", systemImage: "internaldrive.fill")
                        Spacer()
                        Text(totalSizeFormatted)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Tools") {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Clear All Apps", systemImage: "trash.fill")
                            .foregroundColor(.red)
                    }
                }

                Section("How to Install") {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("TrollStore", systemImage: "1.circle.fill")
                            .font(.subheadline.weight(.medium)) +
                        Text(" - Open the IPA in TrollStore via Share sheet, tap Install")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("Jailbreak (appinst)", systemImage: "2.circle.fill")
                            .font(.subheadline.weight(.medium)) +
                        Text(" - SSH into your device, run: appinst /path/to/file.ipa")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("AltStore / Sideloadly", systemImage: "3.circle.fill")
                            .font(.subheadline.weight(.medium)) +
                        Text(" - Download IPA to PC via Upload tab, then sideload with your tool")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IPA Manager").font(.subheadline.weight(.semibold))
                        Text("Upload, manage, and install IPA files wirelessly. Built for iOS.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Clear All?", isPresented: $showClearConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    for ipa in ipaManager.ipas {
                        ipaManager.deleteIPA(ipa)
                    }
                }
            } message: {
                Text("This will delete all uploaded IPAs from the device.")
            }
        }
    }

    private var totalSizeFormatted: String {
        let total = ipaManager.ipas.reduce(0) { $0 + $1.originalSize }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: total)
    }
}
