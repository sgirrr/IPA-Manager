import SwiftUI

struct StoreView: View {
    @EnvironmentObject var ipaManager: IPAManagerService
    @State private var selectedIPA: IPAFile?
    @State private var showDetail = false
    @State private var searchText = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showFilePicker = false
    @State private var selectedCategory = "All"

    let categories = ["All", "Recently Added", "Duplicates"]

    var filteredIPAs: [IPAFile] {
        var result = ipaManager.ipas
        switch selectedCategory {
        case "Recently Added":
            result.sort { $0.createdAt > $1.createdAt }
        case "Duplicates":
            result = result.filter { $0.isDuplicate }
        default: break
        }
        if !searchText.isEmpty {
            result = result.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var featuredIPAs: [IPAFile] {
        Array(ipaManager.ipas.sorted { $0.createdAt > $1.createdAt }.prefix(3))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !ipaManager.ipas.isEmpty && searchText.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.self) { cat in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = cat }
                                } label: {
                                    Text(cat)
                                        .font(.subheadline.weight(selectedCategory == cat ? .bold : .medium))
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == cat ? Color(red: 0.914, green: 0.271, blue: 0.376) : Color(.systemGray6))
                                        .foregroundColor(selectedCategory == cat ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }

                ScrollView {
                    VStack(spacing: 0) {
                        if ipaManager.ipas.isEmpty {
                            emptyState
                        } else {
                            if searchText.isEmpty && selectedCategory == "All" {
                                featuredSection
                            }
                            appsGrid
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search apps...")
            }
            .background(Color(.systemBackground))
            .navigationTitle("My Store")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showFilePicker = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.caption2)
                            .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
                        Text("\(ipaManager.ipas.count)")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        if url.lastPathComponent.hasSuffix(".ipa") {
                            if ipaManager.importIPA(from: url) {
                                alertMessage = "✅ \(url.lastPathComponent) imported"
                            } else {
                                alertMessage = "⚠️ Failed to import"
                            }
                        } else {
                            alertMessage = "⚠️ Select an .ipa file"
                        }
                        showAlert = true
                    }
                case .failure(let error):
                    alertMessage = error.localizedDescription
                    showAlert = true
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

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Featured")
                    .font(.title2.weight(.bold))
                Spacer()
                Text("View All")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(featuredIPAs) { ipa in
                        FeaturedCard(ipa: ipa)
                            .onTapGesture {
                                selectedIPA = ipa
                                showDetail = true
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private var appsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 16) {
            ForEach(filteredIPAs) { ipa in
                AppGridCard(ipa: ipa)
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
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 100, height: 100)
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
            }
            VStack(spacing: 8) {
                Text("No Apps Yet")
                    .font(.title2.weight(.bold))
                Text("Import IPAs from Files or upload wirelessly\nfrom the Upload tab")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showFilePicker = true
            } label: {
                Label("Import from Files", systemImage: "doc.badge.plus")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.914, green: 0.271, blue: 0.376))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func duplicateIPA(_ ipa: IPAFile) {
        let newID = ipa.bundleID + ".duplicate"
        let newName = ipa.displayName + " (2)"
        if ipaManager.duplicateIPA(ipa, newBundleID: newID, newName: newName) {
            alertMessage = "✅ \(ipa.displayName) duplicated!"
            showAlert = true
        }
    }
}

// MARK: - Featured Card

struct FeaturedCard: View {
    let ipa: IPAFile

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: gradientColors(for: ipa.displayName),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 200, height: 120)

                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "app.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text(ipa.displayName)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(ipa.sizeFormatted)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(12)
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    func gradientColors(for name: String) -> [Color] {
        let palettes: [[Color]] = [
            [.blue, .purple], [.orange, .pink], [.green, .teal],
            [.indigo, .blue], [.purple, .pink], [.red, .orange],
            [.teal, .blue], [.pink, .purple]
        ]
        let hash = abs(name.hashValue) % palettes.count
        return palettes[hash]
    }
}

// MARK: - Grid Card

struct AppGridCard: View {
    let ipa: IPAFile

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: gradientColors(for: ipa.displayName),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .aspectRatio(1, contentMode: .fit)
                VStack(spacing: 6) {
                    Image(systemName: "app.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    Text(ipa.displayName.prefix(10))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(ipa.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(ipa.version)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if ipa.isDuplicate {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                HStack {
                    Text(ipa.sizeFormatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("GET")
                        .font(.caption.weight(.heavy))
                        .foregroundColor(Color(red: 0.914, green: 0.271, blue: 0.376))
                }
            }
        }
    }

    func gradientColors(for name: String) -> [Color] {
        let palettes: [[Color]] = [
            [.blue, .purple], [.orange, .pink], [.green, .teal],
            [.indigo, .blue], [.purple, .pink], [.red, .orange],
            [.teal, .blue], [.pink, .purple]
        ]
        let hash = abs(name.hashValue) % palettes.count
        return palettes[hash]
    }
}
