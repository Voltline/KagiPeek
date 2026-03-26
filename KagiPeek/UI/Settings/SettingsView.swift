import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    private let delayOptions: [Double] = [0, 0.1, 0.2, 0.3, 0.5, 0.8, 1.0, 1.5]
    private let maxDisplayOptions: [Int] = [10, 20, 30, 50, 100, 0]

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
