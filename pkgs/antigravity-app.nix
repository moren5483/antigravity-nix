# Google Antigravity App（2.x agent 平台）+ 中文注入工具，返回可复用的组件集合。
{ pkgs }:

let
  version = "2.34.0";
  build = "5887025308631040";

  src = pkgs.fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/${version}-${build}/linux-x64/Antigravity.tar.gz";
    hash = "sha256-R4xo+Gye9hpQIYWjnpzuxmsSdqalOxkaGbDZzoaYNts=";
  };

  app = pkgs.stdenvNoCC.mkDerivation {
    pname = "antigravity-app-unwrapped";
    inherit version src;
    unpackPhase = "tar -xzf $src";
    installPhase = ''
      mkdir -p $out/opt
      cp -a Antigravity-x64 $out/opt/antigravity
    '';
  };

  launcher = pkgs.writeShellScript "antigravity-app" ''
    # 某些桌面环境会带 ELECTRON_RUN_AS_NODE，Electron 会退化成 Node 而不是 GUI
    unset ELECTRON_RUN_AS_NODE NODE_OPTIONS
    exec ${app}/opt/antigravity/antigravity "$@"
  '';

  wrapped = pkgs.buildFHSEnv {
    name = "antigravity-app";
    targetPkgs =
      p: with p;
      [
        alsa-lib
        at-spi2-atk
        at-spi2-core
        cairo
        cups
        dbus
        expat
        glib
        gtk3
        libdrm
        libGL
        libgbm
        libnotify
        libpulseaudio
        libxkbcommon
        libsecret
        nspr
        nss
        pango
        systemd
        udev
        # xorg 包集已被 nixpkgs 弃用（aliases.nix, 2026-01-29），改用顶层小写属性
        libx11
        libxcomposite
        libxcursor
        libxdamage
        libxext
        libxfixes
        libxi
        libxrandr
        libxrender
        libxscrnsaver
        libxcb
        libxshmfence
      ];
    runScript = launcher;
  };

  # 图标：Antigravity 把图标放在 app.asar 里，构建时提取
  icons = pkgs.runCommand "antigravity-app-icons" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    mkdir -p $out/share/icons/hicolor/512x512/apps
    python3 ${./extract-asar-icon.py} \
      ${app}/opt/antigravity/resources/app.asar \
      $out/share/icons/hicolor/512x512/apps/antigravity-app.png
  '';

  # 汉化：antigravity_chinese_v2（MIT）源码 + Linux 补丁
  # 来源：https://github.com/nianshou555qiansui/antigravity_chinese_v2
  # 钉死 commit 而不是 refs/heads/main：否则上游每 push 一次，hash 就失配、所有人都构建失败。
  # 升级步骤：把 zhRev 换成新的 commit，重新取 hash（nix store prefetch-file <url>）。
  zhRev = "1f5747c376369a45f40d9abebeedee09d6f3b6fe";

  zhTool = pkgs.stdenvNoCC.mkDerivation {
    pname = "antigravity-chinese-v2";
    version = "unstable-${builtins.substring 0 7 zhRev}";
    src = pkgs.fetchurl {
      url = "https://codeload.github.com/nianshou555qiansui/antigravity_chinese_v2/tar.gz/${zhRev}";
      hash = "sha256-l9t5WkGOvYWEF4T5FaKzRf54AERveII5H+zjai5gcCs=";
    };

    unpackPhase = "tar -xzf $src";
    sourceRoot = "antigravity_chinese_v2-${zhRev}";
    nativeBuildInputs = [ pkgs.python3 ];
    postPatch = ''
      ${pkgs.python3}/bin/python3 ${./antigravity-zh-linux.py} .
    '';
    installPhase = ''
      mkdir -p $out/share/antigravity-zh
      cp -r . $out/share/antigravity-zh/
    '';
  };

  pythonEnv = pkgs.python3.withPackages (ps: [ ps.websockets ]);

  zhLauncher = pkgs.writeShellScriptBin "antigravity-app-zh" ''
    export PATH=${wrapped}/bin:$PATH
    log="$HOME/.cache/antigravity-zh.log"
    mkdir -p "$(dirname "$log")"

    if pgrep -f "opt/antigravity/antigravity" >/dev/null 2>&1; then
      msg="请先完全退出 Antigravity App，再从“Antigravity App 中文”启动"
      command -v notify-send >/dev/null 2>&1 && notify-send "Antigravity 汉化" "$msg" || echo "$msg" >&2
      exit 1
    fi

    exec ${pythonEnv}/bin/python ${zhTool}/share/antigravity-zh/hanhua_v2.py "$@" 2>&1 | tee -a "$log"
  '';

  desktop = pkgs.makeDesktopItem {
    name = "antigravity-app";
    exec = "antigravity-app %U";
    desktopName = "Antigravity App";
    icon = "antigravity-app";
    comment = "Google Antigravity agent platform";
    categories = [ "Development" ];
    mimeTypes = [ "x-scheme-handler/antigravity" ];
  };

  desktopZh = pkgs.makeDesktopItem {
    name = "antigravity-app-zh";
    exec = "antigravity-app-zh";
    desktopName = "Antigravity App 中文";
    icon = "antigravity-app";
    comment = "Google Antigravity App（启动时自动注入简体中文）";
    genericName = "Antigravity 中文";
    categories = [ "Development" ];
    mimeTypes = [ "x-scheme-handler/antigravity" ];
  };
in
{
  inherit app wrapped icons zhTool zhLauncher desktop desktopZh version;
}
