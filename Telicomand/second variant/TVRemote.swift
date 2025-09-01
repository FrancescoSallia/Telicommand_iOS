import Foundation
import Network

// Allows insecure SSL/TLS connections (for local/self-signed certificates)
final class InsecureURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}

final class TVRemote: ObservableObject {
    enum State { case disconnected, connecting, connected(String?) } // optional token
    @Published var state: State = .disconnected
    @Published var lastError: String?

    private var task: URLSessionWebSocketTask?
    private var session: URLSession!
    private let queue = DispatchQueue(label: "TVRemoteQueue")
    private let appNameB64: String
    private let clientIdB64: String

    private(set) var ip: String = ""
    private(set) var useTLS: Bool = false
    private(set) var token: String?

    init(appName: String = "LocalSamsungRemote") {
        self.appNameB64 = Data(appName.utf8).base64EncodedString()
        let uuid = UUID().uuidString
        self.clientIdB64 = Data(uuid.utf8).base64EncodedString()
        self.session = URLSession(
            configuration: .default,
            delegate: InsecureURLSessionDelegate(),
            delegateQueue: nil
        )
    }

    func connect(to ip: String, useTLS: Bool = false, token: String? = nil) {
        disconnect()
        self.ip = ip
        self.useTLS = useTLS
        self.token = token
        state = .connecting

        let scheme = useTLS ? "wss" : "ws"
        let port = useTLS ? 8002 : 8001

        var urlStr = "\(scheme)://\(ip):\(port)/api/v2/channels/samsung.remote.control?name=\(appNameB64)&clientid=\(clientIdB64)"
        if let token = token, !token.isEmpty {
            urlStr += "&token=\(token)"
        }
        guard let url = URL(string: urlStr) else {
            self.lastError = "Ungültige URL"
            self.state = .disconnected
            return
        }

        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        receiveLoop()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        state = .disconnected
    }

    // MARK: - Sending

    /// Pfeile, Lautstärke, Kanal etc.: KEY_* senden
    func sendKey(_ key: String) {
        let payload: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": "Click",
                "DataOfCmd": key,
                "Option": "false",
                "TypeOfRemote": "SendRemoteKey"
            ]
        ]
        send(json: payload)
    }

    /// Freitext senden (wenn auf dem TV ein Eingabefeld/On-Screen-Keyboard aktiv ist)
    func sendText(_ text: String) {
        let textB64 = Data(text.utf8).base64EncodedString()
        let payload: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": textB64,
                "TypeOfRemote": "SendInputString",
                "DataOfCmd": "base64"
            ]
        ]
        send(json: payload)
    }

    func powerToggle() {
        sendKey("KEY_POWER")
    }

    func wakeOnLan(mac: String) {
        // Remove any separators and uppercase
        let cleanMac = mac.replacingOccurrences(of: "[:\\-]", with: "", options: .regularExpression).uppercased()
        guard cleanMac.count == 12 else {
            DispatchQueue.main.async {
                self.lastError = "Ungültige MAC-Adresse"
            }
            return
        }
        var macBytes = [UInt8]()
        for i in stride(from: 0, to: 12, by: 2) {
            let byteStr = cleanMac.dropFirst(i).prefix(2)
            if let byte = UInt8(byteStr, radix: 16) {
                macBytes.append(byte)
            } else {
                DispatchQueue.main.async {
                    self.lastError = "Ungültige MAC-Adresse"
                }
                return
            }
        }

        var packet = [UInt8]()
        // 6 times 0xFF
        packet += [UInt8](repeating: 0xFF, count: 6)
        // 16 times MAC address
        for _ in 0..<16 {
            packet += macBytes
        }
        let data = Data(packet)

        let connection = NWConnection(host: NWEndpoint.Host("255.255.255.255"), port: NWEndpoint.Port(integerLiteral: 9), using: .udp)
        connection.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                DispatchQueue.main.async {
                    self.lastError = "WoL Fehler: \(error.localizedDescription)"
                }
                connection.cancel()
            }
        }
        connection.start(queue: DispatchQueue.global())
        connection.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                DispatchQueue.main.async {
                    self.lastError = "WoL Senden Fehler: \(error.localizedDescription)"
                }
            }
            connection.cancel()
        }))
    }

    private func send(json: [String: Any]) {
        queue.async {
            guard let task = self.task else { return }
            do {
                let data = try JSONSerialization.data(withJSONObject: json, options: [])
                let text = String(data: data, encoding: .utf8) ?? ""
                task.send(.string(text)) { [weak self] error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self?.lastError = error.localizedDescription
                            self?.state = .disconnected
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async { self.lastError = error.localizedDescription }
            }
        }
    }

    // MARK: - Receiving + Token capture

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.lastError = error.localizedDescription
                    self.state = .disconnected
                }
            case .success(let message):
                if case .string(let text) = message {
                    // Sehr leichter Parser nur für das Kopplungs-Event
                    if text.contains("\"event\":\"ms.channel.connect\"") {
                        // Token extrahieren falls vorhanden
                        if let tok = self.extractToken(from: text) {
                            self.token = tok
                            DispatchQueue.main.async {
                                self.state = .connected(tok)
                                UserDefaults.standard.set(tok, forKey: "tv_token_\(self.ip)")
                            }
                        } else {
                            DispatchQueue.main.async { self.state = .connected(nil) }
                        }
                    }
                }
                // weiter lauschen
                self.receiveLoop()
            }
        }
    }

    private func extractToken(from json: String) -> String? {
        // sehr grob – ausreichend zur Demo
        // Beispiel: ..."data":{"token":"12345678"}...
        guard let range = json.range(of: "\"token\":\"") else { return nil }
        let after = json[range.upperBound...]
        if let end = after.firstIndex(of: "\"") {
            return String(after[..<end])
        }
        return nil
    }
}
