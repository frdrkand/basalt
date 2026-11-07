# Basalt as a NixOS module: the whole desktop from one `basalt` option set.
#
#   imports = [ inputs.basalt.nixosModules.default ];
#   basalt = {
#     enable = true;
#     display.outputs = [ { name = "DP-1"; mode = "2560x1440@60"; position = "0x0"; } ];
#     updates.status = [ "snout" "has-updates" "--json" ];
#   };
#
# Every program is wrapped so its config comes from the store (built from
# Basalt's files, recoloured into `basalt.theme`) and nothing under ~/.config
# is read, except where GTK and Qt leave no other way: those few files are
# linked into $HOME by systemd user tmpfiles, re-applied on every switch.
#
# Each piece can be turned off (`basalt.<piece>.enable = false`) for a host
# that provides it some other way. The login screen, the user's login shell and
# default applications stay the host's.
basaltLib:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    mkMerge
    types
    ;
  cfg = config.basalt;
  basalt = basaltLib;
  t = cfg.theme;

  themed =
    src:
    basalt.recolorFile {
      inherit pkgs src;
      inherit (t) palette fonts;
    };
  themedDir =
    src: name:
    basalt.recolorDir {
      inherit pkgs src name;
      inherit (t) palette fonts;
    };
  wrap = args: basalt.wrapPackage ({ inherit pkgs; } // args);

  piece = description: {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether Basalt provides ${description}.";
    };
  };

  outputType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Wayland connector name.";
      };
      mode = mkOption {
        type = types.str;
        default = "preferred";
        example = "2560x1440@59.95";
        description = "Hyprland mode, WIDTHxHEIGHT@RATE.";
      };
      position = mkOption {
        type = types.str;
        default = "auto";
        example = "1920x0";
      };
      scale = mkOption {
        type = types.either types.str types.number;
        default = 1;
      };
      workspaces = mkOption {
        type = types.int;
        default = 5;
        description = "Persistent workspaces on this output.";
      };
    };
  };

  # The largest width and height among declared modes: what the wallpaper is
  # rendered at, so no monitor scales it up.
  sizes = lib.concatMap (
    o:
    let
      m = builtins.match "([0-9]+)x([0-9]+).*" o.mode;
    in
    lib.optional (m != null) {
      w = lib.toInt (lib.elemAt m 0);
      h = lib.toInt (lib.elemAt m 1);
    }
  ) (if cfg.display.outputs == null then [ ] else cfg.display.outputs);

  idleListener =
    {
      lock = ''
        listener {
            timeout = ${toString cfg.idle.timeout}
            on-timeout = loginctl lock-session
        }
      '';
      blank-when-locked = ''
        listener {
            timeout = ${toString cfg.idle.timeout}
            on-timeout = basalt-dpms off-if-locked
            on-resume = basalt-dpms on
        }
      '';
      none = "";
    }
    .${cfg.idle.action};

  scripts = basalt.scripts { inherit pkgs; };
