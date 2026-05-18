{
  description = "Fetch Bitwarden vault entries via rbw to tmpfs files (NixOS module)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    nixosModules.default = ./module.nix;
    nixosModules.rbw-fetch = self.nixosModules.default;

    homeManagerModules.default = ./hm-module.nix;
    homeManagerModules.rbw-fetch = self.homeManagerModules.default;
  };
}
