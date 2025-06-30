{ inputs, pkgs, config, lib, ... }:

let
  makeUnitCount = unit: count: { inherit unit count; };
  makeVcpupin = vcpu: cpuset: { inherit vcpu cpuset; };
  makeNameValue = name: value: { inherit name value; };
  makeFeature = policy: name: { inherit policy name; };
  makeValue = value: { inherit value; };
  makeController = type: index: model: {
    inherit type index model;
  };
  makeControllerAddr = type: index: address: {
    inherit type index address;
  };
  
  win11 = {
    type = "kvm";
    name = "win11-111";
    uuid = "cad4ffc1-bd63-4faa-b0af-9f6740589f31";

    memory = makeUnitCount "G" 16;
    currentMemory = makeUnitCount "G" 16;

    iothreads.count = 1;

    vcpu.placement = "static";
    vcpu.count = 12;

    cputune.emulatorpin = { cpuset = "0-1,8-9"; };
    cputune.iothreadpin = { iothread = 1; cpuset = "0-1,8-9"; };
    cputune.vcpupin = [
      (makeVcpupin 0 "2")
      (makeVcpupin 1 "10")
      (makeVcpupin 2 "3")
      (makeVcpupin 4 "4")
      (makeVcpupin 5 "12")
      (makeVcpupin 6 "5")
      (makeVcpupin 7 "13")
      (makeVcpupin 8 "6")
      (makeVcpupin 9 "6")
      (makeVcpupin 10 "7")
      (makeVcpupin 11 "15")
    ];

    os = {
      type = "hvm";
      arch = "x86_64";
      machine = "q35";

      bootmenu.enable = true;
      smbios.mode = "host";

      loader = {
        readonly = true;
        type = "pflash";
        path = /run/libvirt/nix-ovmf/OVMF_CODE.fd;
      };
      nvram = {
        template = /run/libvirt/nix-ovmf/OVMF_VARS.fd;
        path = /var/lib/libvirt/qemu/nvram/win11_VARS.fd;
      };
    };

    features = {
      acpi = { };
      apic = { };
      hyperv = {
        mode = "custom";
        relaxed.state = false;
        vapic.state = false;
        spinlocks.state = false;
        vpindex.state = false;
        runtime.state = false;
        synic.state = false;
        stimer.state = false;
        reset.state = false;
        frequencies.state = false;
        vendor_id = {
          state = true;
          value = "AuthenticAMD";
        };
      };
      kvm.hidden.state = true;
      smm.state = true;
      pmu.state = false;
      ioapic.driver = "kvm";
      msrs.unknown = "fault";
    };

    cpu = {
      mode = "host-passthrough";
      check = "none";
      migratable = false;

      topology = {
        sockets = 1;
        dies = 1;
        cores = 6;
        threads = 2;
      };

      cache.mode = "passthrough";

      feature = [
        (makeFeature "require" "svm")
        (makeFeature "require" "topoext")
        (makeFeature "require" "invtsc")
        (makeFeature "disable" "ssbd")
        (makeFeature "disable" "amd-ssbd")
        (makeFeature "disable" "virt-ssbd")
        (makeFeature "disable" "rdpid")
      ];
    };

    clock = {
      offset = "timezone";
      timezone = "Europe/London";
    
      timer = [
        { name = "hpet"; present = false; }
        { name = "rtc"; present = false; tickpolicy = "catchup"; }
        { name = "pit"; tickpolicy = "discard"; }
        { name = "tsc"; present = true; mode = "native"; }

        { name = "kvmclock"; present = false; }
        { name = "hypervclock"; present = true; }
      ];
    };

    on_poweroff = "destroy";
    on_reboot = "restart";
    on_crash = "destroy";

    pm = {
      suspend-to-mem.enabled = true;
      suspend-to-disk.enabled = true;
    };

    devices = {
      emulator = /run/libvirt/nix-emulators/qemu-system-x86_64;

      disk = {
        type = "file";
        device = "disk";
        serial = "01f4c755-1dc4-4d93-9343-8c3c65d20467";

        driver = {
          name = "qemu";
          type = "qcow2";
          cache = "none";
          io = "native";
          discard = "ignore";
        };

        source.file = /var/lib/libvirt/images/win11.qcow2;

        backingStore = { };

        target = {
          dev = "sda";
          bus = "sata";
        };

        boot.order = 1;

        address = {
          type = "drive";
          controller = 0;
          bus = 0;
          target = 0;
          unit = 0;
        };
      };

      interface = [
        {
          type = "bridge";
          mac.address = "52:54:00:20:c8:5d";
          source.bridge = "br0";
          model.type = "e1000e"; 
          link.state = "up";
          address = {
            type = "pci";
            domain = 0;
            bus = 1;
            slot = 0;
            function = 0;
          };
        }
      ];

      input = [
        {
          type = "evdev";
          source.dev = "/dev/input/event5";
        }
        {
          type = "evdev";
          source = {
            dev = "/dev/input/by-id/usb-Razer_Razer_BlackWidow_V4_75_-event-kbd";
            grab = "all";
            grabToggle = "ctrl-ctrl";
            repeat = true;
          };
        }
      ];

      tpm = {
        model = "tpm-crb";
        backend = {
          type = "emulator";
          version = "2.0";
        };
      };

      sound = {
        model = "ich9";
        
        codec.type = "micro";
        audio.id = 1;
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 27;
          function = 0;
        };
      };
      audio = {
        id = 1;
        type = "pulseaudio";
        serverName = "/run/user/1000/pulse/native";
      };

      video.model.type = "none";

      watchdog = {
        model = "itco";
        action = "reset";
      };

      memballoon.model = "none";

      shmem = {
        name = "looking-glass";

        model.type = "ivshmem-plain";
        size = makeUnitCount "M" 32;
        address = {
          type = "pci";
          domain = 0;
          bus = 16;
          slot = 0;
          function = 0;
        };
      };

      controller = [
        (makeController "usb" 0 "qemu-xhci")
        (makeController "pci" 0 "pcie-root")
        (makeController "pci" 1 "pcie-root-port")
        (makeController "pci" 16 "pcie-to-pci-bridge")
        (makeControllerAddr "sata" 0 { type = "pci"; domain = 0; bus = 0; slot = 31; function = 2; })
        (makeControllerAddr "virtio-serial" 0 { type = "pci"; domain = 0; bus = 3; slot = 0; function = 0; })
      ];

      hostdev = [
        {
          mode = "subsystem";
          type = "pci";
          managed = true;
          source.address = {
            domain = 0;
            bus = 3;
            slot = 0;
            function = 0;
          };
          address = {
            type = "pci";
            domain = 0;
            bus = 4;
            slot = 0;
            function = 0;
          };
        }
        {
          mode = "subsystem";
          type = "pci";
          managed = true;
          source.address = {
            domain = 0;
            bus = 3;
            slot = 0;
            function = 1;
          };
          address = {
            type = "pci";
            domain = 0;
            bus = 5;
            slot = 0;
            function = 0;
          };
        }
      ];
    };

    qemu-commandline.arg = [
      (makeValue "-smbios")
      (makeValue ("file=" + toString ./smbios.bin))
    ];

    qemu-override.device = {
      alias = "sata0-0-0";
      frontend.property = [
        {
          name = "rotation_rate";
          type = "unsigned";
          value = "1";
        }
        {
          name = "discard_granularity";
          type = "unsigned";
          value = "0";
        }
      ];
    };
  };
in {
  imports = [
    inputs.nixvirt.nixosModules.default
  ];

  virtualisation.libvirt.enable = true;
  virtualisation.libvirt.connections."qemu:///system".domains = [
    {
      definition = inputs.nixvirt.lib.domain.writeXML win11;
      active = false;
    }
  ];
}