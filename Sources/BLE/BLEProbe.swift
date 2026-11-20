import Foundation
import CoreBluetooth

struct DiscoveredPeripheral: Identifiable {
    let id: UUID
    var name: String
    var rssi: Int
    var adv: String
    var peripheral: CBPeripheral
}

struct CharItem: Identifiable {
    let id: String
    let uuid: String
    let title: String
    let props: String
    var value: String
    let canRead: Bool
    let canNotify: Bool
    var notifying: Bool
}

struct ServiceItem: Identifiable {
    let id: String
    let title: String
    var chars: [CharItem]
}

/// 唯讀探針：掃描、連線、列出服務、讀取特徵值、訂閱通知。不會寫入任何特徵值。
final class BLEProbe: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var stateText = "初始化中"
    @Published var scanning = false
    @Published var visible: [DiscoveredPeripheral] = []
    @Published var connectedName: String?
    @Published var services: [ServiceItem] = []
    @Published var nameFilter: String = "Noodoe" {
        didSet { refreshVisible() }
    }

    private var central: CBCentralManager!
    private var found: [UUID: DiscoveredPeripheral] = [:]
    private var peripheral: CBPeripheral?
    private var charRefs: [String: CBCharacteristic] = [:]
    private var values: [String: Data] = [:]
    private var notifying: Set<String> = []
    private var refreshScheduled = false
    private var loggedIDs: Set<UUID> = []

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main,
                                   options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    // MARK: - 掃描

    func startScan() {
        guard central.state == .poweredOn else {
            Log.add("BLE", "藍牙尚未就緒：\(stateText)")
            return
        }
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        scanning = true
        Log.add("BLE", "開始掃描（過濾：\(nameFilter.isEmpty ? "無" : nameFilter)）")
    }

    func stopScan() {
        central.stopScan()
        scanning = false
        Log.add("BLE", "停止掃描")
    }

    /// 已被系統（例如 ANCS）連線的裝置不會再廣播，需用這個方法找回。
    func retrieveSystemConnected() {
        guard central.state == .poweredOn else { return }
        let list = central.retrieveConnectedPeripherals(withServices: [
            Known.deviceInfoService, Known.ancsService, Known.currentTimeService
        ])
        Log.add("BLE", "系統已連線裝置：\(list.count) 個")
        for p in list {
            let name = p.name ?? "(無名稱)"
            Log.add("BLE", "  系統已連線：\(name) id=\(p.identifier.uuidString)")
            found[p.identifier] = DiscoveredPeripheral(id: p.identifier, name: name, rssi: 0,
                                                       adv: "由系統連線（無廣播資料）", peripheral: p)
        }
        refreshVisible()
    }

    private func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.refreshScheduled = false
            self.refreshVisible()
        }
    }

    private func refreshVisible() {
        let f = nameFilter.trimmingCharacters(in: .whitespaces).lowercased()
        visible = found.values
            .filter { f.isEmpty || $0.name.lowercased().contains(f) }
            .sorted { $0.rssi > $1.rssi }
    }

    private func describe(_ ad: [String: Any]) -> String {
        var parts: [String] = []
        if let u = ad[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            parts.append("svc=" + u.map { $0.uuidString }.joined(separator: ","))
        }
        if let u = ad[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID] {
            parts.append("solicited=" + u.map { $0.uuidString }.joined(separator: ","))
        }
        if let m = ad[CBAdvertisementDataManufacturerDataKey] as? Data {
            parts.append("mfr=" + m.hexString)
        }
        if let c = ad[CBAdvertisementDataIsConnectable] as? NSNumber {
            parts.append("connectable=\(c.boolValue)")
        }
        if let t = ad[CBAdvertisementDataTxPowerLevelKey] as? NSNumber {
            parts.append("tx=\(t)")
        }
        return parts.joined(separator: "  ")
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        switch c.state {
        case .poweredOn: stateText = "已開啟"
        case .poweredOff: stateText = "已關閉"
        case .unauthorized: stateText = "未授權（請到設定允許藍牙）"
        case .unsupported: stateText = "不支援"
        case .resetting: stateText = "重設中"
        case .unknown: stateText = "未知"
        @unknown default: stateText = "未知"
        }
        Log.add("BLE", "藍牙狀態：\(stateText)")
    }

    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral,
                        advertisementData ad: [String: Any], rssi RSSI: NSNumber) {
        let advName = ad[CBAdvertisementDataLocalNameKey] as? String
        let previous = found[p.identifier]
        let name = advName ?? p.name ?? previous?.name ?? "(無名稱)"
        let adText = describe(ad)
        let item = DiscoveredPeripheral(id: p.identifier, name: name, rssi: RSSI.intValue,
                                        adv: adText.isEmpty ? (previous?.adv ?? "") : adText,
                                        peripheral: p)
        found[p.identifier] = item

        let f = nameFilter.trimmingCharacters(in: .whitespaces).lowercased()
        if !loggedIDs.contains(p.identifier), f.isEmpty || name.lowercased().contains(f) {
            loggedIDs.insert(p.identifier)
            Log.add("BLE", "發現 \(name) id=\(p.identifier.uuidString) rssi=\(RSSI) \(adText)")
        }
        scheduleRefresh()
    }

    func connect(_ d: DiscoveredPeripheral) {
        guard central.state == .poweredOn else { return }
        disconnect()
        peripheral = d.peripheral
        d.peripheral.delegate = self
        Log.add("BLE", "連線中：\(d.name)")
        central.connect(d.peripheral, options: nil)
    }

    func disconnect() {
        if let p = peripheral {
            central.cancelPeripheralConnection(p)
        }
    }

    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        connectedName = p.name ?? "(無名稱)"
        charRefs.removeAll(); values.removeAll(); notifying.removeAll(); services = []
        Log.add("BLE", "已連線：\(connectedName ?? "")，探索服務")
        p.discoverServices(nil)
    }

    func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        Log.add("BLE", "連線失敗：\(error?.localizedDescription ?? "未知")")
    }

    func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        Log.add("BLE", "已斷線\(error.map { "：\($0.localizedDescription)" } ?? "")")
        connectedName = nil
        peripheral = nil
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            Log.add("BLE", "探索服務錯誤：\(error.localizedDescription)")
            return
        }
        for s in p.services ?? [] {
            Log.add("BLE", "服務 \(s.uuid.uuidString)  \(Known.name(s.uuid))")
            p.discoverCharacteristics(nil, for: s)
        }
        rebuild()
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            Log.add("BLE", "探索特徵值錯誤：\(error.localizedDescription)")
            return
        }
        for c in service.characteristics ?? [] {
            Log.add("BLE", "  特徵值 \(c.uuid.uuidString)  \(Known.name(c.uuid))  [\(propsText(c.properties))]")
            // Device Information 為標準唯讀資料，連線後自動讀取。
            if service.uuid == Known.deviceInfoService, c.properties.contains(.read) {
                p.readValue(for: c)
            }
        }
        rebuild()
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        if let error = error {
            Log.add("BLE", "讀取錯誤 \(c.uuid.uuidString)：\(error.localizedDescription)")
            return
        }
        let data = c.value ?? Data()
        if let key = key(for: c, in: p) { values[key] = data }
        var line = "值 \(c.uuid.uuidString) \(Known.name(c.uuid)) = \(data.hexString)  | \(data.asciiPreview)"
        if let decoded = Known.decode(uuid: c.uuid, data: data) { line += "  => \(decoded)" }
        Log.add("BLE", line)
        rebuild()
    }

    func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor c: CBCharacteristic, error: Error?) {
        if let error = error {
            Log.add("BLE", "訂閱錯誤 \(c.uuid.uuidString)：\(error.localizedDescription)")
            return
        }
        if let key = key(for: c, in: p) {
            if c.isNotifying { notifying.insert(key) } else { notifying.remove(key) }
        }
        Log.add("BLE", "通知 \(c.uuid.uuidString) isNotifying=\(c.isNotifying)")
        rebuild()
    }

    // MARK: - 使用者操作

    func read(_ item: CharItem) {
        guard let c = charRefs[item.id], let p = peripheral else { return }
        p.readValue(for: c)
    }

    func readAll() {
        guard let p = peripheral else { return }
        Log.add("BLE", "讀取全部可讀特徵值（若出現配對要求請拒絕）")
        for (_, c) in charRefs where c.properties.contains(.read) {
            p.readValue(for: c)
        }
    }

    func toggleNotify(_ item: CharItem) {
        guard let c = charRefs[item.id], let p = peripheral else { return }
        p.setNotifyValue(!c.isNotifying, for: c)
    }

    // MARK: - 輔助

    private func key(for c: CBCharacteristic, in p: CBPeripheral) -> String? {
        for s in p.services ?? [] {
            for x in s.characteristics ?? [] where x === c {
                return "\(s.uuid.uuidString)/\(x.uuid.uuidString)"
            }
        }
        return nil
    }

    private func propsText(_ p: CBCharacteristicProperties) -> String {
        var a: [String] = []
        if p.contains(.read) { a.append("read") }
        if p.contains(.write) { a.append("write") }
        if p.contains(.writeWithoutResponse) { a.append("writeNoRsp") }
        if p.contains(.notify) { a.append("notify") }
        if p.contains(.indicate) { a.append("indicate") }
        return a.joined(separator: ",")
    }

    private func rebuild() {
        guard let p = peripheral else { services = []; return }
        var result: [ServiceItem] = []
        for s in p.services ?? [] {
            var chars: [CharItem] = []
            for c in s.characteristics ?? [] {
                let k = "\(s.uuid.uuidString)/\(c.uuid.uuidString)"
                charRefs[k] = c
                var valueText = "-"
                if let d = values[k] {
                    valueText = "\(d.hexString) | \(d.asciiPreview)"
                    if let decoded = Known.decode(uuid: c.uuid, data: d) { valueText += "\n=> \(decoded)" }
                }
                chars.append(CharItem(id: k,
                                      uuid: c.uuid.uuidString,
                                      title: Known.name(c.uuid),
                                      props: propsText(c.properties),
                                      value: valueText,
                                      canRead: c.properties.contains(.read),
                                      canNotify: c.properties.contains(.notify) || c.properties.contains(.indicate),
                                      notifying: notifying.contains(k)))
            }
            result.append(ServiceItem(id: s.uuid.uuidString,
                                      title: "\(s.uuid.uuidString)  \(Known.name(s.uuid))",
                                      chars: chars))
        }
        services = result
    }
}
