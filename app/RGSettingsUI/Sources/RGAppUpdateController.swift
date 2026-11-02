// MARK: LUIYo — update settings page, native UIKit.
//
// This page used to be hosted inside a third-party client shell
// (its SwiftUI view depended on that shell's presentation/theme/
// string services). It is now a plain UITableViewController driven
// directly by RGAppUpdater, with system file picking and alerts.
// All user-facing entries and copy keep their original meaning;
// strings ship in this file (zh-Hans + English) under the same
// "AppUpdate.*" keys the module has always used.
import Combine
import Foundation
import UIKit
import UniformTypeIdentifiers
import RGAppUpdate

@MainActor
public func rgAppUpdateController(focusSetting: String? = nil) -> UIViewController {
    let controller = RGAppUpdateSettingsViewController(focusSetting: focusSetting)
    controller.title = RGSettingsText.t("AppUpdate.Title")
    return controller
}

// MARK: - Strings

enum RGSettingsText {
    static var isChinese: Bool {
        (Locale.preferredLanguages.first ?? "en").hasPrefix("zh")
    }

    static func t(_ key: String, _ args: String...) -> String {
        var value = (isChinese ? zh : en)[key] ?? en[key] ?? key
        for arg in args { value = value.replacingOccurrences(of: "%@", with: arg, options: [], range: value.range(of: "%@")) }
        return value
    }

