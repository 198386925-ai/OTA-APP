//
//  ContentView.swift
//  主界面：查看当前线上版本 + 上传 IPA 发布新版本
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var config: AdminConfig

    // 服务器状态
    @State private var status: ServerStatus?
    @State private var statusLoading = false
    @State private var statusError: String?

    // 上传表单
    @State private var showPicker = false
    @State private var pickedFileURL: URL?
    @State private var version = ""
    @State private var build = ""
    @State private var notes = ""

    // 上传状态
    @State private var uploading = false
    @State private var progress: Double = 0
    @State private var resultMessage: String?
    @State private var resultIsError = false

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: 服务器状态
                Section {
                    HStack {
                        Text(config.baseURL.isEmpty ? "未配置服务器" : config.baseURL)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Button("刷新") { Task { await refreshStatus() } }
                            .disabled(!config.isConfigured || statusLoading)
                    }

                    if let s = status?.current {
                        LabeledContent("线上版本", value: s.tag_name ?? "-")
                        LabeledContent("文件名", value: s.assets?.first?.name ?? "-")
                        if let size = s.assets?.first?.size {
                            LabeledContent("大小", value: String(format: "%.1f MB", Double(size) / 1_048_576.0))
                        }
                        if let digest = s.assets?.first?.digest {
                            Text(digest)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else if statusLoading {
                        HStack { ProgressView(); Text("读取中…").foregroundStyle(.secondary) }
                    } else if let err = statusError {
                        Text(err).font(.footnote).foregroundStyle(.red)
                    }
                } header: {
                    Text("服务器状态")
                }

                // MARK: 发布新版本
                Section {
                    Button {
                        showPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text(pickedFileURL?.lastPathComponent ?? "选择 IPA 文件")
                                .lineLimit(1)
                        }
                    }

                    TextField("版本号（如 13.1）", text: $version)
                        .keyboardType(.decimalPad)
                    TextField("构建号（如 34620，比旧版大）", text: $build)
                        .keyboardType(.numberPad)
                    TextField("更新说明", text: $notes, axis: .vertical)
                        .lineLimit(2...4)

                    if uploading {
                        HStack(spacing: 10) {
                            ProgressView(value: progress)
                            Text("\(Int(progress * 100))%")
                                .font(.footnote)
                                .monospacedDigit()
                        }
                    } else {
                        Button("上传并发布") { Task { await doUpload() } }
                            .disabled(pickedFileURL == nil || version.isEmpty || build.isEmpty || !config.isConfigured)
                    }
                } header: {
                    Text("发布新版本")
                } footer: {
                    Text("上传后会自动算 sha256 并生成 latest.json，App 检查更新即可发现。构建号必须大于当前线上版本。")
                        .font(.caption)
                }

                // MARK: 结果
                if let msg = resultMessage {
                    Section {
                        Text(msg)
                            .font(.footnote)
                            .foregroundStyle(resultIsError ? .red : .green)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("LUIYo 更新后台")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gear") }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .fileImporter(isPresented: $showPicker, allowedContentTypes: [.data]) { result in
                switch result {
                case .success(let url):
                    guard url.pathExtension.lowercased() == "ipa" else {
                        resultMessage = "请选择 .ipa 结尾的安装包文件"
                        resultIsError = true
                        return
                    }
                    pickedFileURL = url
                    resultMessage = nil
                case .failure(let error):
                    resultMessage = "选择文件失败：\(error.localizedDescription)"
                    resultIsError = true
                }
            }
            .task { await refreshStatus() }
        }
    }

    // MARK: - 动作

    private func refreshStatus() async {
        guard config.isConfigured else { return }
        statusLoading = true
        statusError = nil
        defer { statusLoading = false }
        do {
            status = try await AdminAPI(baseURL: config.baseURL, token: config.token).fetchStatus()
        } catch {
            statusError = error.localizedDescription
        }
    }

    private func doUpload() async {
        guard let fileURL = pickedFileURL else { return }
        uploading = true
        progress = 0
        resultMessage = nil
        defer { uploading = false }
        do {
            let r = try await AdminAPI(baseURL: config.baseURL, token: config.token)
                .upload(ipaFileURL: fileURL, version: version, build: build, notes: notes) { p in
                    progress = p
                }
            resultMessage = """
            ✅ \(r.msg)
            文件：\(r.name ?? "-")
            大小：\(r.size ?? 0) 字节
            sha256：\(r.sha256 ?? "-")
            """
            resultIsError = false
            await refreshStatus()
        } catch {
            resultMessage = "❌ \(error.localizedDescription)"
            resultIsError = true
        }
    }
}
