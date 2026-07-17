{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:

let
  mkWindowsVM = import ./lib/mkWindowsVM.nix;

  # Windows VM configs — single source of truth for domain XML + hooks
  vms = {
    win11-base   = import ./vms/win11-base.nix     { inherit inputs pkgs; };
    win11-rbxl   = import ./vms/win11-rblx.nix     { inherit inputs pkgs; };
    win11-rbxl-2 = import ./vms/win11-rblx-2.nix   { inherit inputs pkgs; };
    win11-office = import ./vms/win11-office.nix   { inherit inputs pkgs; };
    gaming       = import ./vms/gaming.nix         { inherit inputs pkgs; };
  };

  # macOS variants share ./lib/mkMacOSVM.nix (bypassing mkWindowsVM's Windows hardening); each exports { domain, pin?, governor? } and the osx-kvm toolkit is evaluated once here and threaded through.
  osxKvm = inputs.osx-kvm.lib.mkOsxKvm { inherit pkgs; };
  osxModules = {
    osx-kvm     = import ./vms/osx-kvm.nix     { inherit pkgs osxKvm; };
    osx-kvm-gpu = import ./vms/osx-kvm-gpu.nix { inherit pkgs osxKvm; };
  };

  # ── Domain XML generation ──────────────────────────────
  mkDomain = cfg: {
    definition = inputs.nixvirt.lib.domain.writeXML (mkWindowsVM cfg);
    active = false;
  };

  mkRawDomain = domain: {
    definition = inputs.nixvirt.lib.domain.writeXML domain;
    active = false;
  };

  # ── QEMU hook generation ────────────────────────────────
  # One hook script for every VM (windows + osx) that asks for governor management; mkCase takes a flat record so both config shapes feed in the same way.

  mkCase = { name, active, restore, vmCores, hostCores }: ''
    ${name})
      case "$OPERATION/$SUB_OPERATION" in
        prepare/begin)
          set_governor "${vmCores}" "${active}"
          set_governor "${hostCores}" "${active}"
          ;;
        release/end)
          set_governor "${vmCores}" "${restore}"
          set_governor "${hostCores}" "${restore}"
          ;;
      esac
      ;;
  '';

  windowsCases =
    let withGov = lib.filterAttrs
          (_: cfg: (cfg.governor or {}).enable or false) vms;
    in lib.mapAttrsToList (_: cfg: mkCase {
      inherit (cfg) name;
      active    = cfg.governor.active  or "performance";
      restore   = cfg.governor.restore or "schedutil";
      vmCores   = builtins.concatStringsSep "," (map toString (cfg.cpu.pinTo or []));
      hostCores = cfg.cpu.hostCores or "";
    }) withGov;

  osxCases =
    let withGov = lib.filterAttrs
          (_: m: ((m.governor or {}).enable or false) && (m ? pin)) osxModules;
    in lib.mapAttrsToList (_: m: mkCase {
      name      = m.domain.name;
      active    = m.governor.active  or "performance";
      restore   = m.governor.restore or "schedutil";
      vmCores   = builtins.concatStringsSep "," (map toString m.pin.vmCores);
      hostCores = m.pin.hostCores;
    }) withGov;

  allCases = windowsCases ++ osxCases;

  hookScript = pkgs.writeShellScript "qemu-hook" ''
    GUEST_NAME="$1"
    OPERATION="$2"
    SUB_OPERATION="$3"

    set_governor() {
      local cores="$1"
      local governor="$2"
      for core in ''${cores//,/ }; do
        echo "$governor" > /sys/devices/system/cpu/cpu''${core}/cpufreq/scaling_governor 2>/dev/null || true
      done
    }

    case "$GUEST_NAME" in
      ${builtins.concatStringsSep "\n      " allCases}
    esac
  '';

  hasHooks = allCases != [];

  # ── Hugepage host configuration ─────────────────────────
  # Derives sysctl from VM hugepage settings — 2MB pages use overcommit, 1GB pages must be allocated at boot.

  vmsWithHugepages = lib.filterAttrs (_: cfg:
    let hp = cfg.hugepages or false;
    in if builtins.isAttrs hp then hp.enable or false else hp
  ) vms;

  # Convert memory to MB for page count calculation
  memToMB = cfg:
    let u = cfg.memoryUnit or "G";
    in if u == "G" then cfg.memory * 1024 else cfg.memory;

  pageSizeKB = cfg:
    let
      hp = cfg.hugepages;
      sz = if builtins.isAttrs hp then hp.size or null else null;
      u  = if builtins.isAttrs hp then hp.unit or "G" else "G";
    in
      if sz == null then 2048           # default 2MB
      else if u == "G" then sz * 1048576  # 1G = 1048576 KB
      else if u == "M" then sz * 1024
      else sz;

  # Group VMs by page size, sum required pages
  totalPagesBySize = builtins.foldl' (acc: cfg:
    let
      psk = pageSizeKB cfg;
      memKB = memToMB cfg * 1024;
      pages = memKB / psk;
      prev = acc.${toString psk} or 0;
    in acc // { ${toString psk} = prev + pages; }
  ) {} (builtins.attrValues vmsWithHugepages);

  needs2M = totalPagesBySize ? "2048";
in
{
  imports = [
    inputs.nixvirt.nixosModules.default
  ];

  virtualisation.libvirt.enable = true;
  virtualisation.libvirt.connections."qemu:///system".domains =
    (lib.mapAttrsToList (_: mkDomain) vms)
    ++ map (m: mkRawDomain m.domain) (builtins.attrValues osxModules);

  # Post-ocvalidate config.plist per macOS VM, symlinked into /etc (cat /etc/osx-kvm/<vm>/config.plist) from mk-image.nix's /nix/store output.
  environment.etc = lib.mapAttrs'
    (n: m: lib.nameValuePair "osx-kvm/${n}/config.plist" { source = m.configPlist; })
    osxModules;

  # Install qemu hook only if any VM has governor management enabled
  systemd.services.libvirtd.preStart = lib.mkIf hasHooks ''
    mkdir -p /var/lib/libvirt/hooks
    ln -sf ${hookScript} /var/lib/libvirt/hooks/qemu
  '';

  # 2MB hugepages via overcommit, +512 pages (1 GB) headroom for other consumers (e.g. postgres) so a VM at the exact ceiling still starts.
  boot.kernel.sysctl = lib.mkIf needs2M {
    "vm.nr_overcommit_hugepages" = totalPagesBySize."2048" + 512;
  };
}
