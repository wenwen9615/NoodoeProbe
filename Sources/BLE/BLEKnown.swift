import Foundation
import CoreBluetooth

enum Known {
    static let ancsService = CBUUID(string: "7905F431-B5CE-4E99-A40F-4B1E122D00D0")
    static let deviceInfoService = CBUUID(string: "180A")
    static let currentTimeService = CBUUID(string: "1805")

    static let uuidNames: [String: String] = [
        "1800": "Generic Access",
        "1801": "Generic Attribute",
        "180A": "Device Information",
        "180F": "Battery Service",
        "1805": "Current Time Service",
        "2A00": "Device Name",
        "2A01": "Appearance",
        "2A04": "Peripheral Preferred Connection Parameters",
        "2A05": "Service Changed",
        "2A19": "Battery Level",
        "2A23": "System ID",
        "2A24": "Model Number String",
        "2A25": "Serial Number String",
        "2A26": "Firmware Revision String",
        "2A27": "Hardware Revision String",
        "2A28": "Software Revision String",
        "2A29": "Manufacturer Name String",
        "2A2A": "IEEE 11073-20601 Regulatory Certification Data List",
        "2A50": "PnP ID",
        "7905F431-B5CE-4E99-A40F-4B1E122D00D0": "Apple Notification Center Service (ANCS)",
        "9FBF120D-6301-42D9-8C58-25E699A21DBD": "ANCS Notification Source",
        "69D1D8F3-45E1-49A8-9821-9BBDFDAAD9D9": "ANCS Control Point",
        "22EAC6E9-24D6-4BB5-BE44-B36ACE7C7BFB": "ANCS Data Source",
        "89D3502B-0F36-433A-8EF4-C502AD55F8DC": "Apple Media Service (AMS)",
        "9B3C81D8-57B1-4A8A-B8DF-0E56F7CA51C2": "AMS Remote Command",
        "2F7CABCE-808D-411F-9A0C-BB92BA96C102": "AMS Entity Update",
        "C6B2F38C-23AB-46D8-A6AB-A3A870BBD5D7": "AMS Entity Attribute"
    ]

    /// 僅收錄少數常見的 Bluetooth SIG Company ID，供 PnP ID 判讀參考；未收錄者請查官方清單。
    static let companyNames: [UInt16: String] = [
        0x0002: "Intel",
        0x0006: "Microsoft",
        0x000A: "Qualcomm / CSR",
        0x000D: "Texas Instruments",
        0x000F: "Broadcom",
        0x0030: "STMicroelectronics",
        0x0046: "MediaTek",
        0x004C: "Apple",
        0x0059: "Nordic Semiconductor",
        0x005D: "Realtek",
        0x0131: "Cypress Semiconductor"
    ]

    static func name(_ uuid: CBUUID) -> String {
        uuidNames[uuid.uuidString.uppercased()] ?? "Unknown"
    }

    static func decode(uuid: CBUUID, data: Data) -> String? {
        switch uuid.uuidString.uppercased() {
        case "2A00", "2A24", "2A25", "2A26", "2A27", "2A28", "2A29":
            return String(data: data, encoding: .utf8).map { "\"\($0)\"" }
        case "2A50":
            guard data.count >= 7 else { return nil }
            let b = [UInt8](data)
            let source = b[0]
            let vid = UInt16(b[1]) | (UInt16(b[2]) << 8)
            let pid = UInt16(b[3]) | (UInt16(b[4]) << 8)
            let ver = UInt16(b[5]) | (UInt16(b[6]) << 8)
            let sourceText = source == 1 ? "Bluetooth SIG" : (source == 2 ? "USB-IF" : "未知(\(source))")
            var s = "VendorIDSource=\(sourceText) VID=0x" + String(format: "%04X", vid)
            if source == 1, let c = companyNames[vid] { s += " (\(c))" }
            s += " PID=0x" + String(format: "%04X", pid) + " Ver=0x" + String(format: "%04X", ver)
            return s
        default:
            return nil
        }
    }
}
