import Foundation
import Network

class HTTPServerManager: ObservableObject {
    @Published var isRunning = false
    @Published var serverURL: String = ""
    @Published var uploadMessage: String = ""
    @Published var receivedFileURL: URL?

    private var listener: TCPServer?
    private let queue = DispatchQueue(label: "httpserver.queue", qos: .background)

    var onFileReceived: ((URL) -> Void)?

    func start(port: UInt16 = 8080) {
        listener = TCPServer(port: port)
        isRunning = true
        serverURL = getIPAddress() != nil ? "http://\(getIPAddress()!):\(port)" : "http://localhost:\(port)"

        queue.async { [weak self] in
            self?.listener?.start { request, sendResponse in
                self?.handleRequest(request, sendResponse: sendResponse)
            }
        }
    }

    func stop() {
        listener?.stop()
        isRunning = false
        serverURL = ""
    }

    private func handleRequest(_ request: HTTPRequest, sendResponse: @escaping (HTTPResponse) -> Void) {
        DispatchQueue.main.async { self.uploadMessage = "" }

        if request.method == "GET" && request.path == "/" {
            let html = uploadPageHTML()
            let resp = HTTPResponse(status: 200, headers: ["Content-Type": "text/html; charset=utf-8"], body: Data(html.utf8))
            sendResponse(resp)
            return
        }

        if request.method == "POST" && request.path == "/upload" {
            guard let body = request.body, let filename = request.headers["X-Filename"] ?? extractFilename(from: request) else {
                let resp = HTTPResponse(status: 400, headers: ["Content-Type": "text/plain"], body: Data("No file".utf8))
                sendResponse(resp)
                return
            }

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let ipasDir = docs.appendingPathComponent("IPAs")
            try? FileManager.default.createDirectory(at: ipasDir, withIntermediateDirectories: true)
            let dest = ipasDir.appendingPathComponent(filename)

            do {
                try body.write(to: dest)
                DispatchQueue.main.async {
                    self.uploadMessage = "✅ \(filename) uploaded successfully!"
                    self.receivedFileURL = dest
                    self.onFileReceived?(dest)
                }
                let resp = HTTPResponse(status: 200, headers: ["Content-Type": "text/html; charset=utf-8"],
                    body: Data("""
                    <html><body style='font-family: sans-serif; text-align: center; padding: 40px; background: #1a1a2e; color: #eee;'>
                    <h2>✅ Uploaded: \(filename)</h2>
                    <a href='/' style='color: #e94560;'>Upload another</a>
                    </body></html>
                    """.utf8))
                sendResponse(resp)
                return
            } catch {
                let resp = HTTPResponse(status: 500, headers: ["Content-Type": "text/plain"], body: Data("Write failed".utf8))
                sendResponse(resp)
                return
            }
        }

        let resp = HTTPResponse(status: 404, headers: ["Content-Type": "text/plain"], body: Data("Not found".utf8))
        sendResponse(resp)
    }

    private func extractFilename(from request: HTTPRequest) -> String? {
        guard let body = request.body else { return nil }
        guard let bodyStr = String(data: body, encoding: .utf8) else { return nil }

        let pattern = #"filename="(.+?)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(bodyStr.startIndex..., in: bodyStr)
        if let match = regex.firstMatch(in: bodyStr, range: range) {
            let filenameRange = Range(match.range(at: 1), in: bodyStr)!
            return String(bodyStr[filenameRange])
        }
        return nil
    }

