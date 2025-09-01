//
//  ConnectionView.swift
//  Telicomand
//
//  Created by Francesco Sallia on 31.08.25.
//

import SwiftUI

struct ConnectionView: View {
    @Binding var ip: String
    @Binding var useTLS: Bool
    @ObservedObject var remote: TVRemote

    var body: some View {
        
        VStack {
            Form {
                Section("Verbindung") {
                    TextField("TV-IP z. B. 192.168.178.23", text: $ip)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("TLS (wss:// :8002) – nur falls 8001 blockiert", isOn: $useTLS)
                    
                    Button("Verbinden") {
                        let savedToken = UserDefaults.standard.string(forKey: "tv_token_\(ip)")
                        remote.connect(to: ip, useTLS: true, token: savedToken)
                    }
                    Button("Trennen") { remote.disconnect() }
                    
                    statusView
                }
            }
        }
        
}
    
    private var statusView: some View {
        switch remote.state {
        case .disconnected:
            return Text("Status: getrennt").foregroundStyle(.secondary)
        case .connecting:
            return Text("Status: verbinde…").foregroundStyle(.secondary)
        case .connected(let tok):
            return Text("Verbunden \(tok != nil ? "• Token gespeichert" : "")").foregroundStyle(.green)
        }
    }
}

//#Preview {
//    ConnectionView()
//}
