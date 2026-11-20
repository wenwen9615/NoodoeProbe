import SwiftUI

struct EAView: View {
    @ObservedObject var probe: EAProbe

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("狀態")) {
                    Text(probe.sessionState)
                    Text("已接收 \(probe.bytesReceived) bytes")
                        .foregroundColor(.secondary)
                    Button("重新整理") { probe.refresh() }
                    Button("開啟藍牙配件選擇器") { probe.showPicker() }
                    Button("關閉 Session") { probe.closeSession() }
                }

                if probe.accessories.isEmpty {
                    Section(header: Text("沒有配件")) {
                        Text("請先到 iOS「設定 > 藍牙」，與儀表（KYMCO Noodoe）完成配對並連線，並完全關閉原廠 Noodoe App。若仍看不到，代表儀表宣告的協定字串與本 App 不同。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                ForEach(probe.accessories) { a in
                    Section(header: Text(a.name)) {
                        row("製造商", a.manufacturer)
                        row("型號", a.modelNumber)
                        row("序號", a.serialNumber)
                        row("韌體", a.firmwareRevision)
                        row("硬體", a.hardwareRevision)
                        row("連線", a.isConnected ? "是" : "否")
                        row("協定", a.protocolStrings.joined(separator: ", "))
                        ForEach(a.protocolStrings, id: \.self) { p in
                            Button("被動監聽：\(p)") {
                                probe.openSession(a, protocolString: p)
                            }
                        }
                    }
                }
            }
            .navigationTitle("ExternalAccessory")
        }
        .navigationViewStyle(.stack)
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
            Spacer()
            Text(value.isEmpty ? "-" : value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
