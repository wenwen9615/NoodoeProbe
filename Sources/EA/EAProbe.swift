import Foundation
import ExternalAccessory

struct AccessoryInfo: Identifiable {
    let id: Int
    let name: String
    let manufacturer: String
    let modelNumber: String
    let serialNumber: String
    let firmwareRevision: String
    let hardwareRevision: String
    let protocolStrings: [String]
    let isConnected: Bool
    let accessory: EAAccessory
}

/// 被動探針：只列出配件資訊、只讀取 session 收到的資料，不會寫入任何位元組。
final class EAProbe: NSObject, ObservableObject, StreamDelegate {
    @Published var accessories: [AccessoryInfo] = []
    @Published var sessionState: String = "Session：未開啟"
    @Published var bytesReceived: Int = 0

    private let manager = EAAccessoryManager.shared()
    private var session: EASession?
    private var sessionConnectionID: Int?

    override init() {
        super.init()
        manager.registerForLocalNotifications()
        NotificationCenter.default.addObserver(self,
            selector: #selector(accessoryDidConnect(_:)),
            name: .EAAccessoryDidConnect, object: nil)
        NotificationCenter.default.addObserver(self,
            selector: #selector(accessoryDidDisconnect(_:)),
            name: .EAAccessoryDidDisconnect, object: nil)
        refresh()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 配件列表

    func refresh() {
        let list = manager.connectedAccessories
        accessories = list.map { makeInfo($0) }
        Log.add("EA", "重新整理：目前 \(list.count) 個配件")
        for a in list { dump(a) }
    }

    func showPicker() {
        Log.add("EA", "開啟藍牙配件選擇器")
        manager.showBluetoothAccessoryPicker(withNameFilter: nil) { error in
            if let error = error {
                Log.add("EA", "選擇器結束：\(error.localizedDescription)")
            } else {
                Log.add("EA", "選擇器結束：成功")
            }
        }
    }

    private func makeInfo(_ a: EAAccessory) -> AccessoryInfo {
        AccessoryInfo(id: a.connectionID,
                      name: a.name,
                      manufacturer: a.manufacturer,
                      modelNumber: a.modelNumber,
                      serialNumber: a.serialNumber,
                      firmwareRevision: a.firmwareRevision,
                      hardwareRevision: a.hardwareRevision,
                      protocolStrings: a.protocolStrings,
                      isConnected: a.isConnected,
                      accessory: a)
    }

    private func dump(_ a: EAAccessory) {
        Log.add("EA", """
        Accessory #\(a.connectionID) name=\(a.name) manufacturer=\(a.manufacturer) \
        model=\(a.modelNumber) serial=\(a.serialNumber) fw=\(a.firmwareRevision) \
        hw=\(a.hardwareRevision) connected=\(a.isConnected) protocols=\(a.protocolStrings)
        """)
    }

    @objc private func accessoryDidConnect(_ note: Notification) {
        if let a = note.userInfo?[EAAccessoryKey] as? EAAccessory {
            Log.add("EA", "事件：配件連上")
            dump(a)
        }
        refresh()
    }

    @objc private func accessoryDidDisconnect(_ note: Notification) {
        if let a = note.userInfo?[EAAccessoryKey] as? EAAccessory {
            Log.add("EA", "事件：配件斷線 #\(a.connectionID) \(a.name)")
            if a.connectionID == sessionConnectionID { closeSession() }
        }
        refresh()
    }

    // MARK: - Session（被動監聽）

    func openSession(_ info: AccessoryInfo, protocolString: String) {
        closeSession()
        guard let s = EASession(accessory: info.accessory, forProtocol: protocolString) else {
            Log.add("EA", "無法開啟 session：\(info.name) / \(protocolString)")
            sessionState = "Session：開啟失敗（\(protocolString)）"
            return
        }
        session = s
        sessionConnectionID = info.id
        let streams: [Stream?] = [s.inputStream, s.outputStream]
        for stream in streams {
            stream?.delegate = self
            stream?.schedule(in: .main, forMode: .common)
            stream?.open()
        }
        bytesReceived = 0
        sessionState = "Session：已開啟（\(protocolString)），只收不送"
        Log.add("EA", "已開啟 session \(info.name) / \(protocolString)（被動監聽）")
    }

    func closeSession() {
        guard let s = session else { return }
        let streams: [Stream?] = [s.inputStream, s.outputStream]
        for stream in streams {
            stream?.close()
            stream?.remove(from: .main, forMode: .common)
            stream?.delegate = nil
        }
        session = nil
        sessionConnectionID = nil
        sessionState = "Session：未開啟"
        Log.add("EA", "已關閉 session")
    }

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            Log.add("EA", "串流開啟完成：\(aStream is InputStream ? "input" : "output")")
        case .hasBytesAvailable:
            guard let input = aStream as? InputStream else { return }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while input.hasBytesAvailable {
                let n = input.read(&buffer, maxLength: buffer.count)
                if n > 0 {
                    let d = Data(buffer[0..<n])
                    bytesReceived += n
                    Log.add("EA RX", "\(n)B  \(d.hexString)")
                    Log.add("EA RX", "ascii: \(d.asciiPreview)")
                } else {
                    break
                }
            }
        case .errorOccurred:
            Log.add("EA", "串流錯誤：\(aStream.streamError?.localizedDescription ?? "未知")")
        case .endEncountered:
            Log.add("EA", "串流結束")
            closeSession()
        default:
            break
        }
    }
}
