# Shared CPU pin layout for the 9950X3D (16C/32T; SMT sibling of core N is logical CPU N+16).
# The VM sits on the 3D V-Cache CCD (cores 0-7, 96 MB L3) using cores 2-7 + siblings = 12 vCPUs,
# matching the VMs' 6c/2t topology; the host keeps 0-1 for emulator/IO plus the whole freq CCD.
#
#   V-Cache CCD (0-7):  host 0,1 (+16,17)  |  VM 2-7 (+18-23)
#   Freq CCD    (8-15): host 8-15 (+24-31)
#
# To give the VM the entire V-Cache CCD (16 vCPUs), set cores = 8 in mkGamingVM.nix /
# osx-kvm-gpu.nix and use vmCores = [ 0 16 1 17 2 18 3 19 4 20 5 21 6 22 7 23 ]; hostCores = "8-15,24-31".
{
  # vCPU -> host logical CPU, ordered so each (core, SMT-sibling) pair is adjacent.
  vmCores = [ 2 18 3 19 4 20 5 21 6 22 7 23 ];

  # emulatorpin/iothreadpin, and what the qemu hook confines the host slices to. Complement of vmCores.
  hostCores = "0-1,8-17,24-31";

  # Restored to the host slices when a pinned VM stops.
  allCores = "0-31";
}
