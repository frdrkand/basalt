# `nix flake check`: Basalt against itself, through the same builders a host
# uses, so what is checked here is what a host gets.
{
  pkgs,
  nixpkgs,
  basalt,
  module,
}:
let
  inherit (pkgs) lib;
  inherit (basalt) theme;

  # The example host's settings, both ways a display can be described.
  derived = basalt.hyprlandConfig {
    inherit pkgs;
    settings = {
      display.maxMonitors = 2;
      touchpad.natural_scroll = true;
    };
    extraConfig = builtins.readFile ../examples/hypr/hyprland.lua;
  };
  declared = basalt.hyprlandConfig {
    inherit pkgs;
    settings = {
      display.outputs = [
        {
          name = "DP-1";
          mode = "2560x1440@59.95";
          position = "1920x0";
        }
        {
          name = "HDMI-A-1";
          mode = "1920x1080@60";
          position = "0x100";
          workspaces = 4;
        }
      ];
      programs.screenshot = "${basalt.scripts { inherit pkgs; }}/bin/basalt-screenshot";
      autostart = [
        "hyprpaper"
        "dunst"
      ];
      palette = theme.palette;
    };
  };

  shell = basalt.quickshellConfig {
    inherit pkgs;
    host = ../examples/quickshell/Host.qml;
  };
  generatedShell = basalt.quickshellConfig {
    inherit pkgs;
    settings = {
      palette = theme.palette;
      fonts = { inherit (theme.fonts) ui mono glyph; };
      launchCommand = [
        "uwsm"
        "app"
        "--"
        "{id}.desktop"
      ];
      updatesStatus = [
        "snout"
        "has-updates"
        "--json"
      ];
    };
  };

  # theme.json is the canonical palette; these files repeat it in their own
  # syntax, and must not drift from it.
  palette = pkgs.runCommand "basalt-palette-agrees" { } ''
    fail=0
    check() { grep -qF -- "$2" "$1" || { echo "$1: missing $2"; fail=1; }; }
    ${lib.concatStrings (
      lib.mapAttrsToList (k: v: ''
        check ${../hypr/palette.lua} '${k} = "${v}"'
        check ${../hypr/palette.conf} '${"$"}${k} = ${v}'
        check ${../quickshell/HostConfig.qml} '${k}: "${v}"'
      '') theme.palette
    )}
    # The files that spell the palette out literally: every colour in them
    # must be one of the palette's, or the recolouring would miss it. The
    # exceptions are not palette colours on purpose: black for Qt's shadow
    # role, and GTK's three hand-darkened tints (gtk-4.0/colors.css says why).
    allowed=" ${lib.concatStringsSep " " (lib.attrValues theme.palette)} 000000 123a1c 3a2f04 39393d "
    for f in ${
      lib.concatMapStringsSep " " toString [
        ../dunst/dunstrc
        ../kitty/kitty.conf
        ../starship/starship.toml
        ../yazi/theme.toml
        ../yazi/init.lua
        ../gtk/gtk-3.0/colors.css
        ../gtk/gtk-4.0/colors.css
        ../qt/base16.conf
      ]
    }; do
      for hex in $(grep -oiE '#[0-9a-f]{6}' "$f" | tr A-F a-f | sort -u); do
        case "$allowed" in
          *" ''${hex#\#} "*) ;;
          *) echo "$f: $hex is not in the palette"; fail=1 ;;
        esac
      done
    done
    # The faces in fontconfig and the gsettings script.
    for face in "${theme.fonts.ui}" "${theme.fonts.mono}"; do
      check ${../fontconfig/50-basalt.conf} "<family>$face</family>"
    done
    check ${../bin/basalt-gsettings} "font-name '${theme.fonts.ui} ${toString theme.fonts.size}'"
    check ${../bin/basalt-gsettings} "monospace-font-name '${theme.fonts.mono} ${toString theme.fonts.size}'"
    check ${../bin/basalt-gsettings} "gtk-theme '${theme.gtkTheme}'"
    check ${../bin/basalt-gsettings} "icon-theme '${theme.icons}'"
    check ${../bin/basalt-gsettings} "cursor-theme '${theme.cursor.name}'"
    check ${../bin/basalt-gsettings} "cursor-size ${toString theme.cursor.size}"
    [ $fail = 0 ] && touch $out
  '';

  # The module, in a whole NixOS system, the way a host uses it: every piece
  # on, declared monitors, the updates commands set.
  system =
    (nixpkgs.lib.nixosSystem {
      modules = [
        module
        {
          nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
          nixpkgs.config.allowUnfree = true;
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "/dev/null";
            fsType = "ext4";
          };
          system.stateVersion = "26.05";
          basalt = {
            enable = true;
            display.outputs = [
              {
                name = "DP-1";
                mode = "2560x1440@60";
                position = "0x0";
              }
            ];
            updates.status = [
              "snout"
              "has-updates"
              "--json"
            ];
            idle.action = "blank-when-locked";
          };
        }
      ];
    }).config;
in
{
  hyprland-derived = basalt.verifyHyprland {
    inherit pkgs;
    config = derived;
  };
  hyprland-declared = basalt.verifyHyprland {
    inherit pkgs;
    config = declared;
  };
  quickshell = basalt.lintQuickshell {
    inherit pkgs;
    config = shell;
  };
  quickshell-generated = basalt.lintQuickshell {
    inherit pkgs;
    config = generatedShell;
  };
  inherit palette;
  shellcheck =
    pkgs.runCommand "basalt-bin-shellchecked" { nativeBuildInputs = [ pkgs.shellcheck ]; }
      ''
        shellcheck -S warning ${../bin}/*
        touch $out
      '';
  zsh = pkgs.runCommand "basalt-zsh-parses" { nativeBuildInputs = [ pkgs.zsh ]; } ''
    zsh -n ${../zsh/init.zsh}
    zsh -n ${../zsh/finish.zsh}
    touch $out
  '';
  module = system.system.build.toplevel;
  module-hyprland = basalt.verifyHyprland {
    inherit pkgs;
    config = system.basalt.build.hyprland;
  };
  module-quickshell = basalt.lintQuickshell {
    inherit pkgs;
    config = system.basalt.build.quickshell;
  };
  scripts = basalt.scripts { inherit pkgs; };
  wallpaper = basalt.wallpaper {
    inherit pkgs;
    width = 640;
    height = 360;
  };
  confs = pkgs.linkFarm "basalt-confs" {
    "hyprlock.conf" = basalt.hyprlockConf { inherit pkgs; };
    "hypridle.conf" = basalt.hypridleConf { inherit pkgs; };
    "hyprpaper.conf" = basalt.hyprpaperConf {
      inherit pkgs;
      wallpaper = "/dev/null";
    };
    "dunstrc" = basalt.dunstrc { inherit pkgs; };
  };
}
