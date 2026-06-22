import SwiftUI

struct StoreView: View {
    @EnvironmentObject var ipaManager: IPAManagerService
    @State private var selectedIPA: IPAFile?
    @State private var showDetail = false
    @State private var searchText = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    var filteredIPAs: [IPAFile] {
        if searchText.isEmpty { return ipaManager.ipas }
        return ipaManager.ipas.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            Group {
                if ipaManager.ipas.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filteredIPAs) { ipa in
                            IPACardView(ipa: ipa)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .onTapGesture {
                                    selectedIPA = ipa
                                    showDetail = true
                                }
                                .contextMenu {
                                    Button { duplicateIPA(ipa) } label: {
                                        Label("Duplicate", systemImage: "doc.on.doc")
                                    }
                                    Button(role: .destructive) {
                                        ipaManager.deleteIPA(ipa)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                ipaManager.deleteIPA(filteredIPAs[i])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("My Store")
            .searchable(text: $searchText, prompt: "Search apps...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox.fill")
                            .font(.caption)
                        Text("\(ipaManager.ipas.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showDetail) {
                if let ipa = selectedIPA {
                    IPADetailView(ipa: ipa)
                }
            }
            .alert("Done", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray.full")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            Text("No Apps Yet")
                .font(.title2.weight(.semibold))
            Text("Upload IPAs wirelessly from the Upload tab,\nor drag & drop from your browser")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func duplicateIPA(_ ipa: IPAFile) {
        let newID = ipa.bundleID + ".duplicate"
        let newName = ipa.displayName + " (2)"
        if ipaManager.duplicateIPA(ipa, newBundleID: newID, newName: newName) {
            alertMessage = "✅ \(ipa.displayName) duplicated successfully!"
            showAlert = true
        }
    }
}

struct IPACardView: View {
    let ipa: IPAFile

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.7), .purple.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)
                Image(systemName: "app.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(ipa.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(ipa.bundleID)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(ipa.version)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if ipa.isDuplicate {
                        Label("Duplicate", systemImage: "doc.on.doc")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.title3)
                    .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
                Text(ipa.sizeFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
