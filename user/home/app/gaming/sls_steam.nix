{ lib, pkgs, ... }:

let
  # Adding a game is one entry here: its Steam AppId, its directory under $HOME, and the
  # binary inside it. The launcher, desktop entry, shortcut settings and SLSsteam config all
  # follow from this. Set netsock for games whose multiplayer runs on SteamNetworkingSockets.
  games = {
    valheim = {
      appId = 892970;
      dir = "Games/Valheim";
      exe = "valheim.x86_64";
      netsock = true;
    };
  };

  titleOf = g: baseNameOf g.dir;
  appIds = lib.mapAttrsToList (_: g: g.appId) games;

  # The game's in-process steamclient rejects the Spacewar relay certificate FakeAppIds hands
  # it, so every connection fails with "Cert is not authorized for appid <real>, only 480".
  # This audit library patches that one check. Never set it on a game with anti-cheat.
  netsock = pkgs.stdenv.mkDerivation {
    pname = "steamnetsock-patch";
    version = "0-unstable-2026-07-01";
    src = pkgs.fetchFromGitHub {
      owner = "yesyes0649";
      repo = "steamnetsock-patch";
      rev = "4cbf251ae5b7884f100f96b833d5ad722b9762d6";
      hash = "sha256-70/O/4hAfgQG2ZYNarDg2uoDC8R/ofSwM8LfoRLhW2k=";
    };
    buildPhase = "$CC -O3 -shared -fPIC -o netsock.so steamclient_audit.c -ldl";
    installPhase = "install -Dm755 netsock.so $out/lib/netsock.so";
  };

  # Expanded by the shell at launch, so Steam's launch options survive a rebuild unchanged.
  netsockPath = "$HOME/.config/SLSsteam/tools/netsock/netsock.so";

  envOf =
    g:
    lib.optional (g.netsock or false) "LD_AUDIT=${netsockPath}"
    ++ [
      "SteamAppId=${toString g.appId}"
      "SteamGameId=${toString g.appId}"
    ];

  # Must be spawned inside the Steam client's own bwrap sandbox: SLSsteam reads
  # /proc/<pid>/{exe,environ} of every connecting process for FakeAppIds, and anything started
  # outside that user namespace is unreadable, so the mapping silently never applies.
  mkLauncher =
    name: g:
    pkgs.writeShellScriptBin name ''
      client="$HOME/.steam/root/ubuntu12_32/steam-runtime/amd64/usr/bin/steam-runtime-launch-client"
      tries=0

      # Also the readiness probe: the service only answers once the client is fully up.
      until "$client" --alongside-steam -- true >/dev/null 2>&1; do
        if [ "$tries" -eq 0 ]; then
          ${lib.getExe pkgs.libnotify} "${titleOf g}" "Starting Steam first"
          # Its own unit, else it shares this launcher's transient one and dies with the game.
          systemd-run --user --collect --unit=steam steam -silent
        elif [ "$tries" -gt 60 ]; then
          ${lib.getExe pkgs.libnotify} "${titleOf g}" "Steam's launcher service never came up"
          exit 1
        fi
        tries=$((tries + 1))
        sleep 1
      done

      exec "$client" --alongside-steam \
        --directory="$HOME/${g.dir}" \
        ${lib.concatMapStringsSep " " (e: "--env=${e}") (envOf g)} \
        -- ./${g.exe} "$@"
    '';

  python = pkgs.python3.withPackages (ps: [ ps.vdf ]);

  gamesJson = pkgs.writeText "sls-games.json" (
    builtins.toJSON (
      lib.mapAttrsToList (_: g: {
        inherit (g) appId dir;
        launchOptions = lib.concatStringsSep " " (envOf g) + " %command%";
      }) games
    )
  );

  # Steam caches every app's official art once AdditionalApps puts it in the library, so the
  # grid entries for the non-Steam shortcut are copied from there rather than downloaded.
  shortcutsPy = pkgs.writeText "sls-shortcuts.py" ''
    import glob, json, os, shutil, subprocess, sys, time
    import vdf

    MAGICK = "${pkgs.imagemagick}/bin/magick"
    PGREP = "${pkgs.procps}/bin/pgrep"
    HOME = os.path.expanduser("~")

    ASSETS = {
        "library_header.jpg": ".jpg",
        "library_capsule.jpg": "p.jpg",
        "library_hero.jpg": "_hero.jpg",
        "logo.png": "_logo.png",
    }


    def steam_running():
        return subprocess.run([PGREP, "-x", "steam"], capture_output=True).returncode == 0


    def wait_for_steam_gone(timeout=12 * 3600, stable=8):
        """Resets whenever Steam reappears, so a restart does not abandon the patch."""
        deadline = time.time() + timeout
        gone = None
        while time.time() < deadline:
            if steam_running():
                gone = None
                time.sleep(3)
                continue
            if gone is None:
                gone = time.time()
            elif time.time() - gone >= stable:
                return True
            time.sleep(1)
        return False


    def cache(app_id):
        return HOME + "/.local/share/Steam/appcache/librarycache/" + str(app_id)


    def install(app_id, grid, sid):
        for name, suffix in ASSETS.items():
            hits = glob.glob(cache(app_id) + "/*/" + name)
            if hits:
                shutil.copyfile(hits[0], grid + "/" + str(sid) + suffix)

        # The 32x32 icon sits loose beside the asset folders, and the shortcut's icon field
        # only renders reliably from a png.
        icons = [p for p in glob.glob(cache(app_id) + "/*.jpg") if os.path.getsize(p) < 65536]
        out = grid + "/" + str(sid) + "_icon.png"
        if icons:
            subprocess.run([MAGICK, icons[0], out], check=False)
        return out if os.path.exists(out) else None


    def shortcut_files():
        return glob.glob(HOME + "/.steam/steam/userdata/*/config/shortcuts.vdf")


    def sync(games):
        """Copies artwork and returns the fields each shortcut still needs changed."""
        wanted = {}
        for f in shortcut_files():
            grid = os.path.join(os.path.dirname(f), "grid")
            os.makedirs(grid, exist_ok=True)
            for key, e in vdf.binary_load(open(f, "rb")).get("shortcuts", {}).items():
                for g in games:
                    if HOME + "/" + g["dir"] + "/" not in str(e.get("Exe", "")):
                        continue
                    fields = {"LaunchOptions": g["launchOptions"]}
                    icon = install(g["appId"], grid, e["appid"] & 0xFFFFFFFF)
                    if icon:
                        fields["icon"] = icon
                    diff = {k: v for k, v in fields.items() if e.get(k) != v}
                    if diff:
                        wanted.setdefault(f, {})[key] = diff
        return wanted


    def apply(wanted):
        for f, entries in wanted.items():
            d = vdf.binary_load(open(f, "rb"))
            for key, fields in entries.items():
                if key in d.get("shortcuts", {}):
                    d["shortcuts"][key].update(fields)
            shutil.copy2(f, f + ".bak")
            open(f, "wb").write(vdf.binary_dumps(d))
            print("patched " + f)


    def main():
        games = json.loads(open(sys.argv[1]).read())
        wanted = sync(games)
        if not wanted:
            print("Shortcuts already current.")
            return

        # Steam holds shortcuts.vdf in memory and rewrites it on exit, so changes can only be
        # written once it is gone. Re-read then, since that rewrite lands first.
        if steam_running():
            if "--wait" not in sys.argv:
                print("Steam is running - shortcut changes deferred until it exits.")
                return
            if not wait_for_steam_gone():
                print("Timed out waiting for Steam to exit.")
                return
        apply(wanted)


    if __name__ == "__main__":
        main()
  '';

  sls-shortcuts = pkgs.writeShellScriptBin "sls-shortcuts" ''
    exec ${python}/bin/python3 ${shortcutsPy} ${gamesJson} "$@"
  '';

  # Written directly rather than through upstream's Home Manager module: that module is out of
  # sync with the binary, omitting a dozen keys it reads (which it warns about on every start)
  # and offering three it dropped (PlayNotOwnedGames, AutoFilterList, LogLevel).
  slsConfig = {
    # Ownership for each standalone build, and Spacewar so Steam networking reaches Online-Fix
    # peers. Upstream warns against running two apps under one fake id at the same time.
    AdditionalApps = appIds;
    FakeAppIds = lib.listToAttrs (map (id: lib.nameValuePair (toString id) 480) appIds);

    API = false;
    AppIds = [ ];
    AppTokens = { };
    CDKeys = { };
    DenuvoGames = { };
    DepotBlacklist = [ ];
    DisableCloud = true;
    DisableFamilyShareLock = true;
    DisableUpdates = true;
    DlcData = { };
    DumpClientInterfaces = false;
    ExtendedLogging = false;
    FakeEmail = "";
    FakeName = "";
    FakeOffline = [ ];
    FakeWalletBalance = 0;
    GameTitles = { };
    IdleStatus = {
      AppId = 0;
      Title = "";
    };
    LaunchOptions = { };
    LogLevels = 255;
    ManifestIds = { };
    MaxSchemaTries = 10;
    NotifyInit = true;
    Plugins = false;
    SafeMode = false;
    SmartTickets = 1;
    SteamIdOverride = { };
    SubscriptionTimestamps = { };
    UseWhitelist = false;
    WarnHashMissmatch = false;
  };
in
{
  xdg.configFile."SLSsteam/config.yaml".source =
    (pkgs.formats.yaml { }).generate "config.yaml" slsConfig;

  xdg.configFile."SLSsteam/tools/netsock/netsock.so".source = "${netsock}/lib/netsock.so";

  home.packages = lib.mapAttrsToList mkLauncher games ++ [ sls-shortcuts ];

  # Not oneshot: it can wait hours for Steam to exit, and a switch blocks on starting oneshots.
  # A changed games list changes ExecStart, which is what makes a switch restart it.
  systemd.user.services.sls-shortcuts = {
    Unit.Description = "Apply launch options and artwork to the SLSsteam games' Steam shortcuts";
    Service = {
      Type = "simple";
      ExecStart = "${sls-shortcuts}/bin/sls-shortcuts --wait";
    };
    Install.WantedBy = [ "default.target" ];
  };

  xdg.desktopEntries = lib.mapAttrs (name: g: {
    name = titleOf g;
    exec = name;
    icon = "steam";
    terminal = false;
    categories = [ "Game" ];
  }) games;
}
