//
//  SettingsView.swift
//  设置：服务器地址 + 上传口令
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var config: AdminConfig
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("服务器地址", text: $config.baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("上传口令", text: $config.token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("后台连接")
                } footer: {
                    Text("""
                    地址：填你服务器的 HTTPS 域名，例如 https://update.你的域名.com
                    口令：填服务器环境变量 LUIYO_ADMIN_TOKEN 的值
                    """)
                    .font(.caption)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
