//
//  LUIYoAdminApp.swift
//  LUIYo 更新后台管理 App
//
//  作用：连接你自己的更新后台服务器，在手机上完成
//        「选择 IPA → 填版本号 → 上传发布 → 查看当前线上版本」
//

import SwiftUI

@main
struct LUIYoAdminApp: App {
    @StateObject private var config = AdminConfig()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(config)
        }
    }
}

/// 后台连接配置（服务器地址 + 上传口令），存在本机
final class AdminConfig: ObservableObject {
    @AppStorage("admin.baseURL") var baseURL: String = ""
    @AppStorage("admin.token") var token: String = ""

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
