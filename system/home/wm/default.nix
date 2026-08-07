{ lib, pkgs, ... }:

let
  hw = import ../../../hosts/home/hardware-profile.nix;
in
{
  imports = [
    ./hyprland.nix
    ./login.nix
    ./sunshine_greeter.nix
  ];

  services.udev.packages = lib.singleton (
    pkgs.writeTextFile {
      name = "gpu-symlinks";
      text = ''
        KERNEL=="card*", KERNELS=="${hw.dgpu.pciAddr}", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/rtx5080"
        KERNEL=="card*", KERNELS=="${hw.igpu.pciAddr}", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/amd-igpu"
      '';
      destination = "/etc/udev/rules.d/70-gpu-symlinks.rules";
    }
  ) ++ lib.singleton (
    # systemd tags every DRM card master-of-seat, so logind claims the dGPU's card node and hands
    # it to the session — Hyprland then holds an fd on a GPU it never renders on, and nvidia_drm
    # cannot be unloaded for dgpu-disable. No display is attached to it, so drop it from the seat.
    # Numbered past 71-seat.rules and 73-seat-late.rules, which are what set these. Only card*, so
    # the render node keeps uaccess and stays usable for offload.
    pkgs.writeTextFile {
      name = "dgpu-no-seat";
      text = ''
        SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="${hw.dgpu.pciAddr}", TAG-="seat", TAG-="master-of-seat", ENV{ID_SEAT}=""
      '';
      destination = "/etc/udev/rules.d/74-dgpu-no-seat.rules";
    }
  );

  # Games render on the dGPU but the iGPU composites and scans out every one of their frames, and
  # that load is bursty enough that amdgpu's `auto` governor keeps parking sclk at 600MHz and then
  # being slammed to 100% busy. The resulting oscillation is the stutter at high refresh rates.
  systemd.services.igpu-performance = {
    description = "Pin the iGPU to its top DPM state";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/sys/bus/pci/devices/${hw.igpu.pciAddr}/power_dpm_force_performance_level";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "igpu-performance" ''
        echo high > /sys/bus/pci/devices/${hw.igpu.pciAddr}/power_dpm_force_performance_level
      '';
    };
  };

  services.xserver.enable = true;
  services.xserver.xkb.extraLayouts.iso_us = {
    description = "US with ISO keys";
    languages = [ "eng" ];
    symbolsFile = pkgs.writeText "iso_us" ''
      xkb_symbols "intl" {
        include "us(basic)"
        key <BKSL> {[ numbersign, asciitilde ]};
        key <LSGT> {[ backslash, bar ]};
      };
    '';
  };
}
