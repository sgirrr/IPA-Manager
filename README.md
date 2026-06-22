# IPA Manager

Upload IPAs wirelessly from PC → manage like an App Store → install on iPhone.

## Features
- **Wireless Upload** — start a server on iPhone, drop IPAs from any PC browser
- **App Store UI** — browse, search, view details
- **Edit** — rename, change Bundle ID, version
- **Duplicate** — create modified copies with unique Bundle IDs (install alongside originals)
- **Install** — TrollStore, appinst (jailbreak), or export

## How to Build

### Prerequisites
- macOS + Xcode 14+
- Apple Developer account (free is fine)
- **Swift Package Manager dependencies** (add in Xcode):
  - https://github.com/weichsel/ZIPFoundation (for IPA zip manipulation)

### Steps

1. Clone / copy all Swift files into an Xcode project:
   - Create new Xcode project → iOS → App (SwiftUI)
   - Replace generated files with the source files from this repo
   - Add ZIPFoundation via File → Add Packages

2. Add Info.plist:
   - Copy `Sources/IPAManager/Info.plist` into your Xcode project
   - Make sure it's listed in target settings under Info → Custom iOS Target Properties

3. Signing:
   - In Xcode: Target → Signing & Capabilities → select your Team
   - Bundle Identifier: use something unique like `com.yourname.ipamanager`

4. Build & Run:
   - Connect your iPhone via USB (or use wireless debugging)
   - Select your device as the target
   - Press Cmd+R

### Sideload (no Xcode)
Build the app in Xcode, then:
- Product → Archive → Distribute App → Development
- Save IPA and sideload via AltStore, Sideloadly, or TrollStore

## Usage

1. Open IPA Manager on iPhone
2. Tap **Upload** tab → tap **Start Server**
3. Note the URL shown (e.g., `http://192.168.1.5:8080`)
4. On your PC, open that URL in a browser
5. Drag & drop .ipa files into the browser window
6. Switch to the **Store** tab — your apps appear instantly
7. Tap an app → Edit properties, Duplicate, or get Install instructions

## Notes
- PC and iPhone must be on the **same Wi-Fi network**
- IPA modification (rename, bundle ID change) requires the file to be re-signed before installation on non-jailbroken devices
- For jailbroken devices, `appinst` installs directly
- For TrollStore, use the Share sheet
