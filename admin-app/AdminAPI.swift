//
//  AdminAPI.swift
//  与更新后台服务器通信：查询状态、上传 IPA
//

import Foundation

// MARK: - 返回数据模型

struct ServerStatus: Decodable {
    let current: CurrentRelease?
    let files: [String]?
    let base: String?

    struct CurrentRelease: Decodable {
        let tag_name: String?
        let body: String?
        let assets: [Asset]?

        struct Asset: Decodable {
            let name: String?
            let size: Int?
            let digest: String?
        }
    }
}

struct UploadResponse: Decodable {
    let ok: Bool
    let msg: String
    let name: String?
    let size: Int?
    let sha256: String?
}

// MARK: - 错误

enum AdminAPIError: Error, LocalizedError {
    case badURL
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "服务器地址无效，请在右上角设置里填写"
        case .badResponse(let msg):
            return msg
        }
    }
}

// MARK: - 客户端

final class AdminAPI {
    private let baseURL: String
    private let token: String

    init(baseURL: String, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    /// 拼接出合法请求地址
    private func makeURL(_ path: String) throws -> URL {
        var b = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if b.isEmpty { throw AdminAPIError.badURL }
        if !b.lowercased().hasPrefix("http") { b = "https://" + b }
        while b.hasSuffix("/") { b.removeLast() }
        guard let url = URL(string: b + path) else { throw AdminAPIError.badURL }
        return url
    }

    /// 查询当前线上版本（GET /status）
    func fetchStatus() async throws -> ServerStatus {
        var req = URLRequest(url: try makeURL("/status"), timeoutInterval: 20)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AdminAPIError.badResponse("服务器无响应") }
        guard (200..<300).contains(http.statusCode) else {
            throw AdminAPIError.badResponse("连接失败（HTTP \(http.statusCode)），请检查服务器地址")
        }
        return try JSONDecoder().decode(ServerStatus.self, from: data)
    }

    /// 上传 IPA 并发布（POST /upload，multipart 表单，带进度）
    func upload(ipaFileURL: URL,
                version: String,
                build: String,
                notes: String,
                onProgress: @escaping (Double) -> Void) async throws -> UploadResponse {

        let url = try makeURL("/upload")
        let boundary = "Boundary-\(UUID().uuidString)"

        var req = URLRequest(url: url, timeoutInterval: 900) // 大文件放宽超时
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // 读取文件（带安全作用域处理，fileImporter 选的文件在 App 沙箱外）
        let accessing = ipaFileURL.startAccessingSecurityScopedResource()
        defer { if accessing { ipaFileURL.stopAccessingSecurityScopedResource() } }
        let fileData: Data
        do {
            fileData = try Data(contentsOf: ipaFileURL)
        } catch {
            throw AdminAPIError.badResponse("读取文件失败：\(error.localizedDescription)")
        }

        // 拼 multipart body
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        field("token", token)
        field("version", version)
        field("build", build)
        field("notes", notes)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"ipa\"; filename=\"\(ipaFileURL.lastPathComponent)\"\r\n")
        body.append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n")

        // 上传（带进度）
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.uploadTask(with: req, from: body) { data, resp, error in
                if let error = error {
                    continuation.resume(throwing: AdminAPIError.badResponse("网络错误：\(error.localizedDescription)"))
                    return
                }
                guard let data = data, let http = resp as? HTTPURLResponse else {
                    continuation.resume(throwing: AdminAPIError.badResponse("服务器无响应"))
                    return
                }
                if http.statusCode >= 300 {
                    let msg = (try? JSONDecoder().decode(UploadResponse.self, from: data))?.msg
                        ?? "服务器返回 HTTP \(http.statusCode)"
                    continuation.resume(throwing: AdminAPIError.badResponse(msg))
                    return
                }
                do {
                    continuation.resume(returning: try JSONDecoder().decode(UploadResponse.self, from: data))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            task.progress.observe(\.fractionCompleted) { p, _ in
                onProgress(p.fractionCompleted)
            }
            task.resume()
        }
    }
}
