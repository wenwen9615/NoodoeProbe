import SwiftUI

struct BLEView: View {
    @ObservedObject var probe: BLEProbe

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("掃描")) {
                    HStack {
                        Text("藍牙狀態")
                        Spacer()
                        Text(probe.stateText).foregroundColor(.secondary)
                    }
                    TextField("名稱過濾（留空顯示全部）", text: $probe.nameFilter)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button(probe.scanning ? "停止掃描" : "開始掃描") {
                        if probe.scanning { probe.stopScan() } else { probe.startScan() }
                    }
                    Button("查詢系統已連線的 BLE 裝置") { probe.retrieveSystemConnected() }
                }

                Section(header: Text("掃描結果（\(probe.visible.count)）")) {
                    ForEach(probe.visible) { d in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(d.name).font(.headline)
                                Spacer()
                                Text(d.rssi == 0 ? "-" : "\(d.rssi) dBm")
                                    .foregroundColor(.secondary)
                            }
                            if !d.adv.isEmpty {
                                Text(d.adv)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Button("連線並列出服務") { probe.connect(d) }
                                .font(.caption)
                                .buttonStyle(.borderless)
                        }
                    }
                }

                if let name = probe.connectedName {
                    Section(header: Text("已連線：\(name)")) {
                        Button("讀取所有可讀特徵值") { probe.readAll() }
                        Button("中斷連線（測完請務必執行）", role: .destructive) { probe.disconnect() }
                    }
                    ForEach(probe.services) { s in
                        Section(header: Text(s.title)) {
                            ForEach(s.chars) { c in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(c.title)  (\(c.uuid))").font(.subheadline)
                                    Text(c.props).font(.caption2).foregroundColor(.secondary)
                                    Text(c.value)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                    HStack(spacing: 16) {
                                        if c.canRead {
                                            Button("讀取") { probe.read(c) }
                                        }
                                        if c.canNotify {
                                            Button(c.notifying ? "取消訂閱" : "訂閱通知") {
                                                probe.toggleNotify(c)
                                            }
                                        }
                                    }
                                    .font(.caption)
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("BLE 探針")
        }
        .navigationViewStyle(.stack)
    }
}
