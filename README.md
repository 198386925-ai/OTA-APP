# LUIYo 更新系统（自研 OTA 套件）

LUIYo 的「检查更新 → 下载 → 本地签名 → 安装」整套方案，全程在自己 App 内完成：不跳转任何外部签名 App，不依赖任何第三方签名/清单服务。含三部分：

| 目录 | 内容 | 跑在哪 |
|---|---|---|
| `app/` | 用户 App 的更新模块源码（Swift） | 编译进你的 iOS App |
| `server/` | 更新后台（Python/Flask，带网页上传） | 你的服务器 |
| `admin-app/` | 后台管理 App（SwiftUI） | 你的手机（发版用） |

## 整体流程

```
① 你在 admin-app 上传 IPA ──▶ server 保存 + 算 sha256 + 生成 latest.json
② 用户打开 App ──▶ 读更新源 latest ──▶ 发现新版本
③ App 后台下载 IPA ──▶ 本地 zsign 签名 ──▶ 本地服务出安装清单 ──▶ 系统确认安装
```

## `app/` — 用户 App 更新模块

三个模块，只依赖系统框架与套件自身：

```
app/RGAppUpdate/Sources/     →  更新核心：检查/下载/缓存/安装编排、本地安装服务、Live Activity
app/RGUpdateSigner/Sources/  →  签名模块：证书/描述文件校验、IPA 身份校验、zsign 签名与自检
app/RGUpdateSigner/CBridge/  →  zsign 引擎（C/C++ 源码 + C 桥接 + MIT 许可）
app/RGSettingsUI/Sources/    →  更新设置页（原生 UIKit）
```

### 签名模块（RGUpdateSigner）

对外接口（与 `RGAppUpdater` 的调用点逐一对齐）：

| 接口 | 作用 |
|---|---|
| `validateCertificate` | 打开 p12 并确认其证书属于已安装 App 内嵌描述文件的开发者证书，返回证书名 |
| `validateProfiles` | 校验每个描述文件可解析、未过期 |
| `installedProfiles` | 取出已安装 App（主包＋扩展）内嵌、且包含该证书的描述文件 |
| `validateInstalledApp` | 确认某个描述文件可为已安装 App 签更新：含证书、App ID 匹配、权限覆盖已安装 App 的全部 entitlements |
| `prepareIPA` | 校验下载包身份（bundle id / 版本 / 构建与已安装 App 及发布信息一致）→ zsign 签名 → CodeDirectory 自检 |
| `validateTrollStoreIPA` | TrollStore 路径的同等身份校验（不签名） |

实现路子与主 App 已真机跑通的更新签名一致：Security 框架解析 PKCS12、解析 mobileprovision、Mach-O 内嵌 entitlements 读取、签名后逐页校验 CodeDirectory 哈希。失败一律以 `NSError`（domain `RGUpdateSigner`，code 1–6）抛出，由调用方映射成用户可见错误。

zsign 引擎来自开源项目 zsign（MIT，版权 zhlynn），整份源码在 `CBridge/zsign-src/`，桥接是 `CBridge/zsign/luiyo_zsign_bridge.cpp`（把 zsign.cpp 以单一编译单元引入），许可全文在 `CBridge/zsign-LICENSE.txt`。**zsign 依赖 OpenSSL**：接入工程需自行提供 OpenSSL 头文件与库（主 App 用的是其 Vendor 里的 OpenSSL.framework，本套件未重复打包）。

接入接线：

- `RGUpdateSigner` Swift 目标需要能调用桥接函数 `luiyo_zsign_sign`：已附 `Sources/RGUpdateSigner-Bridging-Header.h`（Xcode 目标方式）；SPM 方式则让 Swift 目标依赖 CBridge 的 C 目标。
- Live Activity 的 attributes 定义在 `RGAppUpdate/Sources/RGUpdateActivityAttributes.swift`，**渲染用的 Widget 扩展目标必须包含同一份文件**。
- 更新设置页入口：`rgAppUpdateController()` 返回一个 `UIViewController`，推入你自己的导航栈即可。

### 更新源与规则

- 更新源地址运行时配置（UserDefaults，key：`LUIYo.AppUpdate.SourceLatestURL`），返回与 GitHub `/releases/latest` 相同的 JSON 形状；未配置时回落到 `https://updates.luiyo.app/v1/latest`。
- 下载白名单自动放行更新源域名（及 GitHub 官方域名，兼容以 GitHub Releases 为源）。
- IPA 文件名规则：`LUIYo-<版本>-b<构建>.ipa`。
- 安装清单（manifest）在设备上本地生成、由 App 内回环服务与安装包一同提供；iOS 系统安装器要求清单走 HTTPS，生产接入方式见 NOTES.md。

## `server/` — 更新后台

```bash
pip3 install -r requirements.txt
export LUIYO_ADMIN_TOKEN="改成你的口令"
export LUIYO_PUBLIC_BASE_URL="https://update.你的域名.com"
python3 update_server.py
```

接口：`GET /latest.json`（App 读）、`GET /ipa/<文件>`（App 下载）、`GET /` 与 `POST /upload`（网页上传）。
**必须配 HTTPS**（Caddy/Nginx + Let's Encrypt）。详见文件内注释。

## `admin-app/` — 后台管理 App

Xcode 新建 iOS App（SwiftUI），删掉自动生成的入口和 ContentView，把 4 个 `.swift` 拖进去即可。填服务器地址和口令后就能在手机上传 IPA 发版。

## 发一次新版本的完整步骤

1. Mac 编译出 `LUIYo-<版本>-b<构建>.ipa`
2. 打开 admin-app → 选 IPA → 填版本号/构建号/更新说明 → 上传并发布
3. 用户打开 App 即收到更新（或在更新设置页手动检查）
