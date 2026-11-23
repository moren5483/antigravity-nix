{
  description = "Google Antigravity App (Linux, FHS) with optional Chinese UI injection";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      parts = import ./pkgs/antigravity-app.nix { inherit pkgs; };
    in
    {
      packages.${system} = {
        default = parts.wrapped;
        antigravity-app = parts.wrapped;
        antigravity-app-zh = parts.zhLauncher;
      };

      nixosModules.default = ./modules/antigravity-app.nix;
      nixosModules.antigravity-app = ./modules/antigravity-app.nix;
    };
}
