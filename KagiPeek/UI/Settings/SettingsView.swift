import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    private let delayOptions: [Double] = [0, 0.1, 0.2, 0.3, 0.5, 0.8, 1.0, 1.5]
    private let maxDisplayOptions: [Int] = [10, 20, 30, 50, 100, 0]
    private let repoURL = URL(string: "https://github.com/Voltline/KagiPeek")!

    private var appVersionText: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "未知"
        return "v\(shortVersion) (Build \(buildVersion))"
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
        .frame(width: 520)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
