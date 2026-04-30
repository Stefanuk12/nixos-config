{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:

let
  mkVM = import ./xml/mkVM.nix;

  # VM configs — single source of truth for domain XML + hooks
  vms = {
    win11-base = import ./xml/win11-base.nix { inherit inputs pkgs; };
    win11-rbxl = import ./xml/win11-rblx.nix { inherit inputs pkgs; };
    win11-office = import ./xml/win11-office.nix { inherit inputs pkgs; };
  };

  # ── Domain XML generation ──────────────────────────────
  mkDomain = cfg: {
    definition = inputs.nixvirt.lib.domain.writeXML (mkVM cfg);
    active = false;
  };

  # ── QEMU hook generation ────────────────────────────────
  # Derives CPU core lists and governor settings from the VM config.
  # Generates a single hook script that handles all configured VMs.

  vmsWithGovernor = lib.filterAttrs
    (_: cfg: (cfg.governor or {}).enable or false)
    vms;

  mkCase = _: cfg:
    let
      gov = cfg.governor;
      pinTo = cfg.cpu.pinTo or [];
      vmCores = builtins.concatStringsSep "," (map toString pinTo);
      hostCores = cfg.cpu.hostCores or "";
    in ''
      ${cfg.name})
        case "$OPERATION/$SUB_OPERATION" in
          prepare/begin)
            set_governor "${vmCores}" "${gov.active or "performance"}"
            set_governor "${hostCores}" "${gov.active or "performance"}"
            ;;
          release/end)
            set_governor "${vmCores}" "${gov.restore or "schedutil"}"
            set_governor "${hostCores}" "${gov.restore or "schedutil"}"
            ;;
        esac
        ;;
    '';

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
      ${builtins.concatStringsSep "\n      " (lib.attrValues (lib.mapAttrs mkCase vmsWithGovernor))}
    esac
  '';

  hasHooks = vmsWithGovernor != {};

  # ── Hugepage host configuration ─────────────────────────
  # Derives kernel params / sysctl from VM hugepage settings.
  # 1GB pages: must be allocated at boot (kernel params).
  # 2MB pages: can use overcommit (sysctl).

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
    lib.mapAttrsToList (_: mkDomain) vms;

  # Install qemu hook only if any VM has governor management enabled
  systemd.services.libvirtd.preStart = lib.mkIf hasHooks ''
    mkdir -p /var/lib/libvirt/hooks
    ln -sf ${hookScript} /var/lib/libvirt/hooks/qemu
  '';

  # 2MB hugepages: can be allocated dynamically via overcommit
  boot.kernel.sysctl = lib.mkIf needs2M {
    "vm.nr_overcommit_hugepages" = totalPagesBySize."2048";
  };
}