    static let zh: [String: String] = [
        "AppUpdate.Title": "应用更新",
        "AppUpdate.OK": "好",
        "AppUpdate.CurrentVersion": "当前版本",
        "AppUpdate.Check": "检查更新",
        "AppUpdate.OpenGitHub": "打开更新页面",
        "AppUpdate.ReleaseNotes": "更新说明",
        "AppUpdate.Install": "安装更新",
        "AppUpdate.DownloadTrollStore": "下载更新",
        "AppUpdate.SignCached": "签名已下载的更新",
        "AppUpdate.Prepare": "下载并签名",
        "AppUpdate.Cancel": "取消",
        "AppUpdate.Restoring": "正在恢复更新状态",
        "AppUpdate.Checking": "正在检查更新",
        "AppUpdate.Available": "有可用更新",
        "AppUpdate.UpToDate": "已是最新版本",
        "AppUpdate.Validating": "正在校验签名材料",
        "AppUpdate.Downloading": "正在下载",
        "AppUpdate.Signing": "正在签名",
        "AppUpdate.PreparingInstall": "正在准备安装",
        "AppUpdate.Ready": "更新已就绪",
        "AppUpdate.InstallRequested": "已请求安装",
        "AppUpdate.InstallReading": "系统正在读取安装包",
        "AppUpdate.InstallerReceived": "安装包已送达",
        "AppUpdate.TrollStoreReceived": "安装包已送达 TrollStore",
        "AppUpdate.InstallationMethod": "安装方式",
        "AppUpdate.MethodCertificate": "证书签名",
        "AppUpdate.MethodTrollStore": "TrollStore",
        "AppUpdate.LiveActivity": "实时活动",
        "AppUpdate.AutomaticCheck": "自动检查更新",
        "AppUpdate.AutomaticPrepare": "自动下载并签名",
        "AppUpdate.AutomaticDownload": "自动下载",
        "AppUpdate.AutomaticNotice": "开启后将自动检查更新；准备更新需要先导入签名材料。",
        "AppUpdate.TrollStoreNotice": "通过 TrollStore 安装下载好的更新包，不在本机签名。",
        "AppUpdate.AutomaticExit": "安装后自动退出",
        "AppUpdate.AutomaticExitNotice": "安装包送达后自动退出应用，方便系统完成安装。",
        "AppUpdate.CertificateNotice": "导入用于签名更新的证书（.p12）与描述文件（.mobileprovision）。",
        "AppUpdate.SavedProfiles": "已保存的描述文件：%@ 个",
        "AppUpdate.ImportSigningMaterials": "导入证书与描述文件",
        "AppUpdate.ImportProfiles": "导入描述文件",
        "AppUpdate.Importing": "导入中…",
        "AppUpdate.RemoveCertificate": "移除证书",
        "AppUpdate.CertificatePassword": "证书密码",
        "AppUpdate.ImportConfirm": "导入",
        "AppUpdate.ProfilesImported": "已导入 %@ 个描述文件",
        "AppUpdate.CertificateImported": "证书已导入",
        "AppUpdate.ProfileBundle": "描述文件：%@",
        "AppUpdate.ProfileEntitlement": "权限：%@",
        "AppUpdate.InvalidRelease": "更新信息无效",
        "AppUpdate.InvalidManifest": "安装清单无效",
        "AppUpdate.NetworkError": "网络错误",
        "AppUpdate.HashMismatch": "安装包校验失败",
        "AppUpdate.NotConfigured": "尚未导入签名材料",
        "AppUpdate.KeychainError": "钥匙串错误",
        "AppUpdate.InvalidCertificate": "证书无效或密码错误",
        "AppUpdate.CertificateMismatch": "证书与当前应用不匹配",
        "AppUpdate.InvalidProfile": "描述文件无效",
        "AppUpdate.InvalidArchive": "安装包无效",
        "AppUpdate.IdentityMismatch": "安装包与当前应用不一致",
        "AppUpdate.SigningFailed": "签名失败",
        "AppUpdate.Cancelled": "已取消",
        "AppUpdate.ProfileMissing": "缺少可用的描述文件",
        "AppUpdate.ProfileUnreadable": "描述文件无法读取",
        "AppUpdate.ProfileExpired": "描述文件已过期",
        "AppUpdate.ProfileCertificateMismatch": "描述文件不包含此证书",
        "AppUpdate.ProfileAppIDMismatch": "描述文件的应用标识不匹配",
        "AppUpdate.ProfileEntitlementMismatch": "描述文件缺少所需权限",
        "AppUpdate.InstalledEntitlementsInvalid": "当前应用的权限信息无法读取",
        "AppUpdate.ProfileLimit": "描述文件数量已达上限",
        "AppUpdate.CacheError": "更新缓存错误",
        "AppUpdate.InstallationNotStarted": "安装未开始",
        "AppUpdate.InstallationRejected": "安装被系统拒绝",
        "AppUpdate.InstallationChannelEnded": "安装通道已中断",
        "AppUpdate.TrollStoreUnavailable": "TrollStore 不可用",
        "AppUpdate.TrollStoreNotStarted": "TrollStore 安装未开始",
        "AppUpdate.ImportWrongType": "文件类型不对",
        "AppUpdate.ImportTooLarge": "文件过大",
        "AppUpdate.ImportEmpty": "文件为空",
        "AppUpdate.ImportUnreadable": "文件无法读取",
        "AppUpdate.CertificateSelection": "请选择一份证书文件",
    ]

