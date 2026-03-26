import SwiftUI

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("打开主界面") {
                openWindow(id: "main")
            }

            Button("设置") {
                openSettings()
            }

            Divider()

            Button("退出 KagiPeek") {
                NSApp.terminate(nil)
            }
        }
        .padding(.vertical, 4)
        .frame(minWidth: 180)
    }
}

#Preview {
    MenuBarContentView()
}
