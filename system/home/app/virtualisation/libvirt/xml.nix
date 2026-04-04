{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:

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

    cputune.emulatorpin = {
      cpuset = "0-1,8-9";
    };
    cputune.iothreadpin = {
      iothread = 1;
      cpuset = "0-1,8-9";
    };
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

      loader = {
        readonly = true;
        secure = true;
        type = "pflash";
        path = "/var/lib/barely-metal/firmware/OVMF_CODE.fd";
      };
      nvram = {
        template = "/var/lib/barely-metal/firmware/OVMF_VARS.fd";
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
        reenlightenment.state = false;
        tlbflush.state = false;
        ipi.state = false;
        evmcs.state = false;
        avic.state = false;
        emsr_bitmap.state = false;
        xmm_input.state = false;
      };
      kvm.hidden.state = true;
      smm.state = true;
      pmu.state = false;
      ioapic.driver = "kvm";
      msrs.unknown = "fault";
      vmport.state = false;
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
      maxphysaddr.mode = "passthrough";

      feature = [
        (makeFeature "require" "svm")
        (makeFeature "require" "topoext")
        (makeFeature "require" "invtsc")
        (makeFeature "disable" "vmx-vnmi")
        (makeFeature "disable" "hypervisor")
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
        {
          name = "tsc";
          present = true;
          mode = "native";
          tickpolicy = "discard";
        }
        {
          name = "hpet";
          present = true;
        }
        {
          name = "rtc";
          present = false;
        }
        {
          name = "pit";
          present = false;
        }

        {
          name = "kvmclock";
          present = false;
        }
        {
          name = "hypervclock";
          present = false;
        }
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

      disk = [
        {
          type = "file";
          device = "disk";
          serial = "ECFE037C590CE21A24AE";

          driver = {
            name = "qemu";
            type = "qcow2";
            cache = "none";
            io = "native";
            discard = "unmap";
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
        }
        {
          type = "file";
          device = "cdrom";
          readonly = { };

          driver = {
            name = "qemu";
            type = "raw";
          };

          source.file = "/var/lib/barely-metal/firmware/guest-scripts.iso";

          target = {
            dev = "sdc";
            bus = "sata";
          };
        }
      ];

      interface = [
        {
          type = "bridge";
          mac.address = "52:54:3a:20:c8:5d";
          source.bridge = "br0";
          model.type = "rtl8139";
          link.state = "up";
          address = {
            type = "pci";
            domain = 0;
            bus = 10;
            slot = 0;
            function = 0;
          };
        }
      ];

      input = [
        {
          type = "evdev";
          source.dev = "/dev/input/event1";
        }
        {
          type = "evdev";
          source = {
            dev = "/dev/input/event6";
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

      graphics = {
        type = "spice";
        autoport = true;
        listen.type = "address";
        image.compression = false;
        gl.enable = false;
      };
      channel = [
        {
          type = "spicevmc";
          target = {
            type = "virtio";
            name = "com.redhat.spice.0";
          };
          address = {
            type = "virtio-serial";
            controller = 0;
            bus = 0;
            port = 1;
          };
        }
      ];
      video.model.type = "none";

      watchdog = {
        model = "itco";
        action = "reset";
      };

      memballoon.model = "none";

      controller = [
        (makeController "usb" 0 "qemu-xhci")
        (makeController "pci" 0 "pcie-root")
        (makeController "pci" 1 "pcie-root-port")
        (makeController "pci" 16 "pcie-to-pci-bridge")
        (makeControllerAddr "sata" 0 {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 31;
          function = 2;
        })
        (makeControllerAddr "virtio-serial" 0 {
          type = "pci";
          domain = 0;
          bus = 3;
          slot = 0;
          function = 0;
        })
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
      (makeValue "file=/var/lib/barely-metal/firmware/smbios.bin")
      (makeValue "-acpitable")
      (makeValue "file=/var/lib/barely-metal/firmware/acpi/spoofed_devices.aml")
      # (makeValue "-cpu")
      # (makeValue "host,kvm-pv-enforce-cpuid=on")
      (makeValue "-device")
      (makeValue "{\"driver\":\"ivshmem-plain\",\"id\":\"shmem0\",\"memdev\":\"looking-glass\"}")
      (makeValue "-object")
      (makeValue "{\"qom-type\":\"memory-backend-file\",\"id\":\"looking-glass\",\"mem-path\":\"/dev/kvmfr0\",\"size\":33554432,\"share\":true}") 
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
in
{
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
