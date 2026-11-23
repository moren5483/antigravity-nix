# Third-party notices

## antigravity_chinese_v2

- 仓库：https://github.com/nianshou555qiansui/antigravity_chinese_v2
- 许可：MIT License
- 版权：Copyright (c) 2026 nianshou555qiansui
- 使用方式：构建时从上游仓库获取源码（钉在固定 commit），用其 `load_dictionary` / `build_engine_js`
  生成 DOM 翻译引擎，并作为 `preload` 写入 `app.asar` 的副本。因此**引擎与词典（约 3989 条）会随包分发**，
  上游 MIT 许可证一并安装到 `share/antigravity-zh/LICENSE`。本仓库不修改词典内容与翻译文本。

## Google Antigravity

- 官网：https://antigravity.google/
- 本仓库仅包含获取与运行官方 Linux 发行包的 Nix 表达式，不分发其二进制；使用须遵守 Google 的服务条款。
- 中文包在构建产物中对 `app.asar` 做了注入，但**官方安装包与官方 tarball 本身不被修改**。
