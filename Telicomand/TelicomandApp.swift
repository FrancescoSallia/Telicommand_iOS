//
//  TelicomandApp.swift
//  Telicomand
//
//  Created by Francesco Sallia on 28.08.25.
//

import SwiftUI

@main
struct TelicomandApp: App {
    @StateObject var remote = TVRemote()
    @State var ip = "192.168.178.23"
    @State var useTLS = false

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Remote", systemImage: "appletvremote.gen4.fill") {
                    ContentView(remote: remote, ip: $ip, useTLS: $useTLS)
                }
                Tab("Connection", systemImage: "network") {
                    ConnectionView(ip: $ip, useTLS: $useTLS, remote: remote)
                }
            }
        }
    }
}
