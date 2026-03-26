import AppKit
import SwiftUI

final class OverlayPanelController {
    private let panel: NSPanel

    init(engine: KeyPrefixEngine) {
        let contentView = OverlayPanelView().environmentObject(engine)
        let hostingView = NSHostingView(rootView: contentView)

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 360),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = false
        panel.contentView = hostingView
    }

    func show() {
        positionPanel()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func positionPanel() {
        guard let screen = targetScreen() else { return }
        let visible = screen.visibleFrame
        let width = min(max(visible.width * 0.2, 300), 780)
        let height = min(max(visible.height * 0.7, 700), 900)
        let x = visible.minX + 24
        let y = visible.maxY - height - 24
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let pointedScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return pointedScreen
        }
        if let keyWindowScreen = NSApp.keyWindow?.screen {
            return keyWindowScreen
        }
        return NSScreen.main
    }
}

struct OverlayPanelView: View {
    @EnvironmentObject var engine: KeyPrefixEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KagiPeek")
                .font(.title)
                .foregroundStyle(.white.opacity(0.95))

            Text(engine.currentPrefixLabel)
                .font(.subheadline.monospaced())
                .foregroundStyle(.white.opacity(0.75))

            Text("当前应用: \(engine.activeAppName)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            if engine.candidates.isEmpty {
                Text("无候选快捷键")
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(engine.visibleCandidates()) { item in
                            HStack {
                                Text(engine.displayLabel(for: item.keys))
                                    .font(.system(.title3, design: .monospaced))
                                Spacer()
                                Text(item.category.label)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.white.opacity(0.14), in: Capsule())
                                Text(item.desc)
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}
