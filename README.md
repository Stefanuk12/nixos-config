# nixos-config

Welcome to my NixOS config!

## 🏠 [Home] Features

### Desktop

- [x] [Wayland](https://wayland.freedesktop.org/)
- [x] [Hyprland](https://hyprland.org/)
  - [x] [Hypridle](https://wiki.hyprland.org/Hypr-Ecosystem/hypridle/) (bugged)
  - [ ] [Hyprlock](https://wiki.hyprland.org/Hypr-Ecosystem/hypridle/) (having issues i think)
- [x] Notifications: [Fnott](https://github.com/nix-community/home-manager/blob/master/modules/services/fnott.nix)
- [x] 🚀 App Launcher: [Fuzzel](https://codeberg.org/dnkl/fuzzel)
- [x] Taskbar: [Waybar](https://github.com/Alexays/Waybar)
- [x] 📷 Screenshots: [Grimblast](https://github.com/NixOS/nixpkgs/blob/nixos-23.11/pkgs/by-name/gr/grimblast/package.nix#L55)

### System

- [x] 🔒 Secure Boot via [lanzaboote](https://github.com/nix-community/lanzaboote/v0.3.0)

#### Virtualisation

- [x] Windows KVM with patches
  - [ ] RDTSC kernel patches
  - [x] QEMU patches
  - [x] GPU Passthrough
- [ ] MacOS KVM
     
### Development applications

- [x] 💻 Neovim based upon [Neve](https://github.com/redyf/Neve)
- [x] 🧑‍💻 Terminal: [alacritty](https://github.com/NixOS/nixpkgs/blob/nixos-23.11/pkgs/applications/terminal-emulators/alacritty/default.nix#L132)

### Other applications

- [x] 🤫 Secret Manager: [sops](https://github.com/Mic92/sops-nix)
- [x] 🗣️ [Discord](https://github.com/NixOS/nixpkgs/blob/nixos-23.11/pkgs/applications/networking/instant-messengers/discord/default.nix#L58)
- [x] 💂 [Brave](https://github.com/NixOS/nixpkgs/blob/nixos-23.11/pkgs/applications/networking/browsers/brave/default.nix#L199)
- [x] 🔑 [Bitwarden CLI](https://github.com/NixOS/nixpkgs/blob/nixos-23.11/pkgs/tools/security/bitwarden/cli.nix#L46)
- [ ] 🔑 [Bitwardewn Menu](https://github.com/NixOS/nixpkgs/blob/nixos-23.11/pkgs/applications/misc/bitwarden-menu/default.nix#L27) (having issues with dmenu?)

## 🖥️ [VPS] Features

- [x] [Nginx](https://www.nginx.com/)
- [x] [Mail server](https://gitlab.com/simple-nixos-mailserver/nixos-mailserver)
