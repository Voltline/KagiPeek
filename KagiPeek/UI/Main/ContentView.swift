//
//  ContentView.swift
//  KagiPeek
//
//  Created by Voltline on 2026/3/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var engine: KeyPrefixEngine
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("KagiPeek")
                    .font(.title.bold())
                Spacer()
                Button("设置") {
                    openSettings()
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("状态: \(engine.statusText)")
                Text("当前应用: \(engine.activeAppName)")
                Text("当前快捷键: \(engine.currentPrefixLabel)")
                    .font(.system(.body, design: .monospaced))
            }

            if !engine.accessibilityPermissionGranted {
                VStack(alignment: .leading, spacing: 10) {
                    Text("尚未授予辅助功能权限，无法监听全局快捷键。")
                        .foregroundStyle(.orange)

                    HStack(spacing: 10) {
                        Button("请求辅助功能授权") {
                            engine.requestAccessibilityAuthorization()
                        }
                        Button("打开系统设置") {
                            engine.openAccessibilitySettings()
                        }
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text("快捷键候选")
                .font(.headline.bold())

            if engine.candidates.isEmpty {
                VStack {
                    Text("无候选快捷键")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(engine.visibleCandidates()) { item in
                    HStack {
                        Text(engine.displayLabel(for: item.keys))
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Text(item.category.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.desc)
                    }
                }
                .frame(minHeight: 260)
            }
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 560)
    }
}

#Preview {
    ContentView()
        .environmentObject(KeyPrefixEngine(settings: AppSettings()))
}
