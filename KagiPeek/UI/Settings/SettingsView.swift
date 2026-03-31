import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var engine: KeyPrefixEngine
    @EnvironmentObject private var settings: AppSettings

    private let delayOptions: [Double] = [0, 0.1, 0.2, 0.3, 0.5, 0.8, 1.0, 1.5]
    private let maxDisplayOptions: [Int] = [10, 20, 30, 50, 100, 0]
    private let repoURL = URL(string: "https://github.com/Voltline/KagiPeek")!

    private var appVersionText: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "未知"
        return "v\(shortVersion) (Build \(buildVersion))"
    }

    private var usageStatsSummaryText: String {
        "已学习 \(engine.usageStats.count) 个快捷键，共记录 \(engine.totalLearnedUsageCount) 次触发"
    }

    var body: some View {
        Form {
            Picker("按键长按延时", selection: $settings.overlayHoldDelaySeconds) {
                ForEach(delayOptions, id: \.self) { value in
                    Text(String(format: "%.1f 秒", value)).tag(value)
                }
            }

            Toggle("开机自启动", isOn: $settings.launchAtLoginEnabled)

            Picker("按键显示风格", selection: $settings.keyDisplayStyle) {
                ForEach(AppSettings.KeyDisplayStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Picker("弹窗列数", selection: $settings.overlayColumnCount) {
                ForEach(AppSettings.OverlayColumnCount.allCases) { columnCount in
                    Text(columnCount.title).tag(columnCount)
                }
            }
            .pickerStyle(.segmented)

            Picker("频率排序", selection: $settings.frequencySortOrder) {
                ForEach(AppSettings.FrequencySortOrder.allCases) { order in
                    Text(order.title).tag(order)
                }
            }
            .pickerStyle(.segmented)

            Picker("最大显示条数", selection: $settings.maxDisplayCount) {
                ForEach(maxDisplayOptions, id: \.self) { value in
                    if value == 0 {
                        Text("全部").tag(value)
                    } else {
                        Text("\(value) 条").tag(value)
                    }
                }
            }

            if !settings.launchAtLoginMessage.isEmpty {
                Text(settings.launchAtLoginMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("快捷键统计") {
                Text(usageStatsSummaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if engine.usageStats.isEmpty {
                    ContentUnavailableView(
                        "还没有统计数据",
                        systemImage: "chart.bar.xaxis",
                        description: Text("开始使用 KagiPeek 识别快捷键后，这里会显示你最常触发的组合键。")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Text("快捷键")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("学习次数")
                                .frame(width: 72, alignment: .trailing)
                            Text("排序总分")
                                .frame(width: 72, alignment: .trailing)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 6)

                        ForEach(engine.usageStats) { stat in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(engine.displayLabel(for: stat.shortcut.keys))
                                        .font(.system(.body, design: .monospaced))
                                    HStack(spacing: 6) {
                                        Text(stat.shortcut.desc)
                                        Text("·")
                                        Text(stat.shortcut.category.label)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Text("\(stat.learnedCount)")
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: 72, alignment: .trailing)

                                Text("\(stat.effectiveCount)")
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: 72, alignment: .trailing)
                            }
                            .padding(.vertical, 8)

                            if stat.id != engine.usageStats.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            Section("关于") {
                LabeledContent("版本号") {
                    Text(appVersionText)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("GitHub") {
                    Link("Voltline/KagiPeek", destination: repoURL)
                }

                LabeledContent("开源协议") {
                    Text("GNU GPL v2.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 620, height: 760)
    }
}

#Preview {
    SettingsView()
        .environmentObject(KeyPrefixEngine(settings: AppSettings()))
        .environmentObject(AppSettings())
}
