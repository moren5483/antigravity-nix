"""构建期把中文翻译引擎作为 preload 注入 app.asar 的副本。

与旧方案的区别：不再用 --remote-debugging-port + CDP 运行时注入，而是
把引擎写进 app.asar，作为 BrowserWindow 的 preload 随页面加载自动执行。
因此不需要调试端口、不需要常驻启动器进程，页面重载后也不会丢汉化。

只修改构建产物里的副本；官方 tarball 与安装目录一概不动。

用法：
    python3 inject-zh-preload.py --asar <app.asar> --engine-dir <上游源码目录>
"""
import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

PRELOAD_PATH = "/dist/ag-zh-preload.js"
MAIN_PATH = "/dist/main.js"
MARKER = "antigravity-nix: 注册中文 preload"
BLOCK_SIZE = 4194304

# 信任判断：只翻译 App 自家的页面。
# preload 会被注册到整个 session，内置浏览器里打开的外部网站也会跑到这里，
# 没有这层判断就会去改别人网页的 DOM。
TRUST_PRELUDE = """/* antigravity-nix: 中文 preload（构建期注入，改动见仓库 README） */
window.__agTrustedPage = () => {
  try {
    const u = new URL(location.href);
    if (u.protocol === 'plugin:') return true;
    return (u.protocol === 'https:' || u.protocol === 'http:') &&
           (u.hostname === '127.0.0.1' || u.hostname === 'localhost');
  } catch (e) { return false; }
};
"""

# 插到 dist/main.js 的 "use strict"; 之后，保证严格模式仍然生效
MAIN_PATCH = """
/* %s */
;(() => {
  try {
    const { app, session } = require('electron');
    const path = require('path');
    const preload = path.join(__dirname, 'ag-zh-preload.js');
    const install = (s) => {
      try {
        const current = typeof s.getPreloads === 'function' ? s.getPreloads() : [];
        if (!current.includes(preload)) s.setPreloads([...current, preload]);
      } catch (e) {}
    };
    app.on('session-created', install);
    const installDefault = () => { try { install(session.defaultSession); } catch (e) {} };
    if (typeof app.isReady === 'function' && app.isReady()) installDefault();
    else app.whenReady().then(installDefault).catch(() => {});
  } catch (e) {}
})();
""" % MARKER


def die(msg):
    raise SystemExit(f"[inject-zh] {msg}")


def parse_asar(data):
    magic, header_size, payload, json_len = struct.unpack("<IIII", data[:16])
    if magic != 4:
        die(f"不是 asar 文件（首字段 {magic}）")
    header = json.loads(data[16:16 + json_len])
    return header, 8 + header_size


def pack_asar(header, blobs):
    json_bytes = json.dumps(header, ensure_ascii=False, separators=(",", ":")).encode()
    padded = (len(json_bytes) + 3) // 4 * 4
    payload = 4 + padded
    header_size = 4 + payload
    prefix = struct.pack("<IIII", 4, header_size, payload, len(json_bytes))
    return prefix + json_bytes + b"\0" * (padded - len(json_bytes)) + blobs


def walk(node, path=""):
    for name, item in node.get("files", {}).items():
        here = f"{path}/{name}"
        if "files" in item:
            yield from walk(item, here)
        else:
            yield here, item


def integrity(blob):
    return {
        "algorithm": "SHA256",
        "hash": hashlib.sha256(blob).hexdigest(),
        "blockSize": BLOCK_SIZE,
        "blocks": [
            hashlib.sha256(blob[i:i + BLOCK_SIZE]).hexdigest()
            for i in range(0, max(len(blob), 1), BLOCK_SIZE)
        ] or [hashlib.sha256(b"").hexdigest()],
    }


def build_preload(engine_dir):
    sys.path.insert(0, str(engine_dir))
    import hanhua_v2  # 上游引擎构建逻辑，保证与运行时版本一致

    entries = hanhua_v2.load_dictionary()
    if not entries:
        die(f"{engine_dir} 下没有读到任何词条")
    engine = hanhua_v2.build_engine_js(entries)
    print(f"[inject-zh] 词条 {len(entries)} 条，引擎 {len(engine)} 字节")
    return TRUST_PRELUDE + engine


def patch_asar(asar_path, engine_dir):
    data = asar_path.read_bytes()
    header, base = parse_asar(data)

    blobs = {}
    for path, item in walk(header):
        if "offset" in item:
            start = base + int(item["offset"])
            blobs[path] = data[start:start + int(item["size"])]

    if MAIN_PATH not in blobs:
        die(f"{MAIN_PATH} 不存在，asar 结构与预期不符")
    if PRELOAD_PATH in blobs:
        die("该 asar 已经注入过中文 preload")

    source = blobs[MAIN_PATH].decode("utf-8")
    if source.startswith('"use strict";'):
        patched = '"use strict";\n' + MAIN_PATCH + source[len('"use strict";'):]
    else:
        # 没有严格模式指令时直接前置，不影响语义
        patched = MAIN_PATCH + source
    blobs[MAIN_PATH] = patched.encode("utf-8")

    preload = build_preload(engine_dir).encode("utf-8")
    dist = header["files"]["dist"]["files"]
    if "main.js" not in dist:
        die("dist/main.js 不在 dist 目录下")
    dist["ag-zh-preload.js"] = {"size": len(preload)}
    blobs[PRELOAD_PATH] = preload

    chunks = []
    offset = 0
    for path, item in walk(header):
        if "unpacked" in item:
            continue  # 留在 app.asar.unpacked 里，原样不动
        if path not in blobs:
            continue
        blob = blobs[path]
        item["offset"] = str(offset)
        item["size"] = len(blob)
        item["integrity"] = integrity(blob)
        chunks.append(blob)
        offset += len(blob)

    out = pack_asar(header, b"".join(chunks))

    # 先回读校验，确认写出来的 asar 能被重新解析、补丁都在，再落盘
    check_header, check_base = parse_asar(out)
    check = {
        p: out[check_base + int(i["offset"]):check_base + int(i["offset"]) + int(i["size"])]
        for p, i in walk(check_header) if "offset" in i
    }
    if MARKER.encode() not in check[MAIN_PATH]:
        die("回读校验失败：main.js 里没有补丁标记")
    if len(check[PRELOAD_PATH]) != len(preload):
        die("回读校验失败：preload 长度不符")

    asar_path.write_bytes(out)
    print(
        f"[inject-zh] 完成：文件 {len(check)} 个，"
        f"asar {len(out)} 字节（原 {len(data)}），preload {len(preload)} 字节"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--asar", required=True, type=Path)
    parser.add_argument("--engine-dir", required=True, type=Path)
    args = parser.parse_args()
    if not args.asar.is_file():
        die(f"{args.asar} 不存在")
    patch_asar(args.asar, args.engine_dir)


if __name__ == "__main__":
    main()
