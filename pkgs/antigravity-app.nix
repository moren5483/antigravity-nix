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

    # App 跑在 bwrap 沙箱里，宿主机 /proc 看不到 /opt/antigravity/antigravity 这个 cmdline，
    # 所以 pgrep 不可靠。改用 Electron 单实例锁里记录的宿主机 PID 判断存活。
    app_pid() {
      local lock link
      lock="''${XDG_CONFIG_HOME:-$HOME/.config}/Antigravity/SingletonLock"
      link="$(readlink "$lock" 2>/dev/null)" || return 1
      printf '%s\n' "''${link##*-}"
    }

    app_running() {
      local pid
      pid="$(app_pid)" || return 1
      [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
    }

    if app_running; then
      msg="请先完全退出 Antigravity App，再从“Antigravity App 中文”启动"
      command -v notify-send >/dev/null 2>&1 && notify-send "Antigravity 汉化" "$msg" || echo "$msg" >&2
      exit 1
    fi

    ${pythonEnv}/bin/python ${zhTool}/share/antigravity-zh/hanhua_v2.py "$@" 2>&1 | tee -a "$log"

    # 关键：不要在这里退出。
    # 桌面启动器（uwsm / noctalia 等）把 .desktop 的 Exec 包成 app-*.scope，
    # 本进程就是该 scope 的主进程；注入器跑完就退出会让 scope 被回收，
    # 连带把同一个 scope 里的 App SIGKILL 掉（表现为“窗口自己消失”，无任何日志）。
    # 所以驻留到 App 真正退出为止，与英文入口（Exec 就是 App）行为一致。
    while app_running; do
      sleep 2
    done
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
