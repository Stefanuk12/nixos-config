{ pkgs, ... }:

{
  # Sober: the Roblox player for Linux (VinegarHQ), Flathub-only.
  services.flatpak.packages = [ "org.vinegarhq.Sober" ];

  # Let Sober reach Discord for Rich Presence (discord-rpc).
  services.flatpak.overrides."org.vinegarhq.Sober".Context.filesystems = [
    "xdg-run/app/com.discordapp.Discord:create"
    "xdg-run/discord-ipc-0"
  ];

  home.packages = [
    # nixpkgs pins Vinegar 1.9.3 which mangles "Edit in Studio" deeplinks; bump to 1.9.4 for the upstream fix and drop this override once nixpkgs ships 1.9.4+.
    (pkgs.vinegar.overrideAttrs (old: rec {
      version = "1.9.4";
      src = pkgs.fetchFromGitHub {
        owner = "vinegarhq";
        repo = "vinegar";
        tag = "v${version}";
        hash = "sha256-5RwRiHVOYxMBL92Z8H+0VxJtz6Y7yXpv70UqesLINCk=";
      };
      vendorHash = "sha256-kS8awIGI5xHY4i7hvKMLcZKdMiFaoirokd3TSpMbC8c=";

      # 1.9.4 moved the wine-root pin to internal/config/config.go, so re-bake the packaged wine (from buildInputs) into the new location since the nixpkgs postPatch no longer applies.
      postPatch =
        let
          wine = pkgs.lib.findFirst (p: pkgs.lib.hasPrefix "wine64-" (p.name or "")) (
            throw "vinegar: wine not found in buildInputs"
          ) old.buildInputs;
        in
        ''
          substituteInPlace Makefile \
            --replace-fail 'gtk-update-icon-cache' '${pkgs.lib.getExe' pkgs.gtk4 "gtk4-update-icon-cache"}'
          substituteInPlace internal/config/config.go \
            --replace-fail 'cfg.Studio.WineRoot = dirs.WinePath' 'cfg.Studio.WineRoot = "${wine}"'
        '';
    }))
  ];
}