in
{
  options.basalt = {
    enable = mkEnableOption "Basalt, the Hyprland and quickshell desktop";

    theme = {
      palette = mkOption {
        type = types.attrsOf types.str;
        default = basalt.theme.palette;
        description = "The base16 palette, as bare six-digit hex (no '#'). Default: Basalt's theme.json.";
      };
      fonts = mkOption {
        type = types.submodule {
          options = {
            ui = mkOption { type = types.str; };
            mono = mkOption { type = types.str; };
            glyph = mkOption { type = types.str; };
            size = mkOption { type = types.int; };
          };
        };
        default = basalt.theme.fonts;
        description = "The UI, monospace and glyph faces, and the base size.";
      };
      cursor = {
        name = mkOption {
          type = types.str;
          default = basalt.theme.cursor.name;
        };
        size = mkOption {
          type = types.int;
          default = basalt.theme.cursor.size;
        };
        package = mkOption {
          type = types.package;
          default = pkgs.bibata-cursors;
          defaultText = lib.literalExpression "pkgs.bibata-cursors";
        };
      };
    };

    display.outputs = mkOption {
      type = types.nullOr (types.listOf outputType);
      default = null;
      description = ''
        The monitors, in layout order: the order is the monitor number in the
        SUPER+<n> chords and the order workspace ids are handed out in. Null:
        derived from what is connected (the built-in panel first), which is
        what a laptop wants. See Basalt's hypr/config.lua.
      '';
    };

    autostart = mkOption {
      type = types.listOf types.str;
      default = [
        "hyprpaper"
        "hypridle"
        "dunst"
        "systemctl --user start hyprpolkitagent"
      ];
      description = "What starts with the session, in order, before the shell.";
    };

    hyprland = {
      settings = mkOption {
        type = types.attrs;
        default = { };
        description = "More options for basalt.setup() (hypr/config.lua), over what the module derives.";
      };
      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Lua run after basalt.setup(): the host's own binds, rules and settings.";
      };
      withUWSM = mkOption {
        type = types.bool;
        default = true;
        description = "Start Hyprland through UWSM (programs.hyprland.withUWSM).";
      };
    };

    shell = {
      settings = mkOption {
        type = types.attrs;
        default = { };
        description = "Properties for the shell's Host.qml (quickshell/HostConfig.qml), over what the module derives.";
      };
      host = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "A Host.qml of the host's own, in place of one generated from `settings`.";
      };
      extraFiles = mkOption {
        type = types.attrsOf types.path;
        default = { };
        description = "More files for the shell's config directory, beside shell.qml.";
      };
    };

    updates = {
      status = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "The updates pill's command (Basalt's updates protocol). Empty: no pill.";
      };
      details = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "The updates window's command. Empty: no details.";
      };
      check = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "The updates window's 'Check now' command. Empty: no button.";
      };
    };

    lock = piece "the lock screen (hyprlock)" // {
      extraConfig = mkOption {
        type = types.lines;
        default = ''
          background {
              monitor =
              path = ${cfg.build.wallpaper}
              blur_passes = 3
              blur_size = 8
              brightness = 0.7
              contrast = 0.9
          }
        '';
        defaultText = "the wallpaper, frosted";
        description = "hyprlock config after Basalt's look: the background, an auth block.";
      };
    };

    idle = piece "idle handling (hypridle)" // {
      action = mkOption {
        type = types.enum [
          "lock"
          "blank-when-locked"
          "none"
        ];
        default = "lock";
        description = ''
          What idling does: lock the session, or (never locking on a timer)
          blank the monitors once locked, or nothing.
        '';
      };
      timeout = mkOption {
        type = types.int;
        default = 300;
        description = "Seconds of idle before `action`.";
      };
      extraConfig = mkOption {
        type = types.lines;
        default = "";
      };
    };

    wallpaper = piece "the wallpaper (hyprpaper)" // {
      width = mkOption {
        type = types.int;
        default = if sizes == [ ] then 5120 else lib.foldl' lib.max 0 (map (s: s.w) sizes);
        defaultText = "the largest declared width, or 5120";
      };
      height = mkOption {
        type = types.int;
        default = if sizes == [ ] then 2880 else lib.foldl' lib.max 0 (map (s: s.h) sizes);
        defaultText = "the largest declared height, or 2880";
      };
    };

    shellUi = piece "the quickshell shell (bar, launcher, overlays)";
    notifications = piece "notifications (dunst)" // {
      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "dunst ini after Basalt's; a section named again merges.";
      };
    };
    kitty = piece "the terminal (kitty)" // {
      extraConfig = mkOption {
        type = types.lines;
        default = "";
      };
    };
    starship = piece "the prompt (starship)";
    zsh = piece "the shell config (zsh: oh-my-zsh, plugins, history)" // {
      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "zsh run between Basalt's init.zsh and finish.zsh.";
      };
    };
    yazi = piece "the file manager (yazi)";
    nautilus = piece "nautilus, with gvfs and file-roller, as the folder browser other programs open";
    gtk = piece "GTK theming (adw-gtk3, the palette, icons, fonts)";
    qt = piece "Qt theming (qt6ct)";
    fonts = piece "the fonts and fontconfig defaults";
    cursor = piece "the cursor theme";
    btop = piece "btop";
    fastfetch = piece "fastfetch";
    qalculate = piece "qalc (also the launcher's maths)";

    build = mkOption {
      type = types.attrs;
      readOnly = true;
      description = "What the module built: hyprland and quickshell (config directories), wallpaper.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      basalt.build = {
        hyprland = basalt.hyprlandConfig {
          inherit pkgs;
          settings = lib.recursiveUpdate (
            {
              inherit (t) palette;
              inherit (cfg) autostart;
            }
            // lib.optionalAttrs (cfg.display.outputs != null) {
              display.outputs = cfg.display.outputs;
            }
          ) cfg.hyprland.settings;
          inherit (cfg.hyprland) extraConfig;
        };

        quickshell = basalt.quickshellConfig {
          inherit pkgs;
          inherit (cfg.shell) host extraFiles;
          settings = {
            inherit (t) palette;
            fonts = { inherit (t.fonts) ui mono glyph; };
            updatesStatus = cfg.updates.status;
            updatesDetails = cfg.updates.details;
            updatesCheck = cfg.updates.check;
          }
          // cfg.shell.settings;
        };

        wallpaper = basalt.wallpaper {
          inherit pkgs;
          inherit (t) palette;
          inherit (cfg.wallpaper) width height;
        };
      };

      # Hyprland. Only `start-hyprland` is wrapped, with `-- --config <lua>`
      # (it forwards what follows `--` to Hyprland), never Hyprland itself:
      # NixOS gives the compositor cap_sys_nice through a security wrapper whose
      # source is lib.getExe of this package, and capabilities do not survive
      # another exec in front of it. mainProgram stays "Hyprland" for that
      # reason. The session entry names the unwrapped start-hyprland, so it is
      # rewritten to this one.
      programs.hyprland = {
        enable = true;
        withUWSM = cfg.hyprland.withUWSM;
        xwayland.enable = true;
        package = wrap {
          package = pkgs.hyprland;
          bins.start-hyprland = [
            "--add-flags"
            "-- --config ${cfg.build.hyprland}/hyprland.lua"
          ];
          postBuild = ''
            for f in "$out"/share/wayland-sessions/*.desktop; do
              src=$(readlink -f "$f")
              rm "$f"
              sed "s|${pkgs.hyprland}|$out|g" "$src" > "$f"
            done
          '';
        };
      };

      environment.systemPackages = with pkgs; [
        scripts # basalt-screenshot (SUPER+S), basalt-dpms (hypridle)
        grim
        slurp
        satty
        wl-clipboard
        jq
        hyprpolkitagent
        playerctl # media keys
        brightnessctl # brightness keys
      ];
    }

    (mkIf cfg.shellUi.enable {
      # Both entry points: the binds call `qs`, and quickshell is mainProgram.
      environment.systemPackages = [
        (wrap {
          package = pkgs.quickshell;
          bins = lib.genAttrs [ "quickshell" "qs" ] (_: [
            "--add-flags"
            "--path ${cfg.build.quickshell}"
          ]);
        })
        pkgs.wtype # the emoji picker's paste
        pkgs.hyprpwcenter # the audio settings page's mixer
        pkgs.hyprshutdown # logout, restart and shutdown in the power menu
      ];
    })

    (mkIf cfg.lock.enable {
      programs.hyprlock = {
        enable = true;
        package = wrap {
          package = pkgs.hyprlock;
          bins.hyprlock = [
            "--add-flags"
            "--config ${
              basalt.hyprlockConf {
                inherit pkgs;
                inherit (t) palette fonts;
                inherit (cfg.lock) extraConfig;
              }
            }"
          ];
        };
      };
    })

    (mkIf cfg.idle.enable {
      environment.systemPackages = [
        (wrap {
          package = pkgs.hypridle;
          bins.hypridle = [
            "--add-flags"
            "--config ${
              basalt.hypridleConf {
                inherit pkgs;
                extraConfig = idleListener + cfg.idle.extraConfig;
              }
            }"
          ];
        })
      ];
    })

    (mkIf cfg.wallpaper.enable {
      environment.systemPackages = [
        (wrap {
          package = pkgs.hyprpaper;
          bins.hyprpaper = [
            "--add-flags"
            "--config ${
              basalt.hyprpaperConf {
                inherit pkgs;
                wallpaper = cfg.build.wallpaper;
              }
            }"
          ];
        })
      ];
    })

    (mkIf cfg.notifications.enable {
      environment.systemPackages = [
        (wrap {
          package = pkgs.dunst;
          bins.dunst = [
            "--add-flags"
            "-config ${
              basalt.dunstrc {
                inherit pkgs;
                inherit (t) palette fonts;
                inherit (cfg.notifications) extraConfig;
              }
            }"
          ];
        })
        pkgs.libnotify
      ];
    })

    (mkIf cfg.kitty.enable {
      # A config directory rather than --config, which would land in front of
      # `kitty +kitten …` and `+runpy` and break them: Basalt's kitty.conf,
      # with the host's extraConfig as a kitty.d/ drop-in, as on a plain host.
      environment.systemPackages = [
        (wrap {
          package = pkgs.kitty;
          bins.kitty = [
            "--set"
            "KITTY_CONFIG_DIRECTORY"
            "${pkgs.runCommand "basalt-kitty-config" { } (
              ''
                install -Dm644 ${themed ../kitty/kitty.conf} $out/kitty.conf
              ''
              + lib.optionalString (cfg.kitty.extraConfig != "") ''
                install -Dm644 ${pkgs.writeText "host.conf" cfg.kitty.extraConfig} $out/kitty.d/host.conf
              ''
            )}"
          ];
        })
      ];
    })

    (mkIf cfg.starship.enable {
      environment.systemPackages = [
        (wrap {
          package = pkgs.starship;
          bins.starship = [
            "--set"
            "STARSHIP_CONFIG"
            "${themed ../starship/starship.toml}"
          ];
        })
      ];
    })

    (mkIf cfg.zsh.enable {
      # Basalt's init.zsh and finish.zsh, with oh-my-zsh and the two plugins
      # from the store, around the host's extraConfig. NixOS' own oh-my-zsh,
      # autosuggestions and syntax highlighting are left off: these replace
      # them.
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        # Starship draws the prompt (oh-my-zsh's plugin, in init.zsh). NixOS'
        # default promptInit runs `prompt suse` after it, which would win.
        promptInit = "";
        interactiveShellInit = ''
          BASALT_OMZ=${pkgs.oh-my-zsh}/share/oh-my-zsh
          BASALT_ZSH_AUTOSUGGEST=${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
          BASALT_ZSH_HIGHLIGHT=${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
          source ${../zsh/init.zsh}
          ${cfg.zsh.extraConfig}
          source ${../zsh/finish.zsh}
        '';
      };
    })

    (mkIf cfg.yazi.enable {
      environment.systemPackages = with pkgs; [
        (wrap {
          package = pkgs.yazi;
          bins.yazi = [
            "--set"
            "YAZI_CONFIG_HOME"
            "${themedDir ../yazi "basalt-yazi-config"}"
          ];
        })
        # yazi in kitty for a folder, as an "Open with" choice; nautilus is the
        # default (the nautilus piece).
        (runCommand "yazi-open" { } ''
          install -Dm644 ${../applications/yazi-open.desktop} $out/share/applications/yazi-open.desktop
        '')
        ffmpegthumbnailer # video thumbnails
        poppler-utils # PDF previews
        imagemagick # SVG/HEIC and other image previews
        _7zz # archive previews and extraction
        xdg-utils # yazi's openers
      ];
    })

    (mkIf cfg.nautilus.enable {
      # The folder browser other programs open, and the way to removable and
      # network drives, phones and archives. yazi stays SUPER+E. The default
      # is desktop-specific (applications/hyprland-mimeapps.list), so it
      # outranks the host's /etc/xdg/mimeapps.list in a Hyprland session; a
      # user's own ~/.config/mimeapps.list still wins.
      environment.etc."xdg/hyprland-mimeapps.list".source = ../applications/hyprland-mimeapps.list;
      services.gvfs.enable = true;
      environment.systemPackages = with pkgs; [
        nautilus
        file-roller
      ];
    })

    (mkIf cfg.gtk.enable {
      # GTK reads gtk.css only from ~/.config (libadwaita apps nothing else), so
      # the four files are linked there; see Basalt's gtk/README.md.
      programs.dconf.profiles.user.databases = [
        {
          settings."org/gnome/desktop/interface" = {
            gtk-theme = basalt.theme.gtkTheme;
            color-scheme = basalt.theme.colorScheme;
            icon-theme = basalt.theme.icons;
            cursor-theme = t.cursor.name;
            cursor-size = lib.gvariant.mkInt32 t.cursor.size;
            font-name = "${t.fonts.ui} ${toString t.fonts.size}";
            document-font-name = "${t.fonts.ui} ${toString t.fonts.size}";
            monospace-font-name = "${t.fonts.mono} ${toString t.fonts.size}";
          };
        }
      ];
      systemd.user.tmpfiles.rules =
        let
          gtk = themedDir ../gtk "basalt-gtk";
        in
        map (f: "L+ %h/.config/${f} - - - - ${gtk}/${f}") [
          "gtk-3.0/gtk.css"
          "gtk-3.0/colors.css"
          "gtk-4.0/gtk.css"
          "gtk-4.0/colors.css"
        ];
      environment.systemPackages = with pkgs; [
        adw-gtk3
        papirus-icon-theme # also dunst's notification icons
      ];
    })

    (mkIf cfg.qt.enable (
      let
        colors = themed ../qt/base16.conf;
        # --replace-fail, so a qt6ct.conf without the placeholder fails the
        # build rather than pointing Qt at nothing.
        ct = pkgs.runCommand "qt6ct.conf" { } ''
          substitute ${../qt/qt6ct.conf} $out --replace-fail @COLORS@ ${colors}
        '';
      in
      {
        environment.systemPackages = [ pkgs.qt6Packages.qt6ct ];
        environment.variables.QT_QPA_PLATFORMTHEME = "qt6ct";
        # Qt finds a platform-theme plugin in the system profile only through
        # the plugin path; wrapped Qt apps prefix it, so they keep their own.
        environment.profileRelativeSessionVariables = {
          QT_PLUGIN_PATH = [ "/${pkgs.qt6.qtbase.qtPluginPrefix}" ];
          QML2_IMPORT_PATH = [ "/${pkgs.qt6.qtbase.qtQmlPrefix}" ];
        };
        systemd.user.tmpfiles.rules = [
          "L+ %h/.config/qt5ct/qt5ct.conf - - - - ${ct}"
          "L+ %h/.config/qt6ct/qt6ct.conf - - - - ${ct}"
        ];
      }
    ))

    (mkIf cfg.fonts.enable {
      fonts.packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        nerd-fonts.hack
        nerd-fonts.symbols-only
        # Only Onest, not the whole ~2GB collection.
        (google-fonts.override { fonts = [ t.fonts.ui ]; })
      ];
      # The same defaults as Basalt's fontconfig/50-basalt.conf.
      fonts.fontconfig.defaultFonts = {
        sansSerif = [
          t.fonts.ui
          "Noto Sans CJK SC"
          "Noto Color Emoji"
        ];
        monospace = [
          t.fonts.mono
          "Noto Sans Mono"
          "Noto Color Emoji"
        ];
        emoji = [ "Noto Color Emoji" ];
      };
    })

    (mkIf cfg.cursor.enable {
      # Session variables rather than Hyprland's env, so they also reach
      # anything started outside it.
      environment.sessionVariables = {
        XCURSOR_THEME = t.cursor.name;
        XCURSOR_SIZE = toString t.cursor.size;
        HYPRCURSOR_THEME = t.cursor.name;
        HYPRCURSOR_SIZE = toString t.cursor.size;
      };
      environment.systemPackages = [ t.cursor.package ];
    })

    (mkIf cfg.btop.enable {
      environment.systemPackages = [
        (wrap {
          package = pkgs.btop;
          bins.btop = [
            "--add-flags"
            "--config ${../btop/btop.conf}"
          ];
        })
      ];
    })

    (mkIf cfg.fastfetch.enable {
      environment.systemPackages = [
        (wrap {
          package = pkgs.fastfetch;
          bins.fastfetch = [
            "--add-flags"
            "--config ${../fastfetch/config.jsonc}"
          ];
        })
      ];
    })

    (mkIf cfg.qalculate.enable {
      # qalc reads $XDG_CONFIG_HOME/qalculate/qalc.cfg and nothing else.
      environment.systemPackages = [
        (wrap {
          package = pkgs.libqalculate;
          bins.qalc = [
            "--set"
            "XDG_CONFIG_HOME"
            "${pkgs.runCommand "basalt-qalc-config" { } ''
              install -Dm644 ${../qalculate/qalc.cfg} $out/qalculate/qalc.cfg
            ''}"
          ];
        })
      ];
    })
  ]);
}
