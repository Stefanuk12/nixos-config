sudo virsh nodedev-reattach pci_0000_03_00_0
sudo virsh nodedev-reattach pci_0000_03_00_1
echo "GPU reattached (now host ready)"

sudo rmmod vfio_pci vfio_pci_core vfio_iommu_type1
echo "VFIO drivers removed"

# sudo modprobe -i amdgpu
echo "AMD drivers added"

echo "COMPLETED! (confirm success with hows-my-gpu, and active-gpu-prime)"
