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
  echo "kernel and wedge the GPU until reboot." >&2

  # A stale client normally sits on nvidia_drm's own DRM nodes rather than /dev/nvidia*, so take
  # the list from the GPU's sysfs. fuser needs root to see holders outside this session.
  nodes=""
  for n in /dev/nvidia[0-9]* /dev/nvidiactl /sys/bus/pci/devices/"$gpu_addr"/drm/*; do
    case "$n" in */drm/*) n="/dev/dri/$(basename "$n")" ;; esac
    [ -e "$n" ] && nodes="$nodes $n"
  done

  holders=$(sudo fuser -v $nodes 2>&1 | grep -vE '^ *USER' || true)
  if [ -n "$holders" ]; then
    echo "Close these holders and retry:" >&2
    printf '%s\n' "$holders" >&2
  else
    echo "Nothing holds$nodes, so the reference is kernel-side rather than a process you can" >&2
    echo "close — reboot to clear it." >&2
  fi
  exit 1
fi

sudo modprobe -a vfio_pci vfio_iommu_type1
echo "VFIO drivers added"

sudo virsh nodedev-detach "$gpu_node"
sudo virsh nodedev-detach "$aud_node"
echo "GPU detached (now VFIO ready)"

echo "COMPLETED! (confirm success with hows-my-gpu)"
