# sudo rmmod amdgpu
echo "AMD drivers removed"

sudo modprobe -i vfio_pci vfio_pci_core vfio_iommu_type1
echo "VFIO drivers added"

sudo virsh nodedev-detach pci_0000_03_00_0
sudo virsh nodedev-detach pci_0000_03_00_1
echo "GPU detached (now VFIO ready)"

echo "COMPLETED! (confirm success with hows-my-gpu and active-gpu)"
