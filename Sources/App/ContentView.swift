import SwiftUI

struct ContentView: View {
    @StateObject private var ea = EAProbe()
    @StateObject private var ble = BLEProbe()

    var body: some View {
        TabView {
            EAView(probe: ea)
                .tabItem { Label("配件", systemImage: "cable.connector") }
            BLEView(probe: ble)
                .tabItem { Label("BLE", systemImage: "dot.radiowaves.left.and.right") }
            LogView()
                .tabItem { Label("記錄", systemImage: "doc.text") }
        }
    }
}
