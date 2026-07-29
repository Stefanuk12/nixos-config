{ pkgs, ... }:

{
  # Pairs with Sunshine in the macOS VM — slirp user-mode net needs hostfwd rules to reach it.
  home.packages = [ pkgs.moonlight-qt ];
}
