# Toolkit entry: wires every component into one callPackage scope so modules declare dependencies via their argument list instead of threading pkgs/lib.
#
#   osxKvm = import ./. { inherit pkgs; };
#   img    = osxKvm.mkImage { profile = osxKvm.profiles.mp71; };
#
# Runtime mutable bits (BaseSystem.img, mac_hdd_ng.img, OVMF VARS) stay outside /nix/store; default lookup root $HOME/.local/share/osx-kvm.

{ pkgs, lib ? pkgs.lib }:

lib.makeScope pkgs.newScope (self: {
  ovmf            = self.callPackage ./pkgs/ovmf.nix { };
  opencore        = self.callPackage ./pkgs/opencore-base.nix { };
  ocSnapshot      = self.callPackage ./pkgs/oc-snapshot.nix { };
  fetchBaseSystem = self.callPackage ./pkgs/fetch-basesystem.nix { };
  kexts           = self.callPackage ./pkgs/kexts { };
  profiles        = import ./profiles { inherit (self) kexts; };

  mkConfigPlist   = self.callPackage ./lib/mk-config-plist.nix { };
  mkImage         = self.callPackage ./lib/mk-image.nix { };
})
