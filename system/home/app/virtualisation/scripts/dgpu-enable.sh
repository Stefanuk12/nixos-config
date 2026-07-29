#!/usr/bin/env sh
# Return the dGPU to the host; the host driver binds automatically once VFIO releases it.
# Reverse of dgpu-disable, confirm with hows-my-gpu.
set -e

# Bus-agnostic, so a GPU swap needs no edits.
gpu_addr=$(lspci -Dnnk | awk '
  /VGA compatible controller|3D controller|Display controller/ { addr=$1 }
  /Kernel driver in use: (vfio-pci|nvidia|nouveau)/ { print addr; exit }')

if [ -z "$gpu_addr" ]; then
  echo "dgpu-enable: could not find the discrete GPU (vfio-pci/nvidia/nouveau). Aborting." >&2
  exit 1
fi

gpu_node="pci_$(printf '%s' "$gpu_addr" | tr ':.' '__')"
aud_node="pci_$(printf '%s' "$gpu_addr" | sed 's/\.[0-9]*$//' | tr ':.' '__')_1"

echo "Reattaching $gpu_addr  ($gpu_node + $aud_node)"
sudo virsh nodedev-reattach "$gpu_node"
sudo virsh nodedev-reattach "$aud_node"
echo "GPU reattached (now host ready)"

sudo rmmod vfio_pci vfio_pci_core vfio_iommu_type1 || true
echo "VFIO drivers removed"

# The base driver auto-binds on reattach but the modeset/DRM stack doesn't, and boot's
# nvidia_drm.modeset=1 never applies to a runtime rebind. Without these there's no /dev/dri render
# node, so Wayland/PRIME rendering black-screens.
sudo modprobe nvidia_uvm
sudo modprobe nvidia_drm modeset=1
echo "nvidia modeset/DRM stack loaded (dGPU render node ready)"

echo "COMPLETED! (confirm success with hows-my-gpu)"
