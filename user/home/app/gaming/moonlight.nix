{ pkgs, ... }:

{
  # Moonlight client; pairs with Sunshine in the macOS VM via the bridge network.
  # Slirp user-mode networking needs hostfwd rules (or bridged mode) to reach Sunshine.
  home.packages = [ pkgs.moonlight-qt ];
}
