#!/usr/bin/env sh
# Which kernel driver owns each GPU. The dGPU toggles between vfio-pci and its host driver.
lspci -nnk | grep -EiA3 'VGA compatible controller|3D controller|Display controller' \
  | grep -Ei --color=always \
      'VGA compatible controller|3D controller|Display controller|Kernel driver in use|Kernel modules'

echo
echo "Toggle the dedicated GPU with: dgpu-enable / dgpu-disable"
