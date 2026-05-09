{ kexts }:

{
  mp71    = import ./mp71.nix    { inherit kexts; };
  imac191 = import ./imac191.nix { inherit kexts; };
}