    static let en: [String: String] = [
        "AppUpdate.Title": "App Update",
        "AppUpdate.OK": "OK",
        "AppUpdate.CurrentVersion": "Current Version",
        "AppUpdate.Check": "Check for Updates",
        "AppUpdate.OpenGitHub": "Open Release Page",
        "AppUpdate.ReleaseNotes": "Release Notes",
        "AppUpdate.Install": "Install Update",
        "AppUpdate.DownloadTrollStore": "Download Update",
        "AppUpdate.SignCached": "Sign Downloaded Update",
        "AppUpdate.Prepare": "Download & Sign",
        "AppUpdate.Cancel": "Cancel",
        "AppUpdate.Restoring": "Restoring update state",
        "AppUpdate.Checking": "Checking for updates",
        "AppUpdate.Available": "Update available",
        "AppUpdate.UpToDate": "Up to date",
        "AppUpdate.Validating": "Validating signing materials",
        "AppUpdate.Downloading": "Downloading",
        "AppUpdate.Signing": "Signing",
        "AppUpdate.PreparingInstall": "Preparing install",
        "AppUpdate.Ready": "Update ready",
        "AppUpdate.InstallRequested": "Install requested",
        "AppUpdate.InstallReading": "Installer is reading the package",
        "AppUpdate.InstallerReceived": "Package delivered",
        "AppUpdate.TrollStoreReceived": "Package delivered to TrollStore",
        "AppUpdate.InstallationMethod": "Installation Method",
        "AppUpdate.MethodCertificate": "Certificate Signing",
        "AppUpdate.MethodTrollStore": "TrollStore",
        "AppUpdate.LiveActivity": "Live Activity",
        "AppUpdate.AutomaticCheck": "Check Automatically",
        "AppUpdate.AutomaticPrepare": "Prepare Automatically",
        "AppUpdate.AutomaticDownload": "Download Automatically",
        "AppUpdate.AutomaticNotice": "When on, updates are checked automatically. Preparing an update requires imported signing materials.",
        "AppUpdate.TrollStoreNotice": "Downloaded updates are installed through TrollStore and are not signed on this device.",
        "AppUpdate.AutomaticExit": "Exit After Installing",
        "AppUpdate.AutomaticExitNotice": "Quits the app once the package is delivered so the system can finish installing.",
        "AppUpdate.CertificateNotice": "Import the certificate (.p12) and provisioning profiles (.mobileprovision) used to sign updates.",
        "AppUpdate.SavedProfiles": "Saved profiles: %@",
        "AppUpdate.ImportSigningMaterials": "Import Certificate & Profiles",
        "AppUpdate.ImportProfiles": "Import Profiles",
        "AppUpdate.Importing": "Importing…",
        "AppUpdate.RemoveCertificate": "Remove Certificate",
        "AppUpdate.CertificatePassword": "Certificate Password",
        "AppUpdate.ImportConfirm": "Import",
        "AppUpdate.ProfilesImported": "Imported %@ profiles",
        "AppUpdate.CertificateImported": "Certificate imported",
        "AppUpdate.ProfileBundle": "Profile: %@",
        "AppUpdate.ProfileEntitlement": "Entitlement: %@",
        "AppUpdate.InvalidRelease": "Invalid release information",
        "AppUpdate.InvalidManifest": "Invalid installation manifest",
        "AppUpdate.NetworkError": "Network error",
        "AppUpdate.HashMismatch": "Package verification failed",
        "AppUpdate.NotConfigured": "Signing materials not imported yet",
        "AppUpdate.KeychainError": "Keychain error",
        "AppUpdate.InvalidCertificate": "Invalid certificate or wrong password",
        "AppUpdate.CertificateMismatch": "Certificate does not match this app",
        "AppUpdate.InvalidProfile": "Invalid provisioning profile",
        "AppUpdate.InvalidArchive": "Invalid package",
        "AppUpdate.IdentityMismatch": "Package does not match this app",
        "AppUpdate.SigningFailed": "Signing failed",
        "AppUpdate.Cancelled": "Cancelled",
        "AppUpdate.ProfileMissing": "No usable provisioning profile",
        "AppUpdate.ProfileUnreadable": "Profile could not be read",
        "AppUpdate.ProfileExpired": "Profile has expired",
        "AppUpdate.ProfileCertificateMismatch": "Profile does not contain this certificate",
        "AppUpdate.ProfileAppIDMismatch": "Profile app identifier mismatch",
        "AppUpdate.ProfileEntitlementMismatch": "Profile is missing a required entitlement",
        "AppUpdate.InstalledEntitlementsInvalid": "This app's entitlements could not be read",
        "AppUpdate.ProfileLimit": "Too many profiles",
        "AppUpdate.CacheError": "Update cache error",
        "AppUpdate.InstallationNotStarted": "Installation did not start",
        "AppUpdate.InstallationRejected": "Installation was rejected",
        "AppUpdate.InstallationChannelEnded": "Installation channel ended",
        "AppUpdate.TrollStoreUnavailable": "TrollStore is unavailable",
        "AppUpdate.TrollStoreNotStarted": "TrollStore installation did not start",
        "AppUpdate.ImportWrongType": "Wrong file type",
        "AppUpdate.ImportTooLarge": "File is too large",
        "AppUpdate.ImportEmpty": "File is empty",
        "AppUpdate.ImportUnreadable": "File could not be read",
        "AppUpdate.CertificateSelection": "Select exactly one certificate file",
    ]
}

