# NixOS 模块：安装 Antigravity App + 中文启动器 + 桌面项
{ pkgs, ... }:

let
  p = import ../pkgs/antigravity-app.nix { inherit pkgs; };
in
{
  environment.systemPackages = [
    p.wrapped
    p.wrappedZh
    p.icons
    p.desktop
    p.desktopZh
    p.zhLicenses
  ];

  # 浏览器 OAuth 回调 antigravity:// 交给 App（英文入口，避免注入器与运行中实例冲突）
  xdg.mime.defaultApplications."x-scheme-handler/antigravity" = "antigravity-app.desktop";
}
