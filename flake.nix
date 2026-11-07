{
  description = "Basalt — a Hyprland and quickshell desktop: the config, the shell, and the hypr* tools around them";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # The builders a Nix host uses; see nix/lib.nix.
      lib = import ./nix/lib.nix { inherit (nixpkgs) lib; };

      # The whole desktop as one NixOS module; see nix/module.nix.
      nixosModules.default = import ./nix/module.nix self.lib;

      packages = forAll (pkgs: rec {
        scripts = self.lib.scripts { inherit pkgs; };
        wallpaper = self.lib.wallpaper { inherit pkgs; };
        default = scripts;
      });

      checks = forAll (
        pkgs:
        import ./nix/checks.nix {
          inherit pkgs nixpkgs;
          basalt = self.lib;
          module = self.nixosModules.default;
        }
      );

      formatter = forAll (pkgs: pkgs.nixfmt-tree);
    };
}
