#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LUIYo 更新后台 (Flask 单文件)
================================
功能:
  GET  /              上传管理页面（网页点上传）
  POST /upload        上传 IPA，自动算 sha256 并更新 latest.json
  GET  /latest.json   App 读取的版本信息（更新源）
  GET  /ipa/<文件名>   App 下载安装包
  GET  /status        当前线上版本（页面用）

环境变量（启动时配置）:
  LUIYO_DATA_DIR         数据目录，默认 ./data
  LUIYO_ADMIN_TOKEN      上传口令（必改！防止陌生人传包）
  LUIYO_PUBLIC_BASE_URL  对外 HTTPS 地址，如 https://update.你的域名.com
  LUIYO_MAX_UPLOAD_MB    上传大小上限（MB），默认 500
  PORT                   监听端口，默认 5000
"""

import hashlib
import json
import os
import re

from flask import Flask, jsonify, request, send_from_directory

# ---------- 配置 ----------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.environ.get("LUIYO_DATA_DIR") or os.path.join(BASE_DIR, "data")
IPA_DIR = os.path.join(DATA_DIR, "ipa")
META_FILE = os.path.join(DATA_DIR, "latest.json")
ADMIN_TOKEN = os.environ.get("LUIYO_ADMIN_TOKEN") or "change-me-please"
PUBLIC_BASE_URL = (os.environ.get("LUIYO_PUBLIC_BASE_URL") or "").rstrip("/")
MAX_MB = int(os.environ.get("LUIYO_MAX_UPLOAD_MB") or 500)

# 文件名规则（与 App 源码校验一致）：LUIYo-<版本>-b<构建>.ipa
NAME_RE = re.compile(r"^LUIYo-([0-9]+(?:\.[0-9]+){1,3})-b([1-9][0-9]*)\.ipa$")

os.makedirs(IPA_DIR, exist_ok=True)

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = MAX_MB * 1024 * 1024


# ---------- 工具 ----------
def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_meta():
    if not os.path.isfile(META_FILE):
        return None
    try:
        with open(META_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def write_meta(version, build, name, size, digest, notes):
    """生成 latest.json（格式与 App 更新器要求一致）。"""
    base = PUBLIC_BASE_URL
    url = ("%s/ipa/%s" % (base, name)) if base else ("/ipa/%s" % name)
    data = {
        "tag_name": "v%s-b%s" % (version, build),
        "body": notes or "本次更新：优化体验，修复已知问题。",
        "assets": [
            {
                "name": name,
                "size": size,
                "digest": "sha256:%s" % digest,
                "browser_download_url": url,
            }
        ],
    }
    with open(META_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    return data


# ---------- 路由 ----------
@app.route("/")
def index():
    return INDEX_HTML


@app.route("/latest.json")
def latest():
    meta = read_meta()
    if meta is None:
        return jsonify({"error": "尚未上传任何版本"}), 404
    return jsonify(meta)


@app.route("/ipa/<path:filename>")
def download(filename):
    return send_from_directory(IPA_DIR, filename)


@app.route("/status")
def status():
    try:
        files = sorted(os.listdir(IPA_DIR))
    except Exception:
        files = []
    return jsonify({"current": read_meta(), "files": files, "base": PUBLIC_BASE_URL})


@app.route("/upload", methods=["POST"])
def upload():
    token = request.form.get("token", "")
    if token != ADMIN_TOKEN:
        return jsonify({"ok": False, "msg": "口令错误，禁止上传"}), 403

    f = request.files.get("ipa")
    if not f or not f.filename:
        return jsonify({"ok": False, "msg": "没有选择文件"}), 400

    version = (request.form.get("version") or "").strip()
    build = (request.form.get("build") or "").strip()
    notes = (request.form.get("notes") or "").strip()

    # 未手填时，尝试从文件名解析
    if not version or not build:
        m = NAME_RE.match(f.filename)
        if m:
            version, build = m.group(1), m.group(2)

    if not version or not build:
        return jsonify(
            {"ok": False, "msg": "请填写版本号和构建号（或把文件名改成 LUIYo-版本-b构建.ipa）"}
        ), 400
    if not re.match(r"^[0-9]+(\.[0-9]+){0,3}$", version):
        return jsonify({"ok": False, "msg": "版本号格式不对（应如 13.1）"}), 400
    if not re.match(r"^[1-9][0-9]*$", build):
        return jsonify({"ok": False, "msg": "构建号格式不对（应为纯数字，如 34620）"}), 400

    name = "LUIYo-%s-b%s.ipa" % (version, build)
    save_path = os.path.join(IPA_DIR, name)
    f.save(save_path)

    size = os.path.getsize(save_path)
    digest = sha256_of(save_path)
    meta = write_meta(version, build, name, size, digest, notes)

    return jsonify(
        {
            "ok": True,
            "msg": "上传成功，已设为最新版本",
            "name": name,
            "size": size,
            "sha256": digest,
            "latest": meta,
        }
    )


# ---------- 上传页面 ----------
INDEX_HTML = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>LUIYo 更新后台</title>
<style>
:root{--bg:#f6f7f9;--card:#fff;--fg:#1c1e21;--muted:#666;--accent:#2f7cf6;--border:#e3e6ea}
@media (prefers-color-scheme:dark){:root{--bg:#151719;--card:#1e2124;--fg:#e8eaed;--muted:#9aa0a6;--accent:#5b9bff;--border:#2e3236}}
*{box-sizing:border-box}
body{margin:0;padding:24px;background:var(--bg);color:var(--fg);font-family:-apple-system,BlinkMacSystemFont,"PingFang SC","Microsoft YaHei",sans-serif}
.wrap{max-width:620px;margin:0 auto}
h1{font-size:20px;margin:0 0 4px}
.sub{color:var(--muted);font-size:13px;margin-bottom:20px}
.card{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:18px;margin-bottom:16px}
label{display:block;font-size:13px;margin:12px 0 6px;color:var(--muted)}
input,textarea{width:100%;padding:10px;border:1px solid var(--border);border-radius:8px;background:transparent;color:var(--fg);font-size:14px}
textarea{min-height:70px;resize:vertical}
button{margin-top:16px;width:100%;padding:12px;background:var(--accent);color:#fff;border:0;border-radius:8px;font-size:15px;cursor:pointer}
button:disabled{opacity:.6}
.msg{margin-top:14px;font-size:13px;white-space:pre-wrap;word-break:break-all}
.ok{color:#22a06b}.err{color:#e0453b}
.cur{font-size:13px;color:var(--muted)}
.cur b{color:var(--fg)}
code{background:rgba(127,127,127,.15);padding:2px 5px;border-radius:4px;font-size:12px;word-break:break-all}
</style>
</head>
<body>
<div class="wrap">
<h1>LUIYo 更新后台</h1>
<div class="sub">上传 IPA → 自动算 sha256 → 自动生成 latest.json → App 检查更新即可发现</div>

<div class="card">
  <div class="cur">当前线上版本：<b id="cur">读取中…</b></div>
</div>

<div class="card">
  <label>上传口令</label>
  <input id="token" type="password" placeholder="服务端配置的 ADMIN_TOKEN">

  <label>IPA 文件</label>
  <input id="file" type="file" accept=".ipa">

  <label>版本号（如 13.1）</label>
  <input id="version" placeholder="13.1">

  <label>构建号（如 34620，要比旧的大）</label>
  <input id="build" placeholder="34620">

  <label>更新说明</label>
  <textarea id="notes" placeholder="本次更新：修复闪退，优化启动速度"></textarea>

  <button id="btn" onclick="doUpload()">上传并发布</button>
  <div class="msg" id="msg"></div>
</div>

<div class="card">
  <div class="cur">App 更新源地址（填进 App）：<br><code id="url">/latest.json</code></div>
</div>
</div>

<script>
async function loadStatus(){
  try{
    const r = await fetch('/status'); const j = await r.json();
    const c = j.current;
    document.getElementById('cur').textContent =
      c ? (c.tag_name + '   ' + (c.assets[0] ? c.assets[0].name : '')) : '（尚未上传任何版本）';
    const base = j.base || location.origin;
    document.getElementById('url').textContent = base + '/latest.json';
  }catch(e){ document.getElementById('cur').textContent = '读取失败'; }
}
async function doUpload(){
  const btn = document.getElementById('btn'), msg = document.getElementById('msg');
  const f = document.getElementById('file').files[0];
  if(!f){ msg.className='msg err'; msg.textContent='请先选择 IPA 文件'; return; }
  const fd = new FormData();
  fd.append('token', document.getElementById('token').value);
  fd.append('version', document.getElementById('version').value);
  fd.append('build', document.getElementById('build').value);
  fd.append('notes', document.getElementById('notes').value);
  fd.append('ipa', f);
  btn.disabled = true; btn.textContent = '上传中…';
  msg.className = 'msg'; msg.textContent = '正在上传并计算 sha256…';
  try{
    const r = await fetch('/upload', {method:'POST', body:fd});
    const j = await r.json();
    if(j.ok){
      msg.className='msg ok';
      msg.textContent = '✅ ' + j.msg + '\\n文件: ' + j.name + '\\n大小: ' + j.size + ' 字节\\nsha256: ' + j.sha256;
      loadStatus();
    }else{
      msg.className='msg err'; msg.textContent = '❌ ' + j.msg;
    }
  }catch(e){ msg.className='msg err'; msg.textContent = '❌ 上传失败: ' + e; }
  btn.disabled = false; btn.textContent = '上传并发布';
}
loadStatus();
</script>
</body>
</html>
"""


if __name__ == "__main__":
    port = int(os.environ.get("PORT") or 5000)
    app.run(host="0.0.0.0", port=port)
