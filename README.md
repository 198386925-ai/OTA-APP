# LUIYo 更新系统

LUIYo 的「检查更新 → 下载 → 本地签名 → 安装」整套方案，含三部分：

| 目录 | 内容 | 跑在哪 |
|---|---|---|
| `app/` | 用户 App 的更新模块源码（Swift，已全量改名 LUIYo） | 编译进 LUIYo App（iOS） |
| `server/` | 更新后台（Python/Flask，带网页上传） | 你的服务器 |
| `admin-app/` | 后台管理 App（SwiftUI） | 你的手机（发版用） |

## 整体流程

```
① 你在 admin-app 上传 IPA ──▶ server 保存 + 算 sha256 + 生成 latest.json
② 用户打开 LUIYo App ──▶ 读 /latest.json ──▶ 发现新版本
③ App 下载 IPA ──▶ 本地 zsign 重签 ──▶ 用户点一下系统确认 ──▶ 装好
```

## 各部分

### `app/` — 用户 App 更新模块

放进你的 iOS 工程对应位置后编译：

```
app/RGAppUpdate/Sources/     →  你的工程/RGAppUpdate/Sources/
app/RGSettingsUI/Sources/    →  你的工程/RGSettingsUI/Sources/
```

- 更新源地址运行时配置（UserDefaults，key：`LUIYo.AppUpdate.SourceLatestURL`）
- 下载白名单自动放行更新源域名
- IPA 文件名规则：`LUIYo-<版本>-b<构建>.ipa`

### `server/` — 更新后台

```bash
pip3 install -r requirements.txt
export LUIYO_ADMIN_TOKEN="改成你的口令"
export LUIYO_PUBLIC_BASE_URL="https://update.你的域名.com"
python3 update_server.py
```

接口：`GET /latest.json`（App 读）、`GET /ipa/<文件>`（App 下载）、`GET /` 与 `POST /upload`（网页上传）。
**必须配 HTTPS**（Caddy/Nginx + Let's Encrypt）。详见文件内注释。

### `admin-app/` — 后台管理 App

Xcode 新建 iOS App（SwiftUI），删掉自动生成的入口和 ContentView，把 4 个 `.swift` 拖进去即可。填服务器地址和口令后就能在手机上传 IPA 发版。

## 发一次新版本的完整步骤

1. Mac 编译出 `LUIYo-<版本>-b<构建>.ipa`
2. 打开 admin-app → 选 IPA → 填版本号/构建号/更新说明 → 上传并发布
3. 用户打开 LUIYo App 即收到更新
