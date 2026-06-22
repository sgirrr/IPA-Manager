import SwiftUI

struct UploadView: View {
    @EnvironmentObject var serverManager: HTTPServerManager

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: serverManager.isRunning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 48))
                    .foregroundColor(serverManager.isRunning ? .green : .red)
                    .padding(.top, 32)

                Text(serverManager.isRunning ? "Server Running" : "Server Stopped")
                    .font(.title2.weight(.semibold))

                if serverManager.isRunning {
                    VStack(spacing: 8) {
                        Text("Connect from your PC browser:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(serverManager.serverURL)
                            .font(.title3.weight(.bold))
                            .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
                            .textSelection(.enabled)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)

                        Link("Open in Browser", destination: URL(string: serverManager.serverURL)!)
                            .font(.subheadline)
                            .padding(.top, 4)
                    }
                }

                Divider()
                    .padding(.horizontal, 40)

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "1.circle.fill")
                            .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
                        Text("Make sure your PC is on the same Wi-Fi")
                    }
                    HStack {
                        Image(systemName: "2.circle.fill")
                            .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
                        Text("Open the URL above in your PC browser")
                    }
                    HStack {
                        Image(systemName: "3.circle.fill")
                            .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
                        Text("Drag & drop your .ipa files")
                    }
                    HStack {
                        Image(systemName: "4.circle.fill")
                            .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
                        Text("They appear instantly in your Store tab")
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, 32)

                if !serverManager.uploadMessage.isEmpty {
                    Text(serverManager.uploadMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.green)
                        .padding(10)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }

                Spacer()

                Button(action: {
                    if serverManager.isRunning {
                        serverManager.stop()
                    } else {
                        serverManager.start()
                    }
                }) {
                    Text(serverManager.isRunning ? "Stop Server" : "Start Server")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(serverManager.isRunning ? Color.red : Color(red: 0.914, green: 0.271, blue: 0.376))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            .navigationTitle("Upload")
        }
    }
}
