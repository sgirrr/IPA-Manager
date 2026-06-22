import SwiftUI

struct ContentView: View {
    @EnvironmentObject var ipaManager: IPAManagerService
    @EnvironmentObject var signingService: SigningService

    var body: some View {
        TabView {
            StoreView()
                .tabItem {
                    Image(systemName: "square.grid.3x3.fill")
                    Text("Store")
                }

            UploadView()
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Upload")
                }

            CertificatesView()
                .tabItem {
                    Image(systemName: "certificate.fill")
                    Text("Signing")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .accentColor(Color(red: 0.914, green: 0.271, blue: 0.376))
        .preferredColorScheme(.dark)
    }
}
