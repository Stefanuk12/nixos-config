#!/usr/bin/env sh
# Hand the dGPU to VFIO for the passthrough VMs. Reverse with dgpu-enable, confirm with hows-my-gpu.
set -e

# The VGA/3D/Display controller bound to a GPU or vfio driver, i.e. not the amdgpu iGPU.
# Bus-agnostic, so a GPU swap needs no edits.
gpu_addr=$(lspci -Dnnk | awk '
  /VGA compatible controller|3D controller|Display controller/ { addr=$1 }
  /Kernel driver in use: (vfio-pci|nvidia|nouveau)/ { print addr; exit }')

if [ -z "$gpu_addr" ]; then
  echo "dgpu-disable: could not find a discrete GPU (nvidia/nouveau/vfio-pci). Aborting." >&2
  exit 1
fi

# 0000:01:00.0 -> pci_0000_01_00_0, plus its audio function.
gpu_node="pci_$(printf '%s' "$gpu_addr" | tr ':.' '__')"
aud_node="pci_$(printf '%s' "$gpu_addr" | sed 's/\.[0-9]*$//' | tr ':.' '__')_1"

echo "Detaching $gpu_addr  ($gpu_node + $aud_node)"

# Unbinding while nvidia_drm still owns the DRM node sends the remove through nvidia's
# console-restore path, which NULL-derefs in nv_audio_dynamic_power and kills the caller
# inside device_release_driver_internal, still holding the device lock. The GPU is then
# wedged until reboot, so refuse rather than let rmmod fail quietly.
sudo rmmod nvidia_drm nvidia_modeset nvidia_uvm 2>/dev/null || true

if lsmod | grep -qE '^nvidia_(drm|modeset)'; then
  echo "dgpu-disable: nvidia_drm/nvidia_modeset are still loaded; detaching now would oops the" >&2
  echo "kernel and wedge the GPU until reboot. Close these holders and retry:" >&2
  sudo sh -c 'for d in /proc/[0-9]*; do
    ls -l "$d"/fd 2>/dev/null | grep -q /dev/nvidia &&
      printf "  %s (pid %s)\n" "$(cat "$d"/comm)" "${d#/proc/}"
  done' >&2 || true
  exit 1
fi

sudo modprobe -a vfio_pci vfio_iommu_type1
echo "VFIO drivers added"

sudo virsh nodedev-detach "$gpu_node"
sudo virsh nodedev-detach "$aud_node"
echo "GPU detached (now VFIO ready)"

echo "COMPLETED! (confirm success with hows-my-gpu)"
