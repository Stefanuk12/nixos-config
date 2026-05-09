# MacPro7,1 SMBIOS profile.
#
# Pairs the SMBIOS values with the kext set required to NOT panic under
# this product name. Specifically:
#
#   * AppleMCEReporterDisabler — without it, AppleIntelMCEReporter loads
#     against board-id Mac-27AD2F918AE68F61 and panics on the guest's
#     non-ECC RAM.
#   * AppleTyMCEDriver block — same reason, different driver.
#   * CryptexFixup (kernel ≥ 22) — Ventura+ refuses to boot under MP7,1
#     SMBIOS without it (system cryptex stage check).
#
# Serial / MLB / UUID / ROM are placeholders generated with macserial —
# replace them per-host so multiple installs don't collide on Apple ID.

{ kexts }:

{
  smbios = {
    productName = "MacPro7,1";
    serial = "F5KHLBZ1P7QM";
    mlb = "F5K216700CDK3F7JA";
    uuid = "2271E506-8817-4932-9AE5-9C6EBF678EAB";
    romMac = "E0:ED:8C:79:5B:E0";
  };

  bootArgs = "keepsyms=1 agdpmod=pikera npci=0x3000";

  kexts = [
    { name = "Lilu.kext";                      bundle = kexts.Lilu;
      bundlePath = "Lilu.kext";
      executablePath = "Contents/MacOS/Lilu"; }
    { name = "VirtualSMC.kext";                bundle = kexts.VirtualSMC;
      bundlePath = "VirtualSMC.kext";
      executablePath = "Contents/MacOS/VirtualSMC"; }
    { name = "WhateverGreen.kext";             bundle = kexts.WhateverGreen;
      bundlePath = "WhateverGreen.kext";
      executablePath = "Contents/MacOS/WhateverGreen";
      minKernel = "10.0.0"; }
    { name = "AppleALC.kext";                  bundle = kexts.AppleALC;
      bundlePath = "AppleALC.kext";
      executablePath = "Contents/MacOS/AppleALC"; }
    { name = "AppleMCEReporterDisabler.kext";  bundle = kexts.appleMCEReporterDisabler;
      bundlePath = "AppleMCEReporterDisabler.kext";
      comment = "Disable MCE reporter on non-ECC guest RAM (MP7,1 board-id)";
      minKernel = "21.0.0"; }
    { name = "CryptexFixup.kext";              bundle = kexts.CryptexFixup;
      bundlePath = "CryptexFixup.kext";
      executablePath = "Contents/MacOS/CryptexFixup";
      comment = "Boot Ventura+ under MacPro7,1 SMBIOS";
      minKernel = "22.0.0"; }
  ];

  kextBlocks = [
    { identifier = "com.apple.driver.AppleTyMCEDriver";
      enabled = true;
      comment = "Block AppleTyMCEDriver - panics on MP7,1 without Xeon thermal sensors"; }
  ];
}
