{ pkgs, ... }:

{
  # Flathub-only.
  services.flatpak.packages = [ "org.vinegarhq.Sober" ];

  # Rich Presence.
  services.flatpak.overrides."org.vinegarhq.Sober".Context.filesystems = [
    "xdg-run/app/com.discordapp.Discord:create"
    "xdg-run/discord-ipc-0"
  ];

  home.packages = [
    # nixpkgs pins 1.9.3, which mangles "Edit in Studio" deeplinks. Drop once it ships 1.9.4+.
    (pkgs.vinegar.overrideAttrs (old: rec {
      version = "1.9.4";
      src = pkgs.fetchFromGitHub {
        owner = "vinegarhq";
        repo = "vinegar";
        tag = "v${version}";
        hash = "sha256-5RwRiHVOYxMBL92Z8H+0VxJtz6Y7yXpv70UqesLINCk=";
      };
      vendorHash = "sha256-kS8awIGI5xHY4i7hvKMLcZKdMiFaoirokd3TSpMbC8c=";

      # 1.9.4 moved the wine-root pin to internal/config/config.go, so nixpkgs' postPatch no longer
      # applies; re-bake the packaged wine into the new location.
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
