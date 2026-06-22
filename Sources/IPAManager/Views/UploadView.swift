import SwiftUI

struct UploadView: View {
    @EnvironmentObject var serverManager: HTTPServerManager
    @StateObject private var pcSync = PCSyncService()
    @EnvironmentObject var ipaManager: IPAManagerService

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Upload Server Section
                    VStack(spacing: 16) {
                        Image(systemName: serverManager.isRunning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 40))
                            .foregroundColor(serverManager.isRunning ? .green : .red)

                        Text(serverManager.isRunning ? "Server Running" : "Server Stopped")
                            .font(.title3.weight(.semibold))

                        if serverManager.isRunning {
                            VStack(spacing: 6) {
                                Text("Open on your PC browser:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text(serverManager.serverURL)
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
                                    .textSelection(.enabled)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }

                        Button(action: {
                            if serverManager.isRunning { serverManager.stop() }
                            else { serverManager.start() }
                        }) {
                            Text(serverManager.isRunning ? "⏹ Stop Server" : "▶️ Start Server")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(serverManager.isRunning ? Color.red : Color(red: 0.914, green: 0.271, blue: 0.376))
                                .cornerRadius(10)
                        }
                    }
                    .padding(20)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)

                    // MARK: - Auto Sync Section
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.title3)
                                .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
                            Text("Auto-Sync from PC")
                                .font(.title3.weight(.bold))
                            Spacer()
                        }

                        Text("One-click download all IPAs from your PC")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if pcSync.isScanning {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Scanning network...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if !pcSync.availableIPAs.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Found \(pcSync.availableIPAs.count) IPAs on PC:")
                                    .font(.subheadline.weight(.medium))
                                ForEach(pcSync.availableIPAs) { ipa in
                                    HStack {
                                        Image(systemName: "app.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(ipa.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(ipa.sizeFormatted)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color(.systemGray5).opacity(0.5))
                            .cornerRadius(8)
                        }

                        if pcSync.syncProgress > 0 {
                            ProgressView(value: pcSync.syncProgress)
                                .tint(Color(red: 0.914, green: 0.271, blue: 0.376))
                        }

                        if !pcSync.syncMessage.isEmpty {
                            Text(pcSync.syncMessage)
                                .font(.subheadline)
                                .foregroundColor(pcSync.syncMessage.contains("✅") ? .green : .secondary)
                        }

                        HStack(spacing: 12) {
                            Button {
                                pcSync.scanNetwork()
                            } label: {
                                Label("Scan", systemImage: "magnifyingglass")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                            }
                            .disabled(pcSync.isScanning)

                            Button {
                                pcSync.syncAll { url in
                                    ipaManager.importIPA(from: url)
                                } completion: { _ in }
                            } label: {
                                Label("Sync All", systemImage: "arrow.down.circle")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.914, green: 0.271, blue: 0.376))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .disabled(pcSync.availableIPAs.isEmpty || pcSync.isScanning)
                        }
                    }
                    .padding(20)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)

                    // MARK: - Instructions
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
                            Text("How to Auto-Sync")
                                .font(.subheadline.weight(.semibold))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            InstructionRow(num: "1", text: "Run serve-ipas.ps1 on your PC (from the project folder)")
                            InstructionRow(num: "2", text: "Make sure PC and iPhone are on the same Wi-Fi")
                            InstructionRow(num: "3", text: "Tap Scan to find your PC")
                            InstructionRow(num: "4", text: "Tap Sync All — all IPAs download automatically")
                        }
                    }
                    .padding(20)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Upload")
        }
    }
}

struct InstructionRow: View {
    let num: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(num)
                .font(.caption.weight(.bold))
                .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
                .frame(width: 18, height: 18)
                .background(Color(red: 0.914, green: 0.271, blue: 0.376).opacity(0.15))
                .clipShape(Circle())
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
