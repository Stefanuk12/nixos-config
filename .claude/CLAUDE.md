# CLAUDE.md

NixOS + Home Manager flake for two hosts: `home` (desktop) and `vps` (server).

## Rules

- **Comments: minimum.** Only write one when the code is genuinely non-obvious — a
  workaround, an upstream bug, a hardware quirk, a "remove once merged". Never restate
  what the option name already says. No section banners, no TODO noise. When editing,
  delete comments that have gone stale rather than updating them.
- **Prefer Home Manager over NixOS.** Put anything in `user/` that can live there:
  packages, dotfiles, services, program config. Only use `system/` for what genuinely
  needs root — kernel, boot, drivers, hardware, networking, users, virtualisation hosts,
  system-wide daemons.
- Rebuild only with the aliases below, and only when asked. Never invoke `nixos-rebuild` or
  `home-manager switch` directly.
- Never edit `flake.lock` by hand, `hardware-configuration.nix`, or `secrets/` plaintext.
- Match the surrounding file's style; it is not uniformly `nixfmt`-formatted, so don't reformat one.

## Layout

```
flake.nix                inputs, overlays (homeOverlays), nixosConfigurations, homeConfigurations
hosts/<host>/            configuration.nix (NixOS entry), home.nix (HM entry), vars.nix, hardware-*
system/{common,<host>}/  NixOS modules — default.nix imports its subdirs
user/{common,<host>}/    Home Manager modules — same pattern
packages/                local flakes and derivations referenced by flake.nix
secrets/                 sops-nix
```

Each directory's `default.nix` is an import aggregator. Adding a module = drop the file
in and add it to the sibling `default.nix`.

## Conventions

- Modules take `{ config, lib, pkgs, inputs, hostName, username, ... }` as needed; `hostName`
  and `username` come from `specialArgs` / `extraSpecialArgs`.
- Host-specific values live in `hosts/home/vars.nix` and `hardware-profile.nix` — read from
  there instead of hardcoding device IDs, CPU pins, or PCI addresses.
- Package overrides and pins go in `homeOverlays` in `flake.nix`, each with a one-line reason
  and a removal condition.
- Defaults that a host may override use `lib.mkDefault`.

## Build

```sh
rb-home          # NixOS switch, host `home`
hm-stefan-home   # Home Manager switch, stefan@home
```

Both are zsh aliases from [sh.nix](../user/common/app/shell/sh.nix) and already point at
`~/.dotfiles` with `--option eval-cache false`. `rb-home` needs sudo.
