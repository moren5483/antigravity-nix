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
        xorg.libX11
        xorg.libXcomposite
        xorg.libXdamage
        xorg.libXext
        xorg.libXfixes
        xorg.libXrandr
        xorg.libXrender
        xorg.libXi
        xorg.libXcursor
        xorg.libXScrnSaver
        xorg.libxcb
        xorg.libxshmfence
      ];
    runScript = launcher;
  };

  # 汉化：antigravity_chinese_v2（MIT）源码 + Linux 补丁
  # 来源：https://github.com/nianshou555qiansui/antigravity_chinese_v2
  zhTool = pkgs.stdenvNoCC.mkDerivation {
    pname = "antigravity-chinese-v2";
    version = "main-2026-11";
    src = pkgs.fetchurl {
      url = "https://codeload.github.com/nianshou555qiansui/antigravity_chinese_v2/tar.gz/refs/heads/main";
      hash = "sha256-3CKuLEqfU06Q/plE7WXoyRr95fI6TBuZYNqKiv5kxwU=";
    };

    unpackPhase = "tar -xzf $src";
    sourceRoot = "antigravity_chinese_v2-main";
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
    comment = "Google Antigravity agent platform";
    categories = [ "Development" ];
    mimeTypes = [ "x-scheme-handler/antigravity" ];
  };

  desktopZh = pkgs.makeDesktopItem {
    name = "antigravity-app-zh";
    exec = "antigravity-app-zh";
    desktopName = "Antigravity App 中文";
    comment = "Google Antigravity App（启动时自动注入简体中文）";
    genericName = "Antigravity 中文";
    categories = [ "Development" ];
    mimeTypes = [ "x-scheme-handler/antigravity" ];
  };
in
{
  inherit app wrapped zhTool zhLauncher desktop desktopZh version;
}
