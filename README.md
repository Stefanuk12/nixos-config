# nixos-config

Welcome to my NixOS config!
This is my personal configuration, and (with some tinkering), you can get your system to work identically to mine.

My initial motiviations to switch to Linux is the ability to spin up KVMs.
Therefore, there is a heavy focus on (stealthy) virtualisation in this configuration.

## Home Features

I also store my configuration for my personal server here too.
However, that will not be documented in this README, since it's for me.

### Desktop

- [x] [Wayland](https://wayland.freedesktop.org/)
- [x] [Hyprland](https://hyprland.org/)
  - [x] [Hypridle](https://wiki.hyprland.org/Hypr-Ecosystem/hypridle/) (bugged)
  - [ ] [Hyprlock](https://wiki.hyprland.org/Hypr-Ecosystem/hyprlock/) (having issues i think)
- [ ] Theme: [HyDE](https://hydeproject.pages.dev/)
- [x] Notifications: [Fnott](https://github.com/nix-community/home-manager/blob/master/modules/services/fnott.nix)
- [x] App Launcher: [Fuzzel](https://codeberg.org/dnkl/fuzzel)
- [x] Taskbar: [Waybar](https://github.com/Alexays/Waybar)
- [x] Screenshots: [Grimblast](https://github.com/NixOS/nixpkgs/blob/nixos-23.11/pkgs/by-name/gr/grimblast/package.nix)

### System

- [x] 🔒 Secure Boot via [lanzaboote](https://github.com/nix-community/lanzaboote/v0.3.0)

#### Virtualisation

> [!WARNING]
> In the configuration, there is a lot of computer-specific configuration like my CPU pinning
> and `facter.json`/`probe.json`.

For clipboard/file sync, I am also using [KDE Connect](https://kdeconnect.kde.org/download.html) since it's less suspicious than spice-tools.
Furthermore, install the OpenSSH Server optional feature on Windows to get SFTP + `sshfs`

- [x] Stealthy Windows KVM with patches
  - [x] [AutoVirt](https://hydeproject.pages.dev/) integration via [BarelyMetal](https://github.com/Dreaming-Codes/BarelyMetal)
    - [x] QEMU patches
    - [x] EDK2 patches
    - [x] Kernel patches (disabled)
    - [x] Looking Glass 
  - [x] GPU Passthrough
- [ ] MacOS KVM
     
### Development applications

- [x] Visual Studio Code ([VSCodium](https://vscodium.com/))
- [x] Neovim based upon [Neve](https://github.com/redyf/Neve)
- [x] Terminal: [alacritty](https://github.com/NixOS/nixpkgs/blob/nixos-23.11/pkgs/applications/terminal-emulators/alacritty/default.nix)

### Other applications

Some other notable applications, I will not include them all.

- [x] Secret Manager: [sops](https://github.com/Mic92/sops-nix)
- [x] Password dmenu: [Bitwardewn Menu](https://github.com/NixOS/nixpkgs/blob/nixos-23.11/pkgs/applications/misc/bitwarden-menu)
- [x] [Vesktop](https://mynixos.com/home-manager/options/programs.vesktop.vencord) 
- [x] [Brave](https://github.com/NixOS/nixpkgs/blob/nixos-23.11/pkgs/applications/networking/browsers/brave/default.nix)
- [x] [KDE Connect](https://wiki.nixos.org/wiki/KDE_Connect)