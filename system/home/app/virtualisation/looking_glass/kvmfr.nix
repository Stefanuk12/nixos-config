{ ... }:

{
  virtualisation.kvmfr.enable = true;
  virtualisation.devices = [
    {
      size = 64;

      permissions = {
        user = "stefan";
      };
    }
  ];
}
