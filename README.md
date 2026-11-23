# antigravity-nix

在 NixOS 上安装 **Google Antigravity App**（2.x agent 平台，不是 IDE），并可选地自动注入**简体中文**界面。

- 只用官方 Google 发布的 Linux tarball，不打补丁、不重打包二进制
- 中文通过 [antigravity_chinese_v2](https://github.com/nianshou555qiansui/antigravity_chinese_v2)（MIT）的 CDP 注入实现，仅作用于运行时内存，不修改安装文件
- 提供两个桌面项：**Antigravity App**（英文原版）和 **Antigravity App 中文**（启动时注入中文）

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

中文启动器会：

1. 检查是否已有 App 在运行（单实例会把调试端口吃掉，所以要求先退出）
2. 带 `--remote-debugging-port` 启动 App
3. 通过 CDP 注入词典（约 3989 条）并持续监听新窗口
4. 日志写到 `~/.cache/antigravity-zh.log`

> 注入只存在于内存：**每次都要从中文入口启动**才有中文；从英文入口打开就是原版。

## 汉化来源 / Credits

- **汉化工具**：[nianshou555qiansui/antigravity_chinese_v2](https://github.com/nianshou555qiansui/antigravity_chinese_v2)（MIT License）
  - 上游面向 Windows / macOS，本仓库仅在构建时追加 Linux 兼容补丁（进程/端口发现、`--port` 直连、可执行文件探测），不修改词典与翻译内容
  - 词典约 3989 条，版权归上游作者所有
- **App 本体**：Google 官方发布，从 `storage.googleapis.com/antigravity-public/...` 获取，本仓库不分发二进制

## 已知限制

- **登录地区限制**：Antigravity 需要 Google 账号，部分国家/地区会提示 "not available in your location"。这与汉化无关，本仓库不提供解锁。
- App 与 [Antigravity IDE](https://antigravity.google/) 是两个产品；本仓库只打包 App。
- App 的 `app.asar` 是 Google 的闭源产物，本仓库只提供获取与运行方式，不分发其二进制。
- 版本升级需要同步修改 `pkgs/antigravity-app.nix` 里的 `version`、`build` 与 `hash`（哈希可先用 `nix store prefetch-file` 取得）。
- 汉化工具钉在上游的固定 commit（`zhRev`），上游 `main` 前进**不会**破坏本仓库的构建；升级汉化需手动改 `zhRev` 与 `hash`。
- `flake.lock` 已提交，`nixos-unstable` 被锁定到具体 commit；需要跟进 unstable 时执行 `nix flake update nixpkgs`。

## 许可

- 本仓库的 Nix 表达式：MIT
- 汉化工具 `antigravity_chinese_v2`：MIT
- Antigravity 本体：Google 的专有软件，需遵守其服务条款
