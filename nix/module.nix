{ config, lib, pkgs, ... }:

let
  cfg = config.services.lights-out;

  configFile = pkgs.writeText "lights-out-config.json" (builtins.toJSON {
    amber_time = cfg.config.amberTime;
    winddown_time = cfg.config.winddownTime;
    lights_out_time = cfg.config.lightsOutTime;
    morning_reset_time = cfg.config.morningResetTime;
    blocked_app_bundle_ids = cfg.config.blockedAppBundleIDs;
    blocked_domains = cfg.config.blockedDomains;
    whitelisted_app_bundle_ids = cfg.config.whitelistedAppBundleIDs;
    checklist = cfg.config.checklist;
    friction_delays_seconds = cfg.config.frictionDelaysSeconds;
    enable_shortcut_trigger = cfg.config.enableShortcutTrigger;
    shortcut_name = cfg.config.shortcutName;
    show_countdown_in_menu_bar = cfg.config.showCountdownInMenuBar;
  });

  appPath = "${cfg.package}/Applications/LightsOut.app";
in
{
  options.services.lights-out = {
    enable = lib.mkEnableOption "Lights Out menubar app";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The LightsOut package to use.";
    };

    config = {
      amberTime = lib.mkOption {
        type = lib.types.str;
        default = "22:30";
        description = "Time to enter amber phase (warm display). Format: HH:MM";
      };

      winddownTime = lib.mkOption {
        type = lib.types.str;
        default = "23:00";
        description = "Time to enter wind-down phase (app blocking begins). Format: HH:MM";
      };

      lightsOutTime = lib.mkOption {
        type = lib.types.str;
        default = "23:30";
        description = "Time to enter lights-out phase (full blocking + dim). Format: HH:MM";
      };

      morningResetTime = lib.mkOption {
        type = lib.types.str;
        default = "06:00";
        description = "Time to reset to idle phase. Format: HH:MM";
      };

      blockedAppBundleIDs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "com.google.Chrome" "org.mozilla.firefox" ];
        description = "Bundle identifiers of apps to block during wind-down/lights-out.";
      };

      blockedDomains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "youtube.com" "reddit.com" ];
        description = "Domains to block via /etc/hosts during wind-down/lights-out.";
      };

      whitelistedAppBundleIDs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "com.apple.Terminal" "com.spotify.client" ];
        description = "Bundle identifiers of apps to never block.";
      };

      checklist = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "Brush teeth" "Set out clothes for tomorrow" ];
        description = "Pre-bedtime checklist items shown during amber phase.";
      };

      frictionDelaysSeconds = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [ 60 180 600 ];
        description = "Escalating delay (seconds) for each successive override attempt.";
      };

      enableShortcutTrigger = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Run a macOS Shortcut when lights-out phase begins.";
      };

      shortcutName = lib.mkOption {
        type = lib.types.str;
        default = "Bedtime";
        description = "Name of the macOS Shortcut to trigger.";
      };

      showCountdownInMenuBar = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Show countdown text in the menubar (false = icon only).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Write config file on activation
    system.activationScripts.postActivation.text = ''
      LIGHTSOUT_DIR="$HOME/.lightsout"
      mkdir -p "$LIGHTSOUT_DIR"
      cp ${configFile} "$LIGHTSOUT_DIR/config.json"
      chmod 644 "$LIGHTSOUT_DIR/config.json"
    '';

    # LaunchAgent for the main menubar app (runs as current user in GUI session)
    launchd.user.agents.lights-out = {
      serviceConfig = {
        Label = "com.lightsout.app";
        Program = "${appPath}/Contents/MacOS/LightsOut";
        RunAtLoad = true;
        KeepAlive = true;
        LimitLoadToSessionType = "Aqua";
        StandardOutPath = "/tmp/lightsout.log";
        StandardErrorPath = "/tmp/lightsout.log";
      };
    };

    # LaunchDaemon for the privileged helper (runs as root)
    launchd.daemons.lights-out-helper = {
      serviceConfig = {
        Label = "com.lightsout.helper";
        Program = "${appPath}/Contents/MacOS/LightsOutHelper";
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/var/log/lightsout-helper.log";
        StandardErrorPath = "/var/log/lightsout-helper.log";
      };
    };
  };
}
