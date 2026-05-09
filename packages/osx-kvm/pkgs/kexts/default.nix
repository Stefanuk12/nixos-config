{ callPackage }:

let
  mkAcidantheraKext = callPackage ./mk-acidanthera.nix { };
in
{
  # Exposed so callers can fetch their own Acidanthera kexts:
  #   osxKvm.kexts.mkAcidantheraKext { name = "RestrictEvents";
  #     version = "1.1.5"; sha256 = "..."; }
  inherit mkAcidantheraKext;

  appleMCEReporterDisabler = callPackage ./apple-mce-reporter-disabler.nix { };

  Lilu = mkAcidantheraKext {
    name = "Lilu";
    version = "1.6.8";
    sha256 = "1yg3xawvkb18334xb7r8sncw5f2jv51ix10q0jgpkwqzzqcxc8nv";
  };

  # VirtualSMC's release zip ships the main kext under Kexts/ alongside
  # SMC plugins; only the core is pulled here. For plugins, re-call
  # mkAcidantheraKext with the same version + a different bundleName.
  VirtualSMC = mkAcidantheraKext {
    name = "VirtualSMC";
    version = "1.3.3";
    sha256 = "1avgy56rjap9j36qw8xhpgmvfmpcirf4sfh5pqp9bz8cs56jj60x";
    subdir = "Kexts";
  };

  WhateverGreen = mkAcidantheraKext {
    name = "WhateverGreen";
    version = "1.6.7";
    sha256 = "1hss00pcb32fmfw7nwrihwfv3gmgdb6pg554ab4d8mggzlyxa25b";
  };

  AppleALC = mkAcidantheraKext {
    name = "AppleALC";
    version = "1.9.0";
    sha256 = "189q1992qa3gbj2601ms641jq7vls54g6vgr8gydlf7gkfydnw5v";
  };

  CryptexFixup = mkAcidantheraKext {
    name = "CryptexFixup";
    version = "1.0.3";
    sha256 = "0lp5ipv96fksidi0y1fvr4q2zyplj8fjjsxsf12csdzvl2i279zg";
  };
}
