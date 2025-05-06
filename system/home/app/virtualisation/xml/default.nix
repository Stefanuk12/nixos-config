{ inputs, ... }:

{
  imports = [
    inputs.nixvirt.nixosModules.default
  ];

  virtualisation.libvirt.connections."qemu:///system".domains = [
    {
      definition = ./win11_2.xml;
      active = false;
    }
  ];
}