// MARK: - Row model

private enum RGRowKind {
    case info(value: String)
    case text(footnote: Bool)
    case button(destructive: Bool)
    case toggle(isOn: Bool)
    case picker(value: String)
    case progress(fraction: Double, bytes: String)
    case spinner(text: String)
}

private struct RGRow {
    let anchor: String?
    let title: String
    let kind: RGRowKind
    var enabled = true
    var onSelect: (() -> Void)?
    var onToggle: ((Bool) -> Void)?
}

private struct RGSection {
    var footer: String?
    var rows: [RGRow]
}

// MARK: - Controller

@MainActor
final class RGAppUpdateSettingsViewController: UITableViewController, UIDocumentPickerDelegate {
    private let updater = RGAppUpdater.shared
    private let focusSetting: String?
    private var sections: [RGSection] = []
    private var cancellable: AnyCancellable?
    private var reloadScheduled = false
    private var credentialBusy = false
    private var didScrollToFocus = false

    init(focusSetting: String?) {
        self.focusSetting = focusSetting
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        updater.setActivityLanguageCode(RGSettingsText.isChinese ? "zh-Hans" : "en")
        cancellable = updater.objectWillChange.sink { [weak self] _ in
            self?.scheduleReload()
        }
        rebuild()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !didScrollToFocus, let focusSetting else { return }
        didScrollToFocus = true
        for (sectionIndex, section) in sections.enumerated() {
            if let rowIndex = section.rows.firstIndex(where: { $0.anchor == focusSetting }) {
                tableView.scrollToRow(at: IndexPath(row: rowIndex, section: sectionIndex), at: .middle, animated: false)
                return
            }
        }
    }

