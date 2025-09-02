import SwiftUI


struct ContentView: View {
    @ObservedObject var remote: TVRemote
    @Binding var ip: String
    @Binding var useTLS: Bool
    @State private var textToSend = ""
    @State private var channelNumber = ""
    @State private var showingKeyboardSheet = false

    var body: some View {
        NavigationView {
            VStack {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        HStack {
                            Button {
                                remote.powerToggle()
                            } label: {
                                Image(systemName: "power.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                            }
                            .tint(.red)

                            if let error = remote.lastError {
                                Text("Fehler: \(error)")
                                .foregroundColor(.red)
                            }
                            Spacer()
                        }
                        .padding(.top, 30)
                        .padding(.horizontal)
                        
                        Button {
                            remote.sendKey("KEY_UP")
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 70, height: 70)
                        }
                        HStack(spacing: 40) {
                            Button {
                                remote.sendKey("KEY_LEFT")
                            } label: {
                                Image(systemName: "arrow.left.circle.fill")
                                .resizable()
                                .frame(width: 70, height: 70)
                            }
                            Button {
                                remote.sendKey("KEY_RIGHT")
                            } label: {
                                Image(systemName: "arrow.right.circle.fill")
                                .resizable()
                                .frame(width: 70, height: 70)
                            }
                        }
                        Button {
                            remote.sendKey("KEY_DOWN")
                        } label: {
                            Image(systemName: "arrow.down.circle.fill")
                            .resizable()
                            .frame(width: 70, height: 70)
                        }
                        Button("OK") {
                            remote.sendKey("KEY_ENTER")
                        }
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(Color.purple))
                        .padding()
                        
                        HStack(spacing: 20) {
                            Button("↩︎ BACK") {
                                remote.sendKey("KEY_RETURN")
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button {
                                remote.sendKey("KEY_HOME")
                            } label:{
                                Image(systemName: "house.fill")
                                .resizable()
                                .frame(width: 25, height: 25)
                                .tint(.white)
                            }
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.orange))
                        }
                    }

                    HStack {
                        VStack(spacing: 10) {
                            Button("CH ▲") { remote.sendKey("KEY_CHUP") }
                            .buttonStyle(.borderedProminent)
                            Button("CH ▼") { remote.sendKey("KEY_CHDOWN") }
                            .buttonStyle(.borderedProminent)
                        }
                        Spacer()
                        VStack(spacing: 10) {
                            Button("VOL +") { remote.sendKey("KEY_VOLUP") }
                            .buttonStyle(.borderedProminent)
                            Button("VOL −") { remote.sendKey("KEY_VOLDOWN") }
                            .buttonStyle(.borderedProminent)
                            Button("MUTE") { remote.sendKey("KEY_MUTE") }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal)

                    Button {
                        showingKeyboardSheet = true
                    } label: {
                        Image(systemName: "keyboard")
                        .resizable()
                        .frame(width: 40, height: 30)
                        .padding()
                    }
                    .sheet(isPresented: $showingKeyboardSheet) {
                        VStack {
                            TextField("Text hier tippen…", text: $textToSend)
                                .textInputAutocapitalization(.none)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding()
                            Button("Senden") {
                                remote.sendText(textToSend)
                            }
                            .buttonStyle(.borderedProminent)
                            Spacer()
                                .presentationDetents([.height(300)])
                        }
                        .padding()
                        
                    }
                }
                .padding()
                .navigationTitle("Samsung Q6 Remote")
                .navigationBarTitleDisplayMode(.inline)
            }
            .onAppear {
                Task {
                    let savedToken = UserDefaults.standard.string(forKey: "tv_token_\(ip)")
                    remote.connect(to: ip, useTLS: true, token: savedToken)
                }
            }
        }
    }
}
