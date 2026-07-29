# macOS VM without GPU passthrough; ../lib/mkMacOSVM.nix does the work, this is just identity.

{ pkgs, osxKvm, ... }:

let
  vm = (import ../lib/mkMacOSVM.nix { inherit pkgs osxKvm; }) {
    name = "osx-kvm";
    uuid = "9a8f7c3e-2d4b-4a1c-9e6f-5b0c1d2e3f4a";

    plistOverrides = {
      Misc.Security = {
        # Upstream ships Vault = "Secure", which halts OpenCore at "Configuration requires vault
        # but no vault provided!" — this image isn't vaulted. "Optional" uses one only if present.
        Vault = "Optional";
      };
    };
  };
in
{
  inherit (vm) domain configPlist;
}
