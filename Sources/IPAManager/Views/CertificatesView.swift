import SwiftUI

struct CertificatesView: View {
    @EnvironmentObject var signingService: SigningService
    @State private var showImporter = false
    @State private var showProvisionsImporter = false
    @State private var selectedP12URL: URL?
    @State private var selectedProvisionURL: URL?
    @State private var showAlert = false
    @State private var alertMsg = ""

    var body: some View {
        NavigationView {
            List {
                if signingService.certificates.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "certificate.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.top, 20)
                            Text("No Certificates")
                                .font(.title3.weight(.semibold))
                            Text("Import a .p12 certificate and .mobileprovision to sign IPAs directly on-device")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    }
                }

                ForEach(signingService.certificates) { cert in
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: cert.isExpired ? "xmark.shield.fill" : "checkmark.shield.fill")
                                    .foregroundColor(cert.isExpired ? .red : .green)
                                    .font(.title3)
                                VStack(alignment: .leading) {
                                    Text(cert.name)
                                        .font(.headline)
                                    Text("Team: \(cert.teamID)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if cert.mobileProvisionFileName != nil {
                                    Image(systemName: "doc.badge.gearshape.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                }
                            }
                            HStack {
                                Label(cert.isExpired ? "Expired" : "Valid", systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(cert.isExpired ? .red : .secondary)
                                Spacer()
                                Text(cert.expirationDate, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { indexSet in
                    for i in indexSet {
                        signingService.removeCertificate(signingService.certificates[i])
                    }
                }

                Section {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import .p12 Certificate", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
                    }

                    if selectedP12URL != nil {
                        Button {
                            showProvisionsImporter = true
                        } label: {
                            Label("Import .mobileprovision", systemImage: "doc.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                Section("How to Get Certificates") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Open Xcode → Settings → Accounts → Download Manual Profiles")
                            .font(.caption)
                        Text("2. Or use a tool like iOS App Signer to export your .p12")
                            .font(.caption)
                        Text("3. For jailbreak: ldid is used automatically if available")
                            .font(.caption)
                        Text("4. For non-jailbroken: sign on PC, then upload the signed IPA")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Certificates")
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pkcs12], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        selectedP12URL = url
                        if signingService.certificates.contains(where: { $0.p12FileName == url.lastPathComponent }) {
                            alertMsg = "Certificate already imported"
                            showAlert = true
                        }
                    }
                case .failure(let error):
                    alertMsg = error.localizedDescription
                    showAlert = true
                }
            }
            .fileImporter(isPresented: $showProvisionsImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    if let p12 = selectedP12URL, let prov = urls.first {
                        if signingService.importCertificate(p12URL: p12, provisionURL: prov) {
                            alertMsg = "✅ Certificate imported successfully"
                        } else {
                            alertMsg = signingService.lastSignResult
                        }
                        selectedP12URL = nil
                        showAlert = true
                    }
                case .failure(let error):
                    alertMsg = error.localizedDescription
                    showAlert = true
                }
            }
            .alert("Certificates", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMsg)
            }
        }
    }
}
