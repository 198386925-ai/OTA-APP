# 补齐说明与待验证清单

这套 OTA 原是一份残件：签名模块缺失、界面层依赖某个第三方客户端的私有框架栈、安装清单走第三方签名服务（节点协议）。本次按「全程 App 内、自研干净」补齐，改动要点与仍需在 Xcode/真机验证的事项如下。

## 本次改动

- **新建 `RGUpdateSigner` 模块**（`app/RGUpdateSigner/`）：实现调用方需要的全部 6 个接口（清单见 README），校验逻辑与 zsign 签名沿用主 App 已真机跑通的路子；签名后强制 CodeDirectory 自检，失败不交包。
- **zsign 引擎整份收入** `app/RGUpdateSigner/CBridge/`（源码 68 文件 + 桥接 + MIT 许可原文）。引擎依赖 OpenSSL，套件未打包 OpenSSL，接入工程需自备（见下）。
- **删除第三方节点安装文件**：安装清单改为设备本地生成（`RGInstallManifest`，标准 Apple OTA plist 格式），由套件自带的回环服务 `RGLocalUpdateServer` 与安装包一同提供（各自随机路由）；更新编排里的节点列表/节点选择/远程清单请求全部移除。
- **界面层去第三方框架**：更新设置页重写为原生 UIKit（`UITableViewController`），功能入口与文案含义与原 SwiftUI 版一致，字符串表（zh-Hans/English）随文件自带；原缺失的文件选择器类由系统 `UIDocumentPickerViewController` + 系统密码弹窗替代。
- **Live Activity**：attributes 改为套件内自包含定义（`RGUpdateActivityAttributes.swift`）；本地化改为从宿主 App 自己的 `.lproj` 按语言代码解析。
- **杂项**：`ValuePromise` 换成套件内 Combine 实现（`RGValuePromise`）；设置深链改为从宿主 App 实际注册的 URL scheme 生成，不再依赖第三方构建配置模块。

## 已在本地（Linux）完成的校验

- 全仓扫描：无任何第三方签名服务的域名/字样残留；全部 Swift 文件的 `import` 仅限系统框架（Foundation / UIKit / SwiftUI / Security / Network / CryptoKit / ActivityKit / Combine / UniformTypeIdentifiers / Compression）与套件内模块（RGAppUpdate / RGUpdateSigner）。
- `RGUpdateSigner` 6 个接口与 `RGAppUpdater.swift` 全部调用点逐一比对：参数标签、参数类型、返回类型、`throws` 一致；错误 domain/code 与调用方 `mapSigningError` 的映射（1 证书无效、2 证书不匹配、3 描述文件问题＋`profileReason`/`bundleName`/`entitlement`、4 包无效、5 身份不一致、其它 签名失败）一致。

## 仍需在 Xcode / 真机验证（本机无 Swift 工具链，未做编译）

1. **整体编译**：三模块按 README 接线后在 Xcode 编译一遍，重点看：
   - `RGUpdateSigner` 目标对 C 桥接函数 `luiyo_zsign_sign` 的可见性（桥接头方式或 SPM C 目标依赖）；
   - zsign 源码的头文件搜索路径（桥接以 `../zsign-src/zsign.cpp` 单一编译单元引入，zsign-src 内部以引号相对包含）与 OpenSSL 头文件/库的链接（需接入工程自备 OpenSSL，如主 App 的 OpenSSL.framework）；
   - `Compression` 框架链接（ZIP 解压用，系统框架）。
2. **签名链真机验证**：导入真实 p12＋描述文件，走一遍 检查→下载→签名→安装，确认 `prepareIPA` 选中的描述文件、签名产物可覆盖安装；故意用错证书/过期描述文件各试一次，确认错误提示与原因（证书不匹配/已过期/App ID/权限）对得上。
3. **安装清单的 HTTPS**：iOS 要求 itms-services 的 manifest 必须经 HTTPS 获取；本套件回环服务为本地 HTTP，manifest 与 IPA 同机提供。生产接入需二选一（与主 App 现行做法一致的是其一）：① 自有域名解析到 127.0.0.1＋该域名的受信任 TLS 证书，在回环服务前终结 TLS；② 把 manifest 放到自有 HTTPS 静态托管（内容由 App 生成后上传，仅清单、无包体）。**这一点未在真机验证前不要宣称安装链完整跑通。**
4. **Live Activity**：Widget 扩展包含 `RGUpdateActivityAttributes.swift` 后，确认活动可创建/更新/结束，深链能回到更新设置页。
5. **TrollStore 路径**：在装了 TrollStore 的设备上验证下载→校验→送达安装。
6. **后台下载恢复**：杀进程后重开 App，确认后台下载任务与缓存恢复（`RGUpdateBackgroundDownload` / `RGUpdateCache` 为原有文件，未改动其逻辑，但未在真机复测）。
