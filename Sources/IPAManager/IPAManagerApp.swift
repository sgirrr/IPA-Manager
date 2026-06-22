import SwiftUI

@main
struct IPAManagerApp: App {
    @StateObject private var ipaManager = IPAManagerService()
    @StateObject private var serverManager = HTTPServerManager()
    @StateObject private var signingService = SigningService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ipaManager)
                .environmentObject(serverManager)
                .environmentObject(signingService)
                .onAppear {
                    serverManager.onFileReceived = { url in
                        _ = ipaManager.saveIPA(from: url)
                    }
                }
        }
    }
}
