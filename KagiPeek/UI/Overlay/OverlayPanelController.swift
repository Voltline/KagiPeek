import AppKit
import SwiftUI

final class OverlayPanelController {
    private let panel: NSPanel
    private let settings: AppSettings

    init(engine: KeyPrefixEngine) {
        settings = engine.settings
        let contentView = OverlayPanelView()
            .environmentObject(engine)
            .environmentObject(settings)
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
        let columnCount = settings.overlayColumnCount.columnCount
        let widthFactor = settings.keyDisplayStyle == .symbols ? 0.06 : 0.12
        let preferredWidth = visible.width * (0.18 + (Double(columnCount) * widthFactor))
        let maxWidth = min(visible.width - 48, 1180)
        let width = min(max(preferredWidth, 350), maxWidth)
        let height = min(max(visible.height * 0.5, 500), 900)
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
    @EnvironmentObject private var engine: KeyPrefixEngine
    @EnvironmentObject private var settings: AppSettings

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 180, maximum: .infinity), spacing: 14, alignment: .top),
            count: settings.overlayColumnCount.columnCount
        )
    }

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
                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
                        ForEach(engine.visibleCandidates()) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack() {
                                    Text(engine.displayLabel(for: item.keys))
                                        .font(.system(.title3, design: .monospaced))
                                    Spacer()
                                    Text(item.category.label)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(.white.opacity(0.14), in: Capsule())
                                }
                                Text(item.desc)
                                    .font(.system(.title3, design: .default))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(10)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
