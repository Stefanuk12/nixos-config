{ ... }:

{
  virtualisation.kvmfr = {
    enable = true;

    devices = [
      {
        size = 64;

        permissions = {
          user = "stefan";
        };
      }
    ];
  };
}
