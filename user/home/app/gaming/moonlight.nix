{ pkgs, ... }:

{
  # Moonlight client — pairs with Sunshine running inside the macOS VM
  # (or a real GameStream/Sunshine host). Reaches the VM via the bridge
  # network; user-mode networking (slirp) needs hostfwd rules added or a
  # switch to bridged mode for Moonlight to see Sunshine.
  home.packages = [ pkgs.moonlight-qt ];
}