    private func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        return address
    }

    private func uploadPageHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>IPA Uploader</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: -apple-system, 'Segoe UI', sans-serif; background: #0f0f1a; color: #e0e0e0; min-height: 100vh; display: flex; justify-content: center; align-items: center; }
            .card { background: #1a1a2e; border-radius: 16px; padding: 40px; width: 90%; max-width: 480px; box-shadow: 0 20px 60px rgba(0,0,0,0.5); text-align: center; }
            h1 { font-size: 24px; margin-bottom: 8px; color: #fff; }
            .sub { color: #888; font-size: 14px; margin-bottom: 24px; }
            .dropzone { border: 2px dashed #333; border-radius: 12px; padding: 40px 20px; cursor: pointer; transition: all 0.3s; background: #12122a; }
            .dropzone:hover, .dropzone.dragover { border-color: #e94560; background: #1a1a35; }
            .dropzone .icon { font-size: 48px; margin-bottom: 12px; }
            .dropzone p { color: #aaa; font-size: 14px; }
            .dropzone .browse { color: #e94560; font-weight: 600; }
            input[type="file"] { display: none; }
            .progress { display: none; margin-top: 20px; }
            .progress-bar { height: 4px; background: #333; border-radius: 2px; overflow: hidden; margin-top: 8px; }
            .progress-fill { height: 100%; width: 0%; background: linear-gradient(90deg, #e94560, #0f3460); transition: width 0.3s; }
            .status { margin-top: 16px; font-size: 14px; min-height: 20px; }
            .status.success { color: #4ecca3; }
            .status.error { color: #e94560; }
            .info { margin-top: 20px; padding: 12px; background: #12122a; border-radius: 8px; font-size: 12px; color: #666; }
        </style>
        </head>
        <body>
        <div class="card">
            <h1>📦 IPA Uploader</h1>
            <p class="sub">Drop your .ipa file to upload it wirelessly</p>
            <div class="dropzone" id="dropzone">
                <div class="icon">📁</div>
                <p>Drag & drop your IPA here<br>or <span class="browse" onclick="document.getElementById('fileInput').click()">browse files</span></p>
            </div>
            <input type="file" id="fileInput" accept=".ipa">
            <div class="progress" id="progress">
                <p id="progressText">Uploading...</p>
                <div class="progress-bar"><div class="progress-fill" id="progressFill"></div></div>
            </div>
            <div class="status" id="status"></div>
            <div class="info">Connected to your iPhone — files save directly to the app</div>
        </div>
        <script>
        const dropzone = document.getElementById('dropzone');
        const fileInput = document.getElementById('fileInput');
        const progress = document.getElementById('progress');
        const progressFill = document.getElementById('progressFill');
        const progressText = document.getElementById('progressText');
        const status = document.getElementById('status');

        function upload(file) {
            if (!file.name.endsWith('.ipa')) {
                status.className = 'status error';
                status.textContent = '❌ Only .ipa files are supported';
                return;
            }
            progress.style.display = 'block';
            status.className = 'status';
            status.textContent = '';
            const formData = new FormData();
            formData.append('file', file);
            const xhr = new XMLHttpRequest();
            xhr.open('POST', '/upload', true);
            xhr.setRequestHeader('X-Filename', file.name);
            xhr.upload.onprogress = function(e) {
                if (e.lengthComputable) {
                    const pct = (e.loaded / e.total) * 100;
                    progressFill.style.width = pct + '%';
                    progressText.textContent = `Uploading... ${Math.round(pct)}%`;
                }
            };
            xhr.onload = function() {
                if (xhr.status === 200) {
                    status.className = 'status success';
                    status.textContent = '✅ Upload complete!';
                    progressFill.style.width = '100%';
                    progressText.textContent = 'Complete!';
                    setTimeout(() => { progress.style.display = 'none'; progressFill.style.width = '0%'; }, 2000);
                } else {
                    status.className = 'status error';
                    status.textContent = '❌ Upload failed';
                }
            };
            xhr.onerror = function() {
                status.className = 'status error';
                status.textContent = '❌ Network error';
            };
            xhr.send(formData);
        }

        dropzone.addEventListener('dragover', e => { e.preventDefault(); dropzone.classList.add('dragover'); });
        dropzone.addEventListener('dragleave', () => dropzone.classList.remove('dragover'));
        dropzone.addEventListener('drop', e => { e.preventDefault(); dropzone.classList.remove('dragover'); upload(e.dataTransfer.files[0]); });
        fileInput.addEventListener('change', () => { if (fileInput.files[0]) upload(fileInput.files[0]); });
        </script>
        </body>
        </html>
        """
    }
}

// MARK: - Minimal HTTP Server

class TCPServer {
    private let port: UInt16
    private var socket: Int32?
    private var running = false

    init(port: UInt16) { self.port = port }

    func start(handler: @escaping (HTTPRequest, @escaping (HTTPResponse) -> Void) -> Void) {
        running = true
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return }
        self.socket = sock

        var opt: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = CFSwapInt16HostToBig(port)
        addr.sin_addr.s_addr = INADDR_ANY

        let addrData = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
        }
        guard bind(sock, addrData, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0 else { close(sock); return }
        guard listen(sock, 5) == 0 else { close(sock); return }

        while running {
            var clientAddr = sockaddr_storage()
            var clientLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let client = accept(sock, withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
            }, &clientLen)
            guard client >= 0 else { continue }

            DispatchQueue.global().async {
                defer { close(client) }
                var data = Data()
                var buf = [UInt8](repeating: 0, count: 65536)
                var timeout = 5000
                while timeout > 0 {
                    let n = read(client, &buf, 65536)
                    if n > 0 { data.append(buf, count: n); timeout = 1000 }
                    else if n == 0 { break }
                    else { usleep(1000); timeout -= 1 }
                }
                guard !data.isEmpty else { return }
                if let request = HTTPRequest.parse(data) {
                    handler(request) { response in
                        var header = "HTTP/1.1 \(response.status) \(statusText(response.status))\r\n"
                        for (k, v) in response.headers {
                            header += "\(k): \(v)\r\n"
                        }
                        header += "Content-Length: \(response.body.count)\r\n\r\n"
                        var respData = Data(header.utf8)
                        respData.append(response.body)
                        _ = write(client, (respData as NSData).bytes.bindMemory(to: UInt8.self, capacity: respData.count), respData.count)
                    }
                }
            }
        }
    }

    func stop() {
        running = false
        if let sock = socket { close(sock); self.socket = nil }
    }
}

struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data?

    static func parse(_ data: Data) -> HTTPRequest? {
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        var lines = raw.components(separatedBy: "\r\n")
        guard lines.count >= 1 else { return nil }

        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count >= 2 else { return nil }
        let method = String(requestLine[0])
        let path = String(requestLine[1])

        var headers: [String: String] = [:]
        var i = 1
        while i < lines.count {
            let line = lines[i]
            if line.isEmpty { i += 1; break }
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                headers[String(parts[0]).trimmingCharacters(in: .whitespaces)] = String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
            i += 1
        }

        let bodyStr = lines[i..<lines.count].joined(separator: "\r\n")
        let body = bodyStr.isEmpty ? nil : Data(bodyStr.utf8)

        if let cl = headers["Content-Length"], let len = Int(cl), let _ = body, body!.count < len {
            return nil
        }

        return HTTPRequest(method: method, path: path, headers: headers, body: body)
    }
}

struct HTTPResponse {
    let status: Int
    let headers: [String: String]
    let body: Data
}

func statusText(_ status: Int) -> String {
    switch status {
    case 200: return "OK"
    case 400: return "Bad Request"
    case 404: return "Not Found"
    case 500: return "Internal Server Error"
    default: return "Unknown"
    }
}
