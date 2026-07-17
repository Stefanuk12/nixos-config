{ pkgs, ... }:

{
  # Moonlight client; pairs with Sunshine in the macOS VM (slirp user-mode net needs hostfwd rules or bridged mode to reach it).
  home.packages = [ pkgs.moonlight-qt ];
}
