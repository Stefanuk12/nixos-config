{ inputs, ... }:

{
  imports = [
    inputs.nixvirt.nixosModules.default
  ];

  virtualisation.libvirt.connections."qemu:///system".domains = [
    {
      definition = ./win11.xml;
      active = false;
    }
  ];
}
