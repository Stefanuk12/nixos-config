{ pkgs }:

{
  ignition = pkgs.callPackage ./ignition.nix { };
  psvr2-toolkit-driver = pkgs.callPackage ./psvr2-toolkit-driver.nix { };
  psvr2-toolkit-capi-apps = pkgs.callPackage ./psvr2-toolkit-capi-apps.nix { };
  psvr2-unity-setup = pkgs.callPackage ./psvr2-unity-setup.nix { };
  psvr2-updater = pkgs.callPackage ./psvr2-updater.nix { };
  steamvr-linux-fixes = pkgs.callPackage ./steamvr-linux-fixes.nix { };
  xr-hardware = pkgs.callPackage ./xr-hardware.nix { };
}
