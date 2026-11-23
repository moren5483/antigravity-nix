# antigravity-nix

在 NixOS 上安装 **Google Antigravity App**（2.x agent 平台，不是 IDE），并可选地自动注入**简体中文**界面。

- 只用官方 Google 发布的 Linux tarball，不修改官方安装包
- 中文通过 [antigravity_chinese_v2](https://github.com/nianshou555qiansui/antigravity_chinese_v2)（MIT）的词典与引擎实现：**构建期**把引擎作为 `preload` 注入 `app.asar` 的副本
- 提供两个桌面项：**Antigravity App**（英文原版）和 **Antigravity App 中文**（开箱即中文，无调试端口、无常驻进程）

## 安装

```nix
# flake.nix
{
  inputs.antigravity-nix.url = "github:moren5483/antigravity-nix";

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        antigravity-nix.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

```bash
sudo nixos-rebuild switch --flake .#myhost
```

装完后启动器里会出现「Antigravity App」和「Antigravity App 中文」。

## 用法

- **英文**：启动器点「Antigravity App」，或终端 `antigravity-app`
- **中文**：启动器点「Antigravity App 中文」，或终端 `antigravity-app-zh`

中文版不是运行时注入，而是构建期就改好了：

1. 构建时复制官方解包产物，把翻译引擎（约 3989 条词条）写进 `app.asar` 的副本，并注册为窗口 `preload`
2. 启动时没有任何注入器进程、没有 `--remote-debugging-port`，页面加载即自动翻译
3. 页面重载、切换标签页都不会丢汉化（之前的 CDP 方案重载后会失效）

> 英文 / 中文是两个独立的包：从英文入口打开就是原版，从中文入口打开就是中文。
> App 是单实例的，**先完全退出现有实例**再切换入口。

## 汉化来源 / Credits

- **汉化工具**：[nianshou555qiansui/antigravity_chinese_v2](https://github.com/nianshou555qiansui/antigravity_chinese_v2)（MIT License）
  - 词典与 DOM 翻译引擎取自上游，构建时写入 `app.asar` 副本，不改翻译内容
  - 上游面向 Windows / macOS 的 CDP 驱动逻辑本仓库不再使用；仅构建期调用其 `build_engine_js` 生成引擎
  - 词典约 3989 条，版权归上游作者所有；MIT 许可证随包安装到 `share/antigravity-zh/LICENSE`
- **App 本体**：Google 官方发布，从 `storage.googleapis.com/antigravity-public/...` 获取，本仓库不分发二进制

## 已知限制

- **登录地区限制**：Antigravity 需要 Google 账号，部分国家/地区会提示 "not available in your location"。这与汉化无关，本仓库不提供解锁。
- App 与 [Antigravity IDE](https://antigravity.google/) 是两个产品；本仓库只打包 App。
- App 的 `app.asar` 是 Google 的闭源产物，本仓库只提供获取与运行方式，不分发其二进制。
- 版本升级需要同步修改 `pkgs/antigravity-app.nix` 里的 `version`、`build` 与 `hash`（哈希可先用 `nix store prefetch-file` 取得）。因为是构建期注入，App 升级后重新构建即可，不会出现"更新后又变回英文"。
- 词典基于上游适配的 **2.32.1**，App 目前是 **2.34.0**：2.34 新增的界面文案可能仍是英文。
- `preload` 只作用于窗口主框架，`plugin://` 子框架（Sidecar 伴生面板）暂不翻译。
- 汉化工具钉在上游的固定 commit（`zhRev`），上游 `main` 前进**不会**破坏本仓库的构建；升级汉化需手动改 `zhRev` 与 `hash`。
- `flake.lock` 已提交，`nixos-unstable` 被锁定到具体 commit；需要跟进 unstable 时执行 `nix flake update nixpkgs`。

## 许可

- 本仓库的 Nix 表达式：MIT
- 汉化工具 `antigravity_chinese_v2`：MIT
- Antigravity 本体：Google 的专有软件，需遵守其服务条款
