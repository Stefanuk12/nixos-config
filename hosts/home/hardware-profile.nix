# Hardware identity for the `home` host — the one file to edit when the dGPU or its PCI address
# changes. Read `lspci -Dnn | grep -Ei 'vga|3d|display'` and update dgpu.*; vfio ids, PRIME bus ids,
# udev symlinks and VM passthrough all follow. CPU pinning lives in libvirt/lib/pinning.nix.
rec {
  # RTX 5080 (GB203), bound to vfio-pci at boot and toggled to the host with dgpu-enable.
  dgpu = {
    deviceIds = [ "10de:2c02" "10de:22e9" ]; # GPU function + its HDMI/DP audio function
    busInt = 1; # libvirt <hostdev source address bus=...>, rendered as 0x01
    pciAddr = "0000:01:00.0";
    virshNode = "pci_0000_01_00_0";
    primeBusId = "PCI:1:0:0";
    lspciMatch = "NVIDIA"; # informational; the scripts also auto-detect
  };

  # 9950X3D "Granite Ridge" iGPU (amdgpu) — drives the host display.
  igpu = {
    pciAddr = "0000:7a:00.0";
    primeBusId = "PCI:122:0:0"; # 0x7a = 122 decimal
    lspciMatch = "Granite Ridge";
  };
}