    private func scheduleReload() {
        guard !reloadScheduled else { return }
        reloadScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.reloadScheduled = false
            self?.rebuild()
        }
    }

    private func rebuild() {
        sections = buildSections()
        tableView.reloadData()
    }

    // MARK: Model

    private func buildSections() -> [RGSection] {
        let t = RGSettingsText.t
        var result: [RGSection] = []

        // Status
        var status: [RGRow] = []
        status.append(RGRow(anchor: nil, title: t("AppUpdate.CurrentVersion"), kind: .info(value: "\(updater.installedVersion) (\(updater.installedBuild))")))
        status.append(RGRow(anchor: "check", title: t("AppUpdate.Check"), kind: .button(destructive: false), enabled: !updater.stage.isBusy && !credentialBusy, onSelect: { [weak self] in self?.updater.check() }))
        status.append(RGRow(anchor: "github", title: t("AppUpdate.OpenGitHub"), kind: .button(destructive: false), onSelect: { [weak self] in
            guard let self else { return }
            UIApplication.shared.open(self.updater.githubReleaseURL, options: [:])
        }))
        if let release = updater.release {
            status.append(RGRow(anchor: nil, title: "\(release.version) (\(release.build))", kind: .text(footnote: false)))
            if !release.notes.isEmpty {
                status.append(RGRow(anchor: nil, title: release.notes, kind: .text(footnote: true)))
            }
            status += statusRows()
            if updater.hasPreparedUpdate {
                status.append(RGRow(anchor: nil, title: t("AppUpdate.Install"), kind: .button(destructive: false), enabled: !updater.stage.isBusy, onSelect: { [weak self] in self?.updater.install() }))
            } else if updater.isConfigured {
                let key = updater.installationMethod == .trollStore ? "AppUpdate.DownloadTrollStore" : (updater.hasDownloadedUpdate ? "AppUpdate.SignCached" : "AppUpdate.Prepare")
                status.append(RGRow(anchor: nil, title: t(key), kind: .button(destructive: false), enabled: !updater.stage.isBusy && !credentialBusy, onSelect: { [weak self] in self?.updater.prepare() }))
            }
        } else {
            status += statusRows()
        }
        if updater.stage.isBusy {
            status.append(RGRow(anchor: nil, title: t("AppUpdate.Cancel"), kind: .button(destructive: true), onSelect: { [weak self] in self?.updater.cancel() }))
        }
        result.append(RGSection(rows: status))

        // Settings
        var settings: [RGRow] = []
        settings.append(RGRow(anchor: "installationMethod", title: t("AppUpdate.InstallationMethod"), kind: .picker(value: t(updater.installationMethod.localizationKey)), enabled: !updater.stage.isBusy && !credentialBusy, onSelect: { [weak self] in self?.pickInstallationMethod() }))
        if #available(iOS 16.1, *) {
            settings.append(RGRow(anchor: "liveActivity", title: t("AppUpdate.LiveActivity"), kind: .toggle(isOn: updater.showsUpdateActivity), onToggle: { [weak self] value in self?.updater.showsUpdateActivity = value }))
        }
        settings.append(RGRow(anchor: "automaticCheck", title: t("AppUpdate.AutomaticCheck"), kind: .toggle(isOn: updater.automaticallyCheck), onToggle: { [weak self] value in self?.updater.automaticallyCheck = value }))
        settings.append(RGRow(anchor: "automaticDownload", title: t(updater.installationMethod == .trollStore ? "AppUpdate.AutomaticDownload" : "AppUpdate.AutomaticPrepare"), kind: .toggle(isOn: updater.automaticallyPrepare), enabled: updater.isConfigured, onToggle: { [weak self] value in self?.updater.automaticallyPrepare = value }))
        result.append(RGSection(footer: t(updater.installationMethod == .trollStore ? "AppUpdate.TrollStoreNotice" : "AppUpdate.AutomaticNotice"), rows: settings))

        // Certificate
        if updater.installationMethod == .certificate {
            result.append(RGSection(footer: t("AppUpdate.AutomaticExitNotice"), rows: [
                RGRow(anchor: "automaticExit", title: t("AppUpdate.AutomaticExit"), kind: .toggle(isOn: updater.automaticallyExitAfterInstalling), enabled: !updater.stage.isBusy, onToggle: { [weak self] value in self?.updater.automaticallyExitAfterInstalling = value })
            ]))
            var cert: [RGRow] = []
            if !updater.certificateName.isEmpty {
                cert.append(RGRow(anchor: nil, title: updater.certificateName, kind: .text(footnote: true)))
            }
            cert.append(RGRow(anchor: nil, title: t("AppUpdate.SavedProfiles", String(updater.savedProfileCount)), kind: .text(footnote: true)))
            cert.append(RGRow(anchor: "certificate", title: t("AppUpdate.ImportSigningMaterials"), kind: .button(destructive: false), enabled: !updater.stage.isBusy && !credentialBusy, onSelect: { [weak self] in self?.selectFiles(kind: .signingMaterials) }))
            cert.append(RGRow(anchor: nil, title: t("AppUpdate.ImportProfiles"), kind: .button(destructive: false), enabled: !updater.stage.isBusy && !credentialBusy, onSelect: { [weak self] in self?.selectFiles(kind: .profiles) }))
            if credentialBusy {
                cert.append(RGRow(anchor: nil, title: "", kind: .spinner(text: t("AppUpdate.Importing"))))
            }
            if !updater.certificateName.isEmpty {
                cert.append(RGRow(anchor: nil, title: t("AppUpdate.RemoveCertificate"), kind: .button(destructive: true), enabled: !updater.stage.isBusy && !credentialBusy, onSelect: { [weak self] in
                    guard let self else { return }
                    do { try self.updater.clearCertificate() } catch { self.show(error) }
                }))
            }
            result.append(RGSection(footer: t("AppUpdate.CertificateNotice"), rows: cert))
        }
        return result
    }

    private func statusRows() -> [RGRow] {
        let t = RGSettingsText.t
        var rows: [RGRow] = []
        rows.append(RGRow(anchor: nil, title: t(updater.stage.localizationKey), kind: .text(footnote: true)))
        if let failure = updater.failure {
            if let bundle = failure.profileBundle {
                rows.append(RGRow(anchor: nil, title: t("AppUpdate.ProfileBundle", bundle), kind: .text(footnote: true)))
            }
            if let entitlement = failure.profileEntitlement {
                rows.append(RGRow(anchor: nil, title: t("AppUpdate.ProfileEntitlement", entitlement), kind: .text(footnote: true)))
            }
        }
        if updater.stage == .downloading {
            let bytes = "\(ByteCountFormatter.string(fromByteCount: updater.downloadedBytes, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: updater.release?.size ?? 0, countStyle: .file))"
            rows.append(RGRow(anchor: nil, title: "\(Int(updater.progress * 100))%", kind: .progress(fraction: updater.progress, bytes: bytes)))
        } else if updater.stage.isBusy {
            rows.append(RGRow(anchor: nil, title: "", kind: .spinner(text: "")))
        }
        return rows
    }

    // MARK: Table

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row.kind {
        case .progress(let fraction, let bytes):
            let cell = tableView.dequeueReusableCell(withIdentifier: "progress") as? RGProgressCell ?? RGProgressCell(style: .default, reuseIdentifier: "progress")
            cell.percentLabel.text = row.title
            cell.bytesLabel.text = bytes
            cell.progressView.progress = Float(fraction)
            cell.selectionStyle = .none
            return cell
        case .spinner(let text):
            let cell = tableView.dequeueReusableCell(withIdentifier: "spinner") ?? UITableViewCell(style: .default, reuseIdentifier: "spinner")
            cell.textLabel?.text = text
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            cell.accessoryView = spinner
            cell.selectionStyle = .none
            return cell
        default:
            break
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "row") ?? UITableViewCell(style: .value1, reuseIdentifier: "row")
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.selectionStyle = .none
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = nil
        cell.textLabel?.textColor = .label
        cell.isUserInteractionEnabled = row.enabled
        cell.contentView.alpha = row.enabled ? 1 : 0.45
        switch row.kind {
        case .info(let value):
            cell.detailTextLabel?.text = value
        case .text(let footnote):
            if footnote {
                cell.textLabel?.font = .preferredFont(forTextStyle: .footnote)
                cell.textLabel?.textColor = .secondaryLabel
                cell.textLabel?.numberOfLines = 0
            }
        case .button(let destructive):
            cell.selectionStyle = .default
            cell.textLabel?.textColor = destructive ? .systemRed : view.tintColor
        case .toggle(let isOn):
            let toggle = UISwitch()
            toggle.isOn = isOn
            toggle.isEnabled = row.enabled
            let target = RGSwitchTarget { [weak self] value in
                self?.sections[indexPath.section].rows[indexPath.row].onToggle?(value)
            }
            toggle.addTarget(target, action: #selector(RGSwitchTarget.changed(_:)), for: .valueChanged)
            objc_setAssociatedObject(toggle, &RGSwitchTarget.associatedKey, target, .OBJC_ASSOCIATION_RETAIN)
            cell.accessoryView = toggle
        case .picker(let value):
            cell.detailTextLabel?.text = value
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        case .progress, .spinner:
            break
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        guard row.enabled else { return }
        row.onSelect?()
    }

    // MARK: Actions

    private func pickInstallationMethod() {
        let alert = UIAlertController(title: RGSettingsText.t("AppUpdate.InstallationMethod"), message: nil, preferredStyle: .actionSheet)
        for method in RGUpdateInstallationMethod.allCases {
            let title = RGSettingsText.t(method.localizationKey) + (method == updater.installationMethod ? " ✓" : "")
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.updater.installationMethod = method
            })
        }
        alert.addAction(UIAlertAction(title: RGSettingsText.t("AppUpdate.Cancel"), style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(alert, animated: true)
    }

    // MARK: File import

    private var pendingImportKind: RGUpdateCredentialFileKind?

    private func selectFiles(kind: RGUpdateCredentialFileKind) {
        pendingImportKind = kind
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.data], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let kind = pendingImportKind else { return }
        pendingImportKind = nil
        guard !urls.isEmpty, urls.count <= 16 else { show(RGUpdateCredentialFileError.unreadable); return }
        if kind == .signingMaterials, urls.filter({ RGUpdateCredentialFileKind.certificate.acceptsExtension($0.pathExtension) }).count != 1 {
            show(RGUpdateCredentialFileError.certificateSelection); return
        }
        credentialBusy = true
        rebuild()
        Task { @MainActor in
            defer { credentialBusy = false; rebuild() }
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try urls.map { try RGUpdateCredentialFile.read(url: $0, kind: kind) }
                }.value
                switch kind {
                case .profiles:
                    try await updater.importProfiles(data)
                    presentMessage(RGSettingsText.t("AppUpdate.ProfilesImported", String(data.count)))
                case .certificate, .signingMaterials:
                    guard let certificateIndex = urls.firstIndex(where: { RGUpdateCredentialFileKind.certificate.acceptsExtension($0.pathExtension) }) else {
                        throw RGUpdateCredentialFileError.certificateSelection
                    }
                    guard let password = await requestPassword(fileName: urls[certificateIndex].lastPathComponent) else { return }
                    let profiles = data.enumerated().filter { $0.offset != certificateIndex }.map(\.element)
                    try await updater.importCertificate(data[certificateIndex], password: password, profiles: profiles)
                    presentMessage(RGSettingsText.t("AppUpdate.CertificateImported"))
                }
            } catch {
                show(error)
            }
        }
    }

    private func requestPassword(fileName: String) async -> String? {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: RGSettingsText.t("AppUpdate.ImportSigningMaterials"), message: fileName, preferredStyle: .alert)
            alert.addTextField { field in
                field.placeholder = RGSettingsText.t("AppUpdate.CertificatePassword")
                field.isSecureTextEntry = true
            }
            alert.addAction(UIAlertAction(title: RGSettingsText.t("AppUpdate.Cancel"), style: .cancel) { _ in
                continuation.resume(returning: nil)
            })
            alert.addAction(UIAlertAction(title: RGSettingsText.t("AppUpdate.ImportConfirm"), style: .default) { _ in
                continuation.resume(returning: alert.textFields?.first?.text ?? "")
            })
            present(alert, animated: true)
        }
    }

    private func presentMessage(_ message: String) {
        let alert = UIAlertController(title: RGSettingsText.t("AppUpdate.Title"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: RGSettingsText.t("AppUpdate.OK"), style: .default))
        present(alert, animated: true)
    }

    private func show(_ error: Error) {
        let key = (error as? RGUpdateCredentialFileError)?.localizationKey ?? (error as? RGUpdateError ?? .network).localizationKey
        var message = RGSettingsText.t(key)
        if let failure = error as? RGUpdateError {
            if let bundle = failure.profileBundle { message += "\n\n" + RGSettingsText.t("AppUpdate.ProfileBundle", bundle) }
            if let entitlement = failure.profileEntitlement { message += "\n" + RGSettingsText.t("AppUpdate.ProfileEntitlement", entitlement) }
        }
        presentMessage(message)
    }
}

// MARK: - Helpers

private final class RGSwitchTarget: NSObject {
    static var associatedKey: UInt8 = 0
    private let handler: (Bool) -> Void
    init(handler: @escaping (Bool) -> Void) { self.handler = handler }
    @objc func changed(_ sender: UISwitch) { handler(sender.isOn) }
}

private final class RGProgressCell: UITableViewCell {
    let percentLabel = UILabel()
    let bytesLabel = UILabel()
    let progressView = UIProgressView(progressViewStyle: .default)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        percentLabel.font = .preferredFont(forTextStyle: .body)
        percentLabel.textColor = .label
        bytesLabel.font = .preferredFont(forTextStyle: .footnote)
        bytesLabel.textColor = .secondaryLabel
        let top = UIStackView(arrangedSubviews: [percentLabel, UIView(), bytesLabel])
        top.axis = .horizontal
        let stack = UIStackView(arrangedSubviews: [top, progressView])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
