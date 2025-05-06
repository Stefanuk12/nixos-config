{ ... }:

{
  virtualisation.kvmfr.enable = true;
  virtualisation.devices = [
    {
      size = 32;

      permissions = {
        user = "stefan";
      };
    }
  ];
}
