import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct LogView: View {
    @ObservedObject private var store = LogStore.shared
    @State private var showShare = false

    var body: some View {
        NavigationView {
            List(store.entries.reversed()) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(LogStore.timeFormatter.string(from: entry.date))  \(entry.category)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(entry.message)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .listStyle(.plain)
            .navigationTitle("記錄（\(store.entries.count)）")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("複製") { UIPasteboard.general.string = store.text }
                    Button("分享") { showShare = true }
                    Button("清除") { store.clear() }
                }
            }
            .sheet(isPresented: $showShare) {
                ShareSheet(items: [store.fileURL])
            }
        }
        .navigationViewStyle(.stack)
    }
}
