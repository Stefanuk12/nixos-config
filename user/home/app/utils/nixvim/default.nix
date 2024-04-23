{ inputs,  ... }:

{
  home.packages = [
    inputs.Neve.packages."x86_64-linux".default
  ];
}
