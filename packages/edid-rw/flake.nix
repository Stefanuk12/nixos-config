{
  description = "edid-rw - read and write display EDID values";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.${system}.default = pkgs.stdenv.mkDerivation {
      pname = "edid-rw";
      version = "unstable";

      src = pkgs.fetchFromGitHub {
        owner = "bulletmark";
        repo = "edid-rw";
        rev = "master";
        hash = "sha256-b+GIzLb3TP0EMZ7aUtDHQkLrOf4hTfJPZw4M6UA35PM=";
      };

      nativeBuildInputs = [ pkgs.makeWrapper ];

      dontBuild = true;

      installPhase = ''
        install -Dm755 edid-rw $out/bin/edid-rw
        wrapProgram $out/bin/edid-rw \
          --prefix PYTHONPATH : "${pkgs.python3.withPackages (ps: [ ps.smbus2 ])}/lib/${pkgs.python3.libPrefix}/site-packages"
      '';

      postPatch = ''
        substituteInPlace edid-rw \
          --replace "from smbus import SMBus" "from smbus2 import SMBus"
      '';
    };

    apps.${system}.default = {
      type = "app";
      program = "${self.packages.${system}.default}/bin/edid-rw";
    };
  };
}