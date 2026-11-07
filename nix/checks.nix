# `nix flake check`: Basalt against itself, through the same builders a host
# uses, so what is checked here is what a host gets.
{ pkgs, basalt }:
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
    # dunstrc spells colours with an alpha suffix sometimes; every colour in it
    # must be one of the palette's.
    for hex in $(grep -oE '#[0-9a-f]{6}' ${../dunst/dunstrc} | sort -u); do
      case " ${lib.concatStringsSep " " (lib.attrValues theme.palette)} " in
        *" ''${hex#\#} "*) ;;
        *) echo "dunstrc: $hex is not in the palette"; fail=1 ;;
      esac
    done
    [ $fail = 0 ] && touch $out
  '';
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
