# OSX-KVM macOS VM — libvirt domain definition (no GPU passthrough).
# All the heavy lifting and the OSX-KVM-specific quirks live in
# ../lib/mkMacOSVM.nix; this file just supplies the per-VM identity.

{ pkgs, osxKvm, ... }:

let
  vm = (import ../lib/mkMacOSVM.nix { inherit pkgs osxKvm; }) {
    name = "osx-kvm";
    uuid = "9a8f7c3e-2d4b-4a1c-9e6f-5b0c1d2e3f4a";
  };
in
{
  inherit (vm) domain configPlist;
}
